#!/usr/bin/env bash

# Create a signed URL (valid for one hour) and test it: without signature,
# with a range request and with a Cross-Origin Resource Sharing (CORS) preflight
# of the map. For a PMTiles file, also print the address of the map with these
# tiles.
#
# Usage: ./sign-url.sh [object]   (default: raw/geonames/cities15000.txt)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
load_state t07
[[ -n "${BUCKET:-}" ]] || die "No bucket. Run ./create-bucket.sh first."
object="${1:-raw/geonames/cities15000.txt}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Signed by the service account of create-bucket.sh, which you may act as
# (--impersonate-service-account); anyone with the URL may read the object for
# an hour
url=$(gcloud storage sign-url "gs://$BUCKET/$object" --duration 1h \
    --impersonate-service-account "$SIGNER" --format 'value(signed_url)')
printf '\nSigned URL (1 hour):\n%s\n\n' "$url"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

log "Without signature the object is private (expect 403):"
# --write-out prints only the status code; || true: an error status is expected
# here
curl --silent --output /dev/null --write-out '%{http_code}\n' "https://storage.googleapis.com/$BUCKET/$object" || true

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

log "Range request for the first 100 bytes (expect 206 Partial Content):"
# --dump-header - prints the response headers to stdout (- means stdout);
# --range asks for bytes 0 to 99
curl --silent --dump-header - --output /dev/null --range 0-99 "$url" \
    | grep --ignore-case --extended-regexp '^HTTP|^content-range|^content-length' || true

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

log "CORS preflight of the map at http://localhost:5173 (expect Access-Control-Allow-Origin):"
# The request a browser sends before a cross-origin GET with a Range header
# (CORS preflight)
curl --silent --request OPTIONS --dump-header - --output /dev/null \
    --header "Origin: http://localhost:5173" --header "Access-Control-Request-Method: GET" \
    --header "Access-Control-Request-Headers: range" "$url" \
    | grep --ignore-case --extended-regexp '^HTTP|^access-control-allow-origin' || true

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [[ "$object" == *.pmtiles ]]; then
    # the map of PlaceFinder: python3 -m http.server 5173 --directory frontend
    # urllib.parse.quote encodes the signed URL so that it fits into a parameter
    # of another URL (safe="": also / and :)
    printf '\nMap with these tiles (URL-encoded):\nhttp://localhost:5173/?tiles=%s\n' \
        "$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$url")"
fi
