#!/usr/bin/env bash

# Roll out a new PlaceFinder version on the Cloud Run service from t03: copy
# $PLACEFINDER_IMAGE:<tag> into Artifact Registry, deploy it by digest as a
# new revision and run the smoke test. Without a service from t03, it
# creates one with ./deploy.sh.
#
# Usage: ./update-service.sh [tag]   (default: t05)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

require_github_user   # PLACEFINDER_IMAGE and PLACEFINDER_REPO need it

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
tag="${1:-t05}"
service=$(name placefinder)
# Copy the image from ghcr.io into Artifact Registry; push-image.sh saves its
# address in IMAGE
"$REPO_ROOT/03-container-service/push-image.sh" "$PLACEFINDER_IMAGE:$tag"
load_state t03   # push-image.sh stored the Artifact Registry image

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# A tag can later point to another image; the digest names exactly this one
# The address with the digest (…@sha256:…) names exactly this image, even if the
# tag moves later
image=$(gcloud artifacts docker images describe "$IMAGE" \
    --format 'value(image_summary.fully_qualified_digest)')

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ! gcloud run services describe "$service" --region "$GCP_REGION" >/dev/null 2>&1; then
    log "No service from t03; creating it with $image ..."
    "$REPO_ROOT/03-container-service/deploy.sh" "$image"
else
    # gcloud waits until the new revision is ready and receives all traffic
    log "Deploying $image as new revision ..."
    gcloud run deploy "$service" --image "$image" --region "$GCP_REGION" --quiet
    # --format table(...) prints the chosen fields of the three newest revisions
    # as a table
    gcloud run revisions list --service "$service" --region "$GCP_REGION" --limit 3 \
        --format 'table(metadata.name, status.conditions[0].status, metadata.creationTimestamp, spec.containers[0].image)'
fi
# SERVICE_URL from the state of deploy.sh
load_state t03
# The smoke test wrapper next to this script
"$(dirname "$0")/smoke-test.sh" "$SERVICE_URL"
