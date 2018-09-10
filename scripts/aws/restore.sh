#!/bin/bash

if [ ! -n "${LAST_BACKUP}" ]; then
  # Find last backup file
  : ${LAST_BACKUP:=$(aws s3 --region $AWS_DEFAULT_REGION ls s3://$S3_BUCKET_NAME/$S3_FOLDER | awk -F " " '{print $4}' | grep ^$BACKUP_NAME | sort -r | head -n1)}
fi

# Download backup from S3
echo "Retrieving backup archive $LAST_BACKUP..."
aws s3 --region $AWS_DEFAULT_REGION cp s3://$S3_BUCKET_NAME/$S3_FOLDER$LAST_BACKUP $LAST_BACKUP || (echo "Failed to download tarball from S3"; exit)
