#!/bin/sh

BUCKET="$BACKUP_BUCKET"
BACKUP_BASEDIR="/backups"
COMPRESSED_FILE="$BACKUP_BASEDIR/`date +%F`-backup.gz"
BUCKET_DESTINATION_FILE="gs://$BUCKET/`date +%Y-%m`/`date +%F`-backup.gz"

log() {
  echo "`date \"+%F %H:%M:%S\"` [Backup Job] $1"
}

replace_placeholders() {
  DATE_VAL=`date +%F`
  echo "$1" | sed "s|%DATE%|$DATE_VAL|g" | sed "s|%BACKUP_ADDRESS%|$BUCKET_DESTINATION_FILE|g"
}

setup_service_account() {
  log "Setting up google service account..."
  # setup gsutil
  echo $GOOGLE_ACCOUNT_JSON > /tmp/account.json
  gcloud auth activate-service-account --key-file=/tmp/account.json
  rm /tmp/account.json
}

full_backup() {
  log "Cleaning up previous data (if any)..."
  rm -rf /data/backup/*
  log "Backing up..."
  PGPASSWORD="$DATABASE_PASSWORD" pg_dump \
    --compress=9 \
    -f $COMPRESSED_FILE \
    --host=$DATABASE_HOST \
    --username=$DATABASE_USER \
    --dbname=$DATABASE_NAME || {
      exit 1
    }
  log "Full backup is done."
}

mail_error() {
  if [[ ! -z "$NOTIFICATION_EMAIL_TO" ]]; then
    SUBJECT=`replace_placeholders "$EMAIL_ERROR_SUBJECT"`
    BODY=`replace_placeholders "$EMAIL_ERROR_BODY"`
    curl --request POST \
      --url https://api.sendgrid.com/v3/mail/send \
      --header "Authorization: Bearer $SENDGRID_API_KEY" \
      --header 'Content-Type: application/json' \
      --data "{
        \"personalizations\": [{\"to\": [{\"email\": \"$NOTIFICATION_EMAIL_TO\"}]}],
        \"from\": {\"email\": \"$NOTIFICATION_EMAIL_FROM\"},
        \"subject\": \"$SUBJECT\",
        \"content\": [{
          \"type\": \"text/html\",
          \"value\": \"$BODY\"
        }]
      }"
  fi
}

mail_success() {
  if [[ ! -z "$NOTIFICATION_EMAIL_TO" ]]; then
    SUBJECT=`replace_placeholders "$EMAIL_SUCCESS_SUBJECT"`
    BODY=`replace_placeholders "$EMAIL_SUCCESS_BODY"`
    curl --request POST \
      --url https://api.sendgrid.com/v3/mail/send \
      --header "Authorization: Bearer $SENDGRID_API_KEY" \
      --header 'Content-Type: application/json' \
      --data "{
        \"personalizations\": [{\"to\": [{\"email\": \"$NOTIFICATION_EMAIL_TO\"}]}],
        \"from\": {\"email\": \"$NOTIFICATION_EMAIL_FROM\"},
        \"subject\": \"$SUBJECT\",
        \"content\": [{
          \"type\": \"text/html\",
          \"value\": \"$BODY\"
        }]
      }"
  fi
}

upload() {
  log "Starting upload routine..."

  if [[ ! -f $COMPRESSED_FILE ]]; then
    log "Nothing to send to GCS. Exiting..."
    exit 1
  else
    log "Uploading..."
    # check if file exists before sending it
    # https://cloud.google.com/storage/docs/gsutil/commands/stat
    gsutil -q stat $BUCKET_DESTINATION_FILE || {
      log "File '$BUCKET_DESTINATION_FILE' does not exists. Will be uploaded now..."
      gsutil -q cp $COMPRESSED_FILE $BUCKET_DESTINATION_FILE || {
        log "ERROR: could not upload the backup!"
        exit 1
      }

      rm $COMPRESSED_FILE
      return
    }
    # file exists - nothing to do
  fi
  log "Upload routine is done."
}