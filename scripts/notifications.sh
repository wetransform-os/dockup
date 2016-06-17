#!/bin/bash

function notifySuccess {
  if [ "$NOTIFY_BACKUP_SUCCESS" == "true" ]; then
    notify_summary="[${S3_FOLDER}$BACKUP_NAME] Backup succeeded."

    notifySlackSuccess
  fi
}

function notifyFailure {
  # always log error message
  if [ -n "$1" ]; then
    echo "ERROR: $1"
  fi

  if [ "$NOTIFY_BACKUP_FAILURE" == "true" ]; then
    notify_summary="[${S3_FOLDER}$BACKUP_NAME] Backup failed."

    notifySlackFailure "$1"
  fi
}

# Slack

function notifySlackSuccess {
  slack_success_message="Backup archive successfully uploaded to bucket $S3_BUCKET_NAME."
  slack_success_fields=
  if [ -n "$backup_size" ]; then
    slack_success_fields="{\"title\": \"Size\", \"value\": \"$backup_size\", \"short\": true}"
  fi
  if [ -n "$backup_duration" ]; then
    if [ -n "$slack_success_fields" ]; then slack_success_fields="$slack_success_fields, "; fi
    slack_success_fields="$slack_success_fields{\"title\": \"Duration\", \"value\": \"$backup_duration\", \"short\": true}"
  fi
  slack_attachment="{\"fallback\": \"$notify_summary\", \"pretext\": \"$notify_summary\", \"text\": \"$slack_success_message\", \"color\": \"good\", \"fields\": [$slack_success_fields]}"

  notifySlack
}

function notifySlackFailure {
  slack_error_message=${1:-Unspecified error.}
  slack_attachment="{\"fallback\": \"$notify_summary $slack_error_message\", \"pretext\": \"$notify_summary\", \"text\": \"$slack_error_message\", \"color\": \"danger\"}"

  notifySlack
}

function notifySlack {
  if [ -n "$NOTIFY_SLACK_WEBHOOK_URL" ]; then
    if [ -n "$slack_attachment" ]; then
      slack_payload="{\"attachments\": [$slack_attachment]}"
    else
      slack_payload="{\"text\": \"$notify_summary\"}"
    fi
    curl --silent --show-error -X POST --data-urlencode "payload=$slack_payload" $NOTIFY_SLACK_WEBHOOK_URL
  fi
}
