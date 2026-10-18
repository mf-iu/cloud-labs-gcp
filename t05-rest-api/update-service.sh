#!/usr/bin/env bash
# Roll out a new PlaceFinder version on the Cloud Run service from t03: copy
# $PLACEFINDER_IMAGE:<tag> into Artifact Registry, deploy it by digest as a
# new revision and run the smoke test. Without a service from t03, it
# creates one with ../t03-container/deploy.sh.
# Usage: ./update-service.sh [tag]   (default: t05)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
tag="${1:-t05}"
service=$(name placefinder)
"$REPO_ROOT/t03-container/push-image.sh" "$PLACEFINDER_IMAGE:$tag"
load_state t03   # push-image.sh stored the Artifact Registry image

# A tag can later point to another image; the digest names exactly this one
image=$(gcloud artifacts docker images describe "$IMAGE" \
  --format 'value(image_summary.fully_qualified_digest)')

if ! gcloud run services describe "$service" --region "$GCP_REGION" >/dev/null 2>&1; then
  log "No service from t03; creating it with $image ..."
  "$REPO_ROOT/t03-container/deploy.sh" "$image"
else
  # gcloud waits until the new revision is ready and receives all traffic
  log "Deploying $image as new revision ..."
  gcloud run deploy "$service" --image "$image" --region "$GCP_REGION" --quiet
  gcloud run revisions list --service "$service" --region "$GCP_REGION" --limit 3 \
    --format 'table(metadata.name, status.conditions[0].status, metadata.creationTimestamp, spec.containers[0].image)'
fi
load_state t03
"$(dirname "$0")/smoke-test.sh" "$SERVICE_URL"
