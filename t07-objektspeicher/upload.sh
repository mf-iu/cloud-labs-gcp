#!/usr/bin/env bash
# Upload a file, e.g. a PMTiles extract, into the bucket.
# Usage: ./upload.sh <file> [object]   (default object: tiles/<name> for .pmtiles, else raw/<name>)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

load_state t07
[[ -n "${BUCKET:-}" ]] || die "No bucket. Run ./create-bucket.sh first."
file="${1:?Usage: $0 <file> [object]}"
default="raw/$(basename "$file")"
[[ "$file" != *.pmtiles ]] || default="tiles/$(basename "$file")"
object="${2:-$default}"
gcloud storage cp "$file" "gs://$BUCKET/$object"
log "Uploaded to gs://$BUCKET/$object"
