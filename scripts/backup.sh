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
tar_try=0
until [ $tar_try -ge $BACKUP_TAR_TRIES ]
do
  time tar czf $tarball $BACKUP_TAR_OPTION $PATHS_TO_BACKUP
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "Created archive $tarball"
    break
  else
    tar_try=$[$tar_try+1]
    rm $tarball
    if [ ! $tar_try -ge $BACKUP_TAR_TRIES ]; then
      echo "Attempt to create archive failed, retrying..."
      sleep $BACKUP_TAR_RETRY_SLEEP
    fi
  fi
done

if [ $rc -ne 0 ]; then
  # early exit
  notifyFailure "Error creating backup archive."
  cleanup
  end_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
  echo -e "[$end_time] Backup failed\n\n"
  exit $rc
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

# do backup according to configured mode
source "./${DOCKUP_MODE}/backup.sh"
rc=$?

# Clean up
rm $tarball
cleanup

end_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
backup_duration=`date -u -d @"$SECONDS" +'%-Mm %-Ss'`
if [ $rc -ne 0 ]; then
  notifyFailure "Error backuping up archive."
  echo -e "[$end_time] Backup failed\n\n"
  exit $rc
else
  notifySuccess
  echo -e "[$end_time] Archive successfully backed up\n\n"
fi
