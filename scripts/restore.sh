#!/bin/bash

if [ ! -n "${LAST_BACKUP}" ]; then
  # Find last backup file
  : ${LAST_BACKUP:=$(aws s3 --region $AWS_DEFAULT_REGION ls s3://$S3_BUCKET_NAME/$S3_FOLDER | awk -F " " '{print $4}' | grep ^$BACKUP_NAME | sort -r | head -n1)}
fi

# Download backup from S3
echo "Retrieving backup archive $LAST_BACKUP..."
aws s3 --region $AWS_DEFAULT_REGION cp s3://$S3_BUCKET_NAME/$S3_FOLDER$LAST_BACKUP $LAST_BACKUP || (echo "Failed to download tarball from S3"; exit)

# Check if tarball is encrypted
if [ ${LAST_BACKUP: -4} == ".gpg" ]; then
  if [ -n "$GPG_SECRING" -a -n "$GPG_KEYRING" -a -n "$GPG_PASSPHRASE" ]; then
    echo "Decrypting backup archive..."
    decrypted_file=${LAST_BACKUP%.*}
    gpg --batch --no-default-keyring --secret-keyring "$GPG_SECRING" --keyring "$GPG_KEYRING" --passphrase "$GPG_PASSPHRASE" --output "$decrypted_file" --decrypt "$LAST_BACKUP"
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "ERROR: Error decrypting backup archive"
      rm $LAST_BACKUP
      exit $rc
    else
      echo "Successfully decrypted backup archive"
      # file to extract is decrypted file
      LAST_BACKUP=$decrypted_file
    fi
  else
    echo "ERROR: Backup archive is encrypted, but no GPG key is configured"
    rm $LAST_BACKUP
    exit 1
  fi
fi

# Extract backup
echo "Extracting backup archive $LAST_BACKUP..."
tar xzf $LAST_BACKUP -C / $RESTORE_TAR_OPTION
rc=$?

rm $LAST_BACKUP

if [ $rc -ne 0 ]; then
  echo "ERROR: Error extracting backup archive"
  exit $rc
else
  echo "Successfully extracted backup archive"
fi

# If a post extraction command is defined, run it
if [ -n "$AFTER_RESTORE_CMD" ]; then
  eval "$AFTER_RESTORE_CMD" || exit
fi
