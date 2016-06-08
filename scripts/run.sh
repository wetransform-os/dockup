#!/bin/bash

if [[ "$RESTORE" == "true" ]]; then
  ./restore.sh
else
  if [ -n "$CRON_TIME" ]; then
    LOGFIFO='/var/log/cron.fifo'
    if [[ ! -e "$LOGFIFO" ]]; then
        mkfifo "$LOGFIFO"
    fi
    env | grep -v 'affinity:container' | sed -e 's/^\([^=]*\)=\(.*\)/export \1="\2"/' > /env.conf # Save current environment
    echo "${CRON_TIME} . /env.conf && /backup.sh >> $LOGFIFO 2>&1" > /crontab.conf
    crontab  /crontab.conf
    echo "=> Running dockup backups as a cronjob for ${CRON_TIME}"
    cron
    tail -f "$LOGFIFO"
  else
    ./backup.sh
  fi
fi