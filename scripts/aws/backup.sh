#!/bin/bash

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
