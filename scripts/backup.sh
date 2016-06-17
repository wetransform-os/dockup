#!/bin/bash
export PATH=$PATH:/usr/bin:/usr/local/bin:/bin

source ./notifications.sh

function cleanup {
  # If a post-backup command is defined (eg: for cleanup)
  if [ -n "$AFTER_BACKUP_CMD" ]; then
    eval "$AFTER_BACKUP_CMD"
  fi
}

start_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
SECONDS=0
echo "[$start_time] Initiating backup $BACKUP_NAME..."

# Get timestamp
: ${BACKUP_SUFFIX:=.$(date +"%Y-%m-%d-%H-%M-%S")}
tarball=$BACKUP_NAME$BACKUP_SUFFIX.tar.gz

# If a pre-backup command is defined, run it before creating the tarball
if [ -n "$BEFORE_BACKUP_CMD" ]; then
	eval "$BEFORE_BACKUP_CMD"
  rc=$?
  if [ $rc -ne 0 ]; then
    # early exit
    notifyFailure "Error performing backup preparation task."
    exit $rc
  fi
fi

if [ "$PATHS_TO_BACKUP" == "auto" ]; then
  # Determine mounted volumes - build command
  volume_cmd="cat /proc/mounts | grep -oP \"/dev/[^ ]+ \K(/[^ ]+)\""
  
  # Skip the three host configuration entries always setup by Docker.
  volume_cmd="$volume_cmd | grep -v \"/etc/resolv.conf\" | grep -v \"/etc/hostname\" | grep -v \"/etc/hosts\""
  
  # remove mounted keyring, if any
  if [ -n "$GPG_KEYRING" ]; then
    volume_cmd="$volume_cmd | grep -v \"$GPG_KEYRING\""
  fi
  
  # make a space separated list
  volume_cmd="$volume_cmd | tr '\n' ' '"
  volumes=$(eval $volume_cmd)
  
  if [ -z "$volumes" ]; then
    notifyFailure "No volumes for backup were detected."
    exit 1
  fi

  echo "Volumes for backup: $volumes"
  PATHS_TO_BACKUP=$volumes
fi

# Create a gzip compressed tarball with the volume(s)
time tar czf $tarball $BACKUP_TAR_OPTION $PATHS_TO_BACKUP
rc=$?
if [ $rc -ne 0 ]; then
  # early exit
  notifyFailure "Error creating backup archive."
  cleanup
  end_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
  echo -e "[$end_time] Backup failed\n\n"
  exit $rc
else
  echo "Created archive $tarball"
fi

# encrypt archive
if [ -n "$GPG_KEYNAME" -a -n "$GPG_KEYRING" ]; then
  echo "Encrypting backup archive..."
  time gpg --batch --no-default-keyring --keyring "$GPG_KEYRING" --trust-model always --encrypt --recipient "$GPG_KEYNAME" $tarball
  rc=$?
  if [ $rc -ne 0 ]; then
    # early exit
    notifyFailure "Error encrypting backup archive."
    rm $tarball
    cleanup
    exit $rc;
  fi
  echo "Encryption completed successfully"
  # remove original tarball and point to encrypted file
  rm $tarball
  tarball="$tarball.gpg"
else
  echo "Encryption not configured...skipping"
fi

backup_size=$(du -h "$tarball" | tr '\t' '\n' | grep -v "$tarball")

# Create bucket, if it doesn't already exist (only try if listing is successful - access may be denied)
BUCKET_LS=$(aws s3 --region $AWS_DEFAULT_REGION ls)
if [ $? -eq 0 ]; then
  BUCKET_EXIST=$(echo $BUCKET_LS | grep $S3_BUCKET_NAME | wc -l)
  if [ $BUCKET_EXIST -eq 0 ];
  then
    aws s3 --region $AWS_DEFAULT_REGION mb s3://$S3_BUCKET_NAME
  fi
fi

# Upload the backup to S3 with timestamp
echo "Uploading the archive to S3..."
time aws s3 --region $AWS_DEFAULT_REGION cp $tarball "s3://${S3_BUCKET_NAME}/${S3_FOLDER}${tarball}"
rc=$?

# Clean up
rm $tarball
cleanup

end_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
backup_duration=`date -u -d @"$SECONDS" +'%-Mm %-Ss'`
if [ $rc -ne 0 ]; then
  notifyFailure "Error uploading backup to S3."
  echo -e "[$end_time] Backup failed\n\n"
  exit $rc
else
  notifySuccess
  echo -e "[$end_time] Archive successfully uploaded to S3\n\n"
fi
