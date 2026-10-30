#!/usr/bin/env bash

# Upload a trained model to the location that /estimate reads at start-up
# and deploy a new revision so that new instances load the model.
#
# Usage: ./upload-model.sh <model.joblib>

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
# ${1:?text} stops the script with this text if there is no first argument
model="${1:?Usage: $0 <model file>}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

tofu_out() {
    # output -raw prints one output of the OpenTofu configuration without quotes
    "$REPO_ROOT/tools/tofu.sh" "$REPO_ROOT/t11-ml/infra" output -raw "$1"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

uri=$(tofu_out model_uri)
gcloud storage cp "$model" "$uri"
log "Uploaded to $uri"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# A changed environment variable creates a new revision with fresh instances
# A changed environment variable makes Cloud Run start a new revision, which
# loads the new model
gcloud run services update "$(tofu_out service_name)" --region "$GCP_REGION" \
    --update-env-vars "MODEL_UPLOADED=$(date --utc +%Y%m%dT%H%M%SZ)" --quiet
log "New revision deployed."
