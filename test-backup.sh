#!/bin/bash
#
# Simple test script for backup and restore
# 
# Before running it, ensure there is a file test-env.txt
# with configuration options as in test-env.txt.sample
# 
# Optionally use the ./gen-test-key.sh script to generate
# a GPG key used in this script.

GPG_KEYNAME=test-key
GPG_PASSPHRASE=dockup-test

# check for keyring
if [ ! -f "$GPG_KEYNAME.pub" ]; then
  GPG_KEYNAME=""
fi

if [ "$1" == "--no-encryption" ]; then
  GPG_KEYNAME=""
fi

# build dockup image
docker build -t wetransform/dockup:local .

# create data container
docker rm -v dockup-data-test
docker create --name dockup-data-test -v /data busybox

# create dummy file to backup
file_time=`date +%Y-%m-%d\\ %H:%M:%S\\ %Z`
echo "File created at $file_time" > tmpBackup.txt

docker cp tmpBackup.txt dockup-data-test:/data/file.txt

# generate a GPG key
#./gen-test-key.sh
#rc=$?; if [ $rc -ne 0 ]; then echo "ERROR: Error generating GPG key"; exit $rc; fi

# backup
docker run --rm \
  --env-file test-env.txt \
  -e BACKUP_NAME=dockup-test \
  -e PATHS_TO_BACKUP=auto \
  -e GPG_KEYNAME=$GPG_KEYNAME \
  -e GPG_KEYRING=/$GPG_KEYNAME.pub \
  --volumes-from dockup-data-test \
  -v $(pwd)/$GPG_KEYNAME.pub:/$GPG_KEYNAME.pub \
  -v $(pwd)/target:/dockup/target \
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
  -e GPG_KEYRING=/$GPG_KEYNAME.pub \
  -e GPG_SECRING=/$GPG_KEYNAME.sec \
  -e GPG_PASSPHRASE=$GPG_PASSPHRASE \
  -e RESTORE=true \
  --volumes-from dockup-data-test \
  -v $(pwd)/$GPG_KEYNAME.pub:/$GPG_KEYNAME.pub \
  -v $(pwd)/$GPG_KEYNAME.sec:/$GPG_KEYNAME.sec \
  -v $(pwd)/target:/dockup/target \
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