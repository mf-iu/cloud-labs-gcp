#!/usr/bin/env bash
# Delete gateway, API configurations, API, API key and service account.
# Usage: ./destroy-api-gateway.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
REGION=europe-west1      # as in create-api-gateway.sh
check_login
load_state "$LAB"
api=$(name api)
confirm "Delete API Gateway $api and its API key?" || exit 0
if gcloud api-gateway gateways describe "$api" --location "$REGION" >/dev/null 2>&1; then
  log "Deleting gateway $api (a few minutes) ..."
  gcloud api-gateway gateways delete "$api" --location "$REGION" --quiet
fi
for config in $(gcloud api-gateway api-configs list --api "$api" --format 'value(name.basename())' 2>/dev/null); do
  gcloud api-gateway api-configs delete "$config" --api "$api" --quiet
done
if gcloud api-gateway apis describe "$api" >/dev/null 2>&1; then
  gcloud api-gateway apis delete "$api" --quiet
fi
if [[ -n "${API_KEY_ID:-}" ]]; then
  # deleted keys can be restored for 30 days: gcloud services api-keys undelete
  gcloud services api-keys delete "$API_KEY_ID" --quiet || warn "API key $API_KEY_ID not found."
fi
sa="$(name apigw)@$GCP_PROJECT.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$sa" >/dev/null 2>&1; then
  gcloud iam service-accounts delete "$sa" --quiet
fi
clear_state "$LAB"
log "API Gateway deleted."
