#!/usr/bin/env bash
# Put Google API Gateway in front of the Cloud Run service. Only the paths in
# openapi2.yaml are passed on; everything else gets 404. Clients need an API
# key; the requests with keys of one project count against QUOTA per minute.
# Usage: ./create-api-gateway.sh   (run it again to deploy a changed openapi2.yaml)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
QUOTA=30                 # requests per minute and project of the API key
REGION=europe-west1      # API Gateway is not offered in europe-west3 (Frankfurt)
check_login
load_state t03
[[ -n "${SERVICE_URL:-}" ]] || die "No service from t03. Run ./update-service.sh first."
load_state "$LAB"
enable_apis apigateway.googleapis.com servicemanagement.googleapis.com \
  servicecontrol.googleapis.com apikeys.googleapis.com

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
render "$(dirname "$0")/openapi2.yaml" "BACKEND=$SERVICE_URL" "QUOTA=$QUOTA" >"$spec"

log "Creating API $api and configuration $config ..."
gcloud api-gateway apis describe "$api" >/dev/null 2>&1 \
  || gcloud api-gateway apis create "$api" --labels "$(labels "$LAB")"
gcloud api-gateway api-configs create "$config" --api "$api" \
  --openapi-spec "$spec" --backend-auth-service-account "$sa" --labels "$(labels "$LAB")"
if gcloud api-gateway gateways describe "$api" --location "$REGION" >/dev/null 2>&1; then
  log "Switching gateway $api to configuration $config ..."
  gcloud api-gateway gateways update "$api" --api "$api" --api-config "$config" --location "$REGION"
else
  log "Creating gateway $api in $REGION (a few minutes) ..."
  gcloud api-gateway gateways create "$api" --api "$api" --api-config "$config" \
    --location "$REGION" --labels "$(labels "$LAB")"
fi
host=$(gcloud api-gateway gateways describe "$api" --location "$REGION" \
  --format 'value(defaultHostname)')
save_state "$LAB" API_URL "https://$host"

# API keys work only for enabled services: the API has its own managed service
service=$(gcloud api-gateway apis describe "$api" --format 'value(managedService)')
log "Enabling $service ..."
enable_apis "$service"
if [[ -z "${API_KEY_ID:-}" ]]; then
  key_id="$(name key)-$(date +%Y%m%d%H%M%S)"
  log "Creating API key $key_id, restricted to $service ..."
  gcloud services api-keys create --key-id "$key_id" --display-name "PlaceFinder $LAB" \
    --api-target "service=$service" >/dev/null
  save_state "$LAB" API_KEY_ID "$key_id"
  key=$(gcloud services api-keys get-key-string "$key_id" --format 'value(keyString)')
  save_state "$LAB" API_HEADER "x-api-key: $key"
fi
load_state "$LAB"

# New keys and configurations take a few minutes to arrive at the gateway
log "Waiting until the gateway accepts the key (up to 10 minutes) ..."
start=$SECONDS
until curl --fail --silent --output /dev/null --max-time 10 --header "$API_HEADER" "https://$host/health"; do
  (( SECONDS - start < 600 )) || die "No answer with the key after 10 minutes: curl --include --header \"x-api-key: …\" https://$host/health"
  sleep 15
done
cat <<INFO

API Gateway: https://$host  ($QUOTA requests per minute and project of the API key)
  Test:        ./smoke-test.sh --gateway
  Rate limit:  ./rate-limit-test.sh
  Without key: curl --include https://$host/health
  Delete:      ./destroy-api-gateway.sh
The key is stored in ../.state/$LAB.env (API_HEADER).
INFO
