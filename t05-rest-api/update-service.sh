#!/usr/bin/env bash
# Roll out a new PlaceFinder version on the Cloud Run service from t03.
# Pushes $PLACEFINDER_IMAGE:<tag> into Artifact Registry first.
# Usage: ./update-service.sh [tag]   (default: t05)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
tag="${1:-t05}"
service=$(name placefinder)
gcloud run services describe "$service" --region "$GCP_REGION" >/dev/null 2>&1 \
  || die "No service from t03. Run ../t03-container/deploy.sh first."

"$REPO_ROOT/t03-container/push-image.sh" "$PLACEFINDER_IMAGE:$tag"
load_state t03   # push-image.sh stored the new image

log "Deploying $IMAGE as new revision ..."
gcloud run deploy "$service" --image "$IMAGE" --region "$GCP_REGION" --quiet
gcloud run revisions list --service "$service" --region "$GCP_REGION" \
  --format 'table(metadata.name, status.conditions[0].status, metadata.creationTimestamp)'
log "Test it with: ./smoke-test.sh $SERVICE_URL"
