#!/usr/bin/env bash
# Put Google API Gateway in front of the Cloud Run service. Only the
# paths in openapi2.yaml are passed on; everything else gets 404.
# Usage: ./create-api-gateway.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
check_login
load_state t03
[[ -n "${SERVICE_URL:-}" ]] || die "No service from t03. Run ../t03-container/deploy.sh first."
enable_apis apigateway.googleapis.com servicemanagement.googleapis.com servicecontrol.googleapis.com

api=$(name api)
config="$api-$(date +%Y%m%d%H%M%S)"
account=$(name apigw)
sa="$account@$GCP_PROJECT.iam.gserviceaccount.com"

# The gateway calls the backend with the identity of this service account
if ! gcloud iam service-accounts describe "$sa" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$account" --display-name "API Gateway backend, lab $LAB"
fi
gcloud run services add-iam-policy-binding "$(name placefinder)" --region "$GCP_REGION" \
  --member "serviceAccount:$sa" --role roles/run.invoker >/dev/null

spec=$(mktemp --suffix .yaml)
trap 'rm --force "$spec"' EXIT
render "$(dirname "$0")/openapi2.yaml" "BACKEND=$SERVICE_URL" >"$spec"

log "Creating API $api and configuration $config ..."
gcloud api-gateway apis describe "$api" >/dev/null 2>&1 \
  || gcloud api-gateway apis create "$api" --labels "$(labels "$LAB")"
gcloud api-gateway api-configs create "$config" --api "$api" \
  --openapi-spec "$spec" --backend-auth-service-account "$sa"
log "Creating gateway in $GCP_REGION (a few minutes) ..."
gcloud api-gateway gateways create "$api" --api "$api" --api-config "$config" \
  --location "$GCP_REGION" --labels "$(labels "$LAB")"
host=$(gcloud api-gateway gateways describe "$api" --location "$GCP_REGION" \
  --format 'value(defaultHostname)')
save_state "$LAB" API_URL "https://$host"

cat <<INFO

API Gateway: https://$host
  Test:    ./smoke-test.sh https://$host
  Delete:  ./destroy-api-gateway.sh
INFO
