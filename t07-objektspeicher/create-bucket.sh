#!/usr/bin/env bash
# Create a private Cloud Storage bucket with CORS (for map tiles) and
# lifecycle rules, plus a service account that signs URLs.
# Usage: ./create-bucket.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t07
check_login
load_state "$LAB"
[[ -z "${BUCKET:-}" ]] || die "Bucket $BUCKET exists already."
enable_apis storage.googleapis.com iamcredentials.googleapis.com
cd "$(dirname "$0")"

# Bucket names are global, hence the random suffix
bucket="$(name "$(suffix)-$LAB")"
log "Creating bucket gs://$bucket in $GCP_REGION ..."
gcloud storage buckets create "gs://$bucket" --location "$GCP_REGION" \
  --uniform-bucket-level-access --public-access-prevention \
  --default-storage-class STANDARD --quiet
save_state "$LAB" BUCKET "$bucket"
gcloud storage buckets update "gs://$bucket" --update-labels "$(labels "$LAB")" \
  --cors-file cors.json --lifecycle-file lifecycle.json --quiet

# Signed URLs need a private key; instead of downloading a key file we let
# Google sign as this service account (impersonation, no secrets on disk).
account=$(name signer)
sa="$account@$GCP_PROJECT.iam.gserviceaccount.com"
if ! gcloud iam service-accounts describe "$sa" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$account" --display-name "URL signer, lab $LAB"
fi
gcloud storage buckets add-iam-policy-binding "gs://$bucket" \
  --member "serviceAccount:$sa" --role roles/storage.objectViewer >/dev/null
gcloud iam service-accounts add-iam-policy-binding "$sa" \
  --member "user:$(gcloud config get-value account 2>/dev/null)" \
  --role roles/iam.serviceAccountTokenCreator >/dev/null
save_state "$LAB" SIGNER "$sa"

log "Uploading GeoNames cities15000 as raw data ..."
gcloud storage cp "$(download_cities)" "gs://$bucket/raw/geonames/cities15000.txt"
gcloud storage ls --long --recursive "gs://$bucket"
log "Next: ./make-tiles.sh, ./upload.sh ../.state/data/erfurt.pmtiles, ./sign-url.sh tiles/erfurt.pmtiles (permissions need about a minute)"
