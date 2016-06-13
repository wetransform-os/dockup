#!/bin/bash
#
# Simple test script for backup with cron.
# 
# Before running it, ensure there is a file test-env.txt
# with configuration options as in test-env.txt.sample
#
# Doesn't use encryption

# build dockup image
docker build -t wetransform/dockup:local .

# create data container
docker rm -v dockup-data-test
docker create --name dockup-data-test -v /data busybox

# create dummy file to backup
file_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
echo "File created at $file_time" > tmpBackup.txt

docker cp tmpBackup.txt dockup-data-test:/data/file.txt

# backup
exec docker run --rm -it \
  --env-file test-env.txt \
  -e BACKUP_NAME=dockup-test \
  -e PATHS_TO_BACKUP=auto \
  -e CRON_TIME="* * * * *" \
  --volumes-from dockup-data-test \
  --name dockup-run-test wetransform/dockup:local
