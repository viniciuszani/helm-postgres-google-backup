#!/bin/bash
set -e
set -o pipefail

if [[ -z `which gcloud` ]] || [[ -z `which gsutil` ]]; then
  echo "gcloud and gsutil are needed. Install it and log in (gcloud init) before proceeding."
  exit 1
fi

if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]; then
  echo "Usage: $0 [google-project-name] [bucket-name] [bucket-location] [bucket-storage-class]"
  echo ""
  echo "This tool creates the backup bucket in GCloud and the service account that will be used by the Helm chart to perform backups."
  echo "A service-account-name.json will be generated in the root folder. Store it safely!"
  echo ""
  echo "Example: create a service account and host the backups in south america in a coldline bucket."
  echo "  $0 my-project-1234 production-backups southamerica-east1 coldline"
  echo "  "
  echo "More information:"
  echo "  - Storage classes: https://cloud.google.com/storage/docs/storage-classes"
  echo "  - Locations: https://cloud.google.com/storage/docs/locations"
  echo ""
  exit 1
fi

BUCKET_PROJECT="$1"
BUCKET_NAME="$2"
BUCKET_LOCATION="$3"
BUCKET_STORAGE_CLASS="$4"
SERVICE_ACCOUNT="$BUCKET_NAME"

# create the bucket if it does not exist
gsutil ls -L -b gs://$BUCKET_NAME/ || {
  echo "The bucket '$BUCKET_NAME' does not exist and will be created now."
  gsutil mb -p $BUCKET_PROJECT -c $BUCKET_STORAGE_CLASS -l $BUCKET_LOCATION -b on gs://$BUCKET_NAME/
}

# create the service account and provide the JSON to be used in the deploy
gcloud iam service-accounts describe $SERVICE_ACCOUNT@$BUCKET_PROJECT.iam.gserviceaccount.com || {
  echo "Creating the service account '$SERVICE_ACCOUNT'..."
  gcloud iam service-accounts create $SERVICE_ACCOUNT

  echo "Making the service account the bucket owner, but only allowing it to create and list objects (not delete or downloading)..."
  gsutil iam ch serviceAccount:$SERVICE_ACCOUNT@$BUCKET_PROJECT.iam.gserviceaccount.com:roles/storage.objectCreator gs://$BUCKET_NAME/
  gsutil iam ch serviceAccount:$SERVICE_ACCOUNT@$BUCKET_PROJECT.iam.gserviceaccount.com:roles/storage.objectViewer gs://$BUCKET_NAME/

  if [[ ! -f ".$SERVICE_ACCOUNT.json" ]]; then
    echo "Creating the service account json to be used in the deployment"
    echo "Please note that it will be stored in your computer. DO NOT COMMIT IT."
    gcloud iam service-accounts keys create ./.$SERVICE_ACCOUNT.json --iam-account $SERVICE_ACCOUNT@$BUCKET_PROJECT.iam.gserviceaccount.com
  fi
}

