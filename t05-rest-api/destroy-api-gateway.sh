#!/usr/bin/env bash
# Delete gateway, API configurations, API and service account.
# Usage: ./destroy-api-gateway.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
check_login
api=$(name api)
confirm "Delete API Gateway $api?" || exit 0
if gcloud api-gateway gateways describe "$api" --location "$GCP_REGION" >/dev/null 2>&1; then
  gcloud api-gateway gateways delete "$api" --location "$GCP_REGION" --quiet
fi
for config in $(gcloud api-gateway api-configs list --api "$api" --format 'value(name.basename())' 2>/dev/null); do
  gcloud api-gateway api-configs delete "$config" --api "$api" --quiet
done
if gcloud api-gateway apis describe "$api" >/dev/null 2>&1; then
  gcloud api-gateway apis delete "$api" --quiet
fi
sa="$(name apigw)@$GCP_PROJECT.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$sa" >/dev/null 2>&1; then
  gcloud iam service-accounts delete "$sa" --quiet
fi
clear_state "$LAB"
log "API Gateway deleted."
