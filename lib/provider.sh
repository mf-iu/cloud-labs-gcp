#!/usr/bin/env bash
# Helpers for the lab scripts of this repository: first the shared helpers
# of cloud-labs-local next to this repository, then the settings in
# config.env, the helpers for all cloud labs and those for Google Cloud.
# Source this file from a script; do not execute it directly.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_LABS="${LOCAL_LABS:-$REPO_ROOT/../cloud-labs-local}"
if [[ ! -f "$LOCAL_LABS/lib/common.sh" ]]; then
  printf 'ERROR: cloud-labs-local not found next to this repository (%s).\n' "$LOCAL_LABS" >&2
  printf 'Clone it in the WSL shell: cd ~/kurs && git clone https://github.com/mf-iu/cloud-labs-local.git\n' >&2
  exit 1
fi
# shellcheck source=../../cloud-labs-local/lib/common.sh
source "$LOCAL_LABS/lib/common.sh"

# Settings for the cloud labs (copied from config.example.env, never
# committed). GITHUB_USER and PLACEFINDER_IMAGE come from config.env of
# cloud-labs-local.
[[ -f "$REPO_ROOT/config.env" ]] \
  || die "config.env not found: copy config.example.env to config.env in $REPO_ROOT and fill it in."
# shellcheck source=/dev/null
source "$REPO_ROOT/config.env"
# shellcheck disable=SC2034  # used by 02-vm/create-vm.sh
PLACEFINDER_REPO="https://github.com/$GITHUB_USER/placefinder.git"

# Tag or label value that marks every resource of the course
# shellcheck disable=SC2034  # used by the lab scripts
COURSE_TAG="cloud-computing"

# Random lowercase suffix, created once per clone, for globally unique names
suffix() {
  local file="$STATE_DIR/suffix"
  if [[ ! -s "$file" ]]; then
    python3 -c 'import secrets; print(secrets.token_hex(3))' >"$file"
  fi
  cat "$file"
}

# Resource name: name t02-vm -> pf-mf-t02-vm
name() { echo "${PREFIX}-${OWNER}-$1"; }

# Public IPv4 address of this computer, used for firewall rules
my_ip() { curl --fail --silent --show-error --max-time 10 https://checkip.amazonaws.com | tr --delete '[:space:]'; }

# Password with upper and lower case letters, digits and a symbol
random_password() {
  python3 -c 'import secrets, string
chars = string.ascii_letters + string.digits
print("Pf1-" + "".join(secrets.choice(chars) for _ in range(20)))'
}

# Google Cloud
require gcloud
# The project created by 01-account/create-project.sh, if not configured
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
    || die "No project. Run 01-account/create-project.sh or set GCP_PROJECT in config.env"
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
