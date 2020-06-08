#!/bin/bash

if [[ "$RESTORE" == "true" ]]; then
  /dockup/restore.sh
else
  if [ -n "$CRON_TIME" ]; then
    LOGFIFO='/dockup/cron.fifo'
    if [[ ! -e "$LOGFIFO" ]]; then
        mkfifo "$LOGFIFO"
    fi
    env | grep -v 'affinity:container' | sed -e 's/^\([^=]*\)=\(.*\)/export \1="\2"/' > /dockup/env.conf # Save current environment
    echo "${CRON_TIME} cd /dockup && . ./env.conf && cd ${WORK_DIR} && /dockup/backup.sh >> $LOGFIFO 2>&1" > /dockup/crontab.conf
    crontab /dockup/crontab.conf
    echo "=> Running dockup backups as a cronjob for ${CRON_TIME}"
    cron
    tail -n +0 -f "$LOGFIFO"
  else
    /dockup/backup.sh
  fi
fi