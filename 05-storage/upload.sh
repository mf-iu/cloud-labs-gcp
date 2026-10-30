#!/usr/bin/env bash

# Upload a file, e.g. a PMTiles extract, into the bucket.
#
# Usage: ./upload.sh <file> [object]   (default object: tiles/<name> for .pmtiles, else raw/<name>)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

load_state t07
[[ -n "${BUCKET:-}" ]] || die "No bucket. Run ./create-bucket.sh first."
# ${1:?text} stops the script with this text if there is no first argument
file="${1:?Usage: $0 <file> [object]}"
# basename is the file name without its folder
default="raw/$(basename "$file")"
# PMTiles files go to tiles/, everything else to raw/
[[ "$file" != *.pmtiles ]] || default="tiles/$(basename "$file")"
object="${2:-$default}"
gcloud storage cp "$file" "gs://$BUCKET/$object"
log "Uploaded to gs://$BUCKET/$object"
