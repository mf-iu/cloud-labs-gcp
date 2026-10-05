#!/usr/bin/env bash
# Delete the Cloud Run service and the Artifact Registry repository.
# Usage: ./destroy.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t03
check_login
confirm "Delete the Cloud Run service and the image repository?" || exit 0
service=$(name placefinder)
if gcloud run services describe "$service" --region "$GCP_REGION" >/dev/null 2>&1; then
  gcloud run services delete "$service" --region "$GCP_REGION" --quiet
fi
repo=$(name images)
if gcloud artifacts repositories describe "$repo" --location "$GCP_REGION" >/dev/null 2>&1; then
  gcloud artifacts repositories delete "$repo" --location "$GCP_REGION" --quiet
fi
clear_state "$LAB"
log "Done."
