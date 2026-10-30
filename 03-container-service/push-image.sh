#!/usr/bin/env bash

# Push a PlaceFinder image into an Artifact Registry repository.
#
# Usage: ./push-image.sh [source image]   (default: $PLACEFINDER_IMAGE:t03)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

require_github_user   # PLACEFINDER_IMAGE and PLACEFINDER_REPO need it

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

LAB=t03
require docker
check_login
enable_apis artifactregistry.googleapis.com
# The image given as argument, otherwise ghcr.io/<github-user>/placefinder:t03
source_image="${1:-$PLACEFINDER_IMAGE:t03}"
repo=$(name images)
host="$GCP_REGION-docker.pkg.dev"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ! gcloud artifacts repositories describe "$repo" --location "$GCP_REGION" >/dev/null 2>&1; then
    log "Creating Artifact Registry repository $repo ..."
    gcloud artifacts repositories create "$repo" --location "$GCP_REGION" \
        --repository-format docker --labels "$(labels "$LAB")" --quiet
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Docker uses gcloud as credential helper for this registry
# Lets docker log in to the registry with the login of gcloud
gcloud auth configure-docker "$host" --quiet

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Pull the image only if it is not there already; --platform linux/amd64 because
# Cloud Run runs this architecture
if ! docker image inspect "$source_image" >/dev/null 2>&1; then
    check_public_image "$source_image" \
        || die "Cannot pull $source_image without login: it does not exist or is private. Run ../../cloud-labs-local/02-container/publish-image.sh and make the package public on GitHub."
    log "Pulling $source_image ..."
    docker pull --platform linux/amd64 "$source_image"
fi
# ${x##*:} keeps the text after the last colon: the tag, e.g. t03
target="$host/$GCP_PROJECT/$repo/placefinder:${source_image##*:}"
docker tag "$source_image" "$target"
docker push "$target"
save_state "$LAB" IMAGE "$target"
log "Pushed $target"
