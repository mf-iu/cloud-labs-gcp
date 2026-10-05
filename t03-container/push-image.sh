#!/usr/bin/env bash
# Push a PlaceFinder image into an Artifact Registry repository.
# Usage: ./push-image.sh [source image]   (default: $PLACEFINDER_IMAGE:t03)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t03
require docker
check_login
enable_apis artifactregistry.googleapis.com
source_image="${1:-$PLACEFINDER_IMAGE:t03}"
repo=$(name images)
host="$GCP_REGION-docker.pkg.dev"

if ! gcloud artifacts repositories describe "$repo" --location "$GCP_REGION" >/dev/null 2>&1; then
  log "Creating Artifact Registry repository $repo ..."
  gcloud artifacts repositories create "$repo" --location "$GCP_REGION" \
    --repository-format docker --labels "$(labels "$LAB")" --quiet
fi

# Docker uses gcloud as credential helper for this registry
gcloud auth configure-docker "$host" --quiet

if ! docker image inspect "$source_image" >/dev/null 2>&1; then
  log "Pulling $source_image ..."
  docker pull --platform linux/amd64 "$source_image"
fi
target="$host/$GCP_PROJECT/$repo/placefinder:${source_image##*:}"
docker tag "$source_image" "$target"
docker push "$target"
save_state "$LAB" IMAGE "$target"
log "Pushed $target"
