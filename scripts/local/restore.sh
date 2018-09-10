#!/bin/bash

if [ ! -n "${LAST_BACKUP}" ]; then
  # Find last backup file
  : ${LAST_BACKUP:=$(ls $LOCAL_TARGET/ -1 | grep ^$BACKUP_NAME | sort -r | head -n1)}
fi

# Retrieve from local storage
echo "Retrieving backup archive $LAST_BACKUP..."
mv "${LOCAL_TARGET}/${LAST_BACKUP}" $LAST_BACKUP
