#!/usr/bin/env bash
# Create the Cloud Storage bucket for the OpenTofu state (versioned,
# private) and write .state/backend.hcl for tools/tofu.sh.
# Usage: ./bootstrap-state.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
enable_apis storage.googleapis.com
bucket="$(name "$(suffix)-tfstate")"
if gcloud storage buckets describe "gs://$bucket" >/dev/null 2>&1; then
  log "State bucket gs://$bucket exists already."
else
  log "Creating state bucket gs://$bucket ..."
  gcloud storage buckets create "gs://$bucket" --location "$GCP_REGION" \
    --uniform-bucket-level-access --public-access-prevention --quiet
  # Versioning keeps older states, e.g. after a failed apply
  gcloud storage buckets update "gs://$bucket" --versioning \
    --update-labels "$(labels t08)" --quiet
fi

# The gcs backend locks the state with a lock file in the bucket
cat >"$STATE_DIR/backend.hcl" <<HCL
bucket = "$bucket"
HCL
log "Wrote $STATE_DIR/backend.hcl. Next, in the repository root: tools/tofu.sh t08-iac/infra plan"
