#!/usr/bin/env bash
# Check gcloud, the logins, the project and its billing account.
# Usage: ./check-cli.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

log "$(gcloud version 2>/dev/null | sed -n 1p)"
check_login
gcloud config list --format='table(core.account, core.project)'
log "Project: $GCP_PROJECT, region: $GCP_REGION, free VM zone: $GCP_FREE_ZONE"
gcloud billing projects describe "$GCP_PROJECT" \
  --format='table(billingAccountName, billingEnabled)'

if gcloud auth application-default print-access-token >/dev/null 2>&1; then
  log "Application Default Credentials (for OpenTofu and Python): OK"
else
  warn "No Application Default Credentials. Run: gcloud auth application-default login --no-launch-browser"
fi
