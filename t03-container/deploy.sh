#!/usr/bin/env bash
# Run the image from push-image.sh on Cloud Run (public, scales to zero).
# Usage: ./deploy.sh [image]   (default: image pushed by push-image.sh)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t03
check_login
enable_apis run.googleapis.com
load_state "$LAB"
image="${1:-${IMAGE:-}}"
[[ -n "$image" ]] || die "No image. Run ./push-image.sh first or pass an image."

service=$(name placefinder)
log "Deploying $service with $image ..."
gcloud run deploy "$service" --image "$image" --region "$GCP_REGION" \
  --port 8000 --cpu 1 --memory 512Mi \
  --min-instances 0 --max-instances 2 \
  --allow-unauthenticated --labels "$(labels "$LAB")" --quiet
url=$(gcloud run services describe "$service" --region "$GCP_REGION" --format 'value(status.url)')
save_state "$LAB" SERVICE_URL "$url"

cat <<INFO

URL:   $url
The service scales to zero when idle; the first request then takes a moment.
Logs:  gcloud run services logs read $service --region $GCP_REGION --limit 20
INFO
wait_for_http "$url/health" 300
