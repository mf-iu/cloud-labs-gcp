#!/usr/bin/env bash
# Delete the bucket with all objects and the signer service account.
# Usage: ./destroy-bucket.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t07
check_login
load_state "$LAB"
[[ -n "${BUCKET:-}" ]] || { log "Nothing to delete."; exit 0; }
confirm "Delete bucket gs://$BUCKET with all objects?" || exit 0
gcloud storage rm --recursive "gs://$BUCKET"
if [[ -n "${SIGNER:-}" ]]; then
  gcloud iam service-accounts delete "$SIGNER" --quiet
fi
clear_state "$LAB"
log "Bucket deleted."
