#!/usr/bin/env bash
# Google Cloud specific helpers. Source after lib/common.sh.

require gcloud
# The project created by t01-grundlagen/create-project.sh, if not configured
if [[ -z "${GCP_PROJECT:-}" && -s "$STATE_DIR/gcp_project" ]]; then
  GCP_PROJECT="$(cat "$STATE_DIR/gcp_project")"
fi
export CLOUDSDK_CORE_PROJECT="${GCP_PROJECT:-}" CLOUDSDK_CORE_DISABLE_PROMPTS=1

check_auth() {
  gcloud auth print-access-token >/dev/null 2>&1 \
    || die "Not logged in to Google Cloud. Run: gcloud auth login --no-launch-browser"
}

check_login() {
  check_auth
  [[ -n "${GCP_PROJECT:-}" ]] \
    || die "No project. Run t01-grundlagen/create-project.sh or set GCP_PROJECT in config.env"
}

enable_apis() {   # enable_apis <service> ...; idempotent, may take a minute
  gcloud services enable "$@" --quiet
}

labels() { echo "course=$COURSE_TAG,lab=$1"; }

billing_account() {
  gcloud billing projects describe "$GCP_PROJECT" --format='value(billingAccountName.basename())'
}

project_number() { gcloud projects describe "$GCP_PROJECT" --format='value(projectNumber)'; }

# Names of the budgets with this display name. The Budget API needs a quota
# project when called with user credentials, hence --billing-project.
find_budgets() {   # find_budgets <billing account> <display name>
  gcloud billing budgets list --billing-account "$1" --billing-project "$GCP_PROJECT" \
    --filter "displayName=$2" --format 'value(name)'
}

# Settings for tools/tofu.sh (the google provider uses Application Default Credentials)
tofu_provider_vars() { export TF_VAR_project="$GCP_PROJECT" TF_VAR_region="$GCP_REGION"; }
backend_key_arg() { echo "prefix=$1"; }
