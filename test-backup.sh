#!/bin/bash
#
# Simple test script for backup and restore
# 
# Before running it, ensure there is a file test-env.txt
# with configuration options as in test-env.txt.sample

docker build -t wetransform/dockup:local .

# create data container
docker rm -v dockup-data-test
docker create --name dockup-data-test -v /data busybox

# create dummy file to backup
file_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
echo "File created at $file_time" > tmpBackup.txt

docker cp tmpBackup.txt dockup-data-test:/data/file.txt

# backup
docker run --rm \
  --env-file test-env.txt \
  -e BACKUP_NAME=dockup-test \
  -e PATHS_TO_BACKUP=/data \
  --volumes-from dockup-data-test \
  --name dockup-run-test wetransform/dockup:local
rc=$?; if [ $rc -ne 0 ]; then
  echo "ERROR: Error running backup"
  rm tmpBackup.txt
  exit $rc
fi

# recreate data container
docker rm -v dockup-data-test
docker create --name dockup-data-test -v /data busybox

# restore
docker run --rm \
  --env-file test-env.txt \
  -e BACKUP_NAME=dockup-test \
  -e PATHS_TO_BACKUP=/data \
  -e RESTORE=true \
  --volumes-from dockup-data-test \
  --name dockup-run-test wetransform/dockup:local
rc=$?; if [ $rc -ne 0 ]; then
  echo "ERROR: Error running restore"
  rm tmpBackup.txt
  exit $rc
fi

docker cp dockup-data-test:/data/file.txt tmpRestore.txt
cmp --silent tmpBackup.txt tmpRestore.txt
rc=$?

rm tmpBackup.txt
rm tmpRestore.txt

if [ $rc -ne 0 ]; then
  echo "ERROR: Backup file is not identical to original"
  exit $rc
else
  echo "Restored file successfully"
fi