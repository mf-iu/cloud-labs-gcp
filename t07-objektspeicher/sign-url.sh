#!/usr/bin/env bash
# Create a signed URL (valid for one hour) and test a range request.
# Usage: ./sign-url.sh [object]   (default: raw/geonames/cities15000.txt)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
load_state t07
[[ -n "${BUCKET:-}" ]] || die "No bucket. Run ./create-bucket.sh first."
object="${1:-raw/geonames/cities15000.txt}"

url=$(gcloud storage sign-url "gs://$BUCKET/$object" --duration 1h \
  --impersonate-service-account "$SIGNER" --format 'value(signed_url)')
printf '\nSigned URL (1 hour):\n%s\n\n' "$url"

log "Without signature the object is private (expect 403):"
curl --silent --output /dev/null --write-out '%{http_code}\n' "https://storage.googleapis.com/$BUCKET/$object"

log "Range request for the first 100 bytes (expect 206 Partial Content):"
curl --silent --dump-header - --output /dev/null --range 0-99 "$url" | grep --ignore-case --extended-regexp '^HTTP|^content-range|^content-length'
