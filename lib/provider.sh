#!/usr/bin/env bash

# Helpers for the lab scripts of this repository: first the shared helpers
# of cloud-labs-local next to this repository, then the settings in
# config.env, the helpers for all cloud labs and those for Google Cloud.
# Source this file from a script; do not execute it directly.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# ${BASH_SOURCE[0]} is this file, even when a script sources it: the repository
# is the folder above lib
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# cloud-labs-local next to this repository, unless LOCAL_LABS points elsewhere
LOCAL_LABS="${LOCAL_LABS:-$REPO_ROOT/../cloud-labs-local}"
if [[ ! -f "$LOCAL_LABS/lib/common.sh" ]]; then
    # die comes from common.sh, which is not loaded yet: print to stderr (>&2)
    # and stop
    printf 'ERROR: cloud-labs-local not found next to this repository (%s).\n' "$LOCAL_LABS" >&2
    printf 'Clone it in the WSL shell: cd ~/kurs && git clone https://github.com/mf-iu/cloud-labs-local.git\n' >&2
    exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# source runs common.sh in this shell: its settings and functions are available
# from here on
# shellcheck source=../../cloud-labs-local/lib/common.sh
source "$LOCAL_LABS/lib/common.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Settings for the cloud labs (copied from config.example.env, never
# committed). GITHUB_USER and PLACEFINDER_IMAGE come from config.env of
# cloud-labs-local.
[[ -f "$REPO_ROOT/config.env" ]] \
    || die "config.env not found: copy config.example.env to config.env in $REPO_ROOT and fill it in."

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# source runs config.env in this shell: its variables stay set
# shellcheck source=/dev/null
source "$REPO_ROOT/config.env"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# shellcheck disable=SC2034  # used by 02-vm/create-vm.sh
PLACEFINDER_REPO="https://github.com/$GITHUB_USER/placefinder.git"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Tag or label value that marks every resource of the course
# shellcheck disable=SC2034  # used by the lab scripts
COURSE_TAG="cloud-computing"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Random lowercase suffix, created once per clone, for globally unique names
suffix() {
    local file="$STATE_DIR/suffix"
    if [[ ! -s "$file" ]]; then
        # six random hex digits, e.g. 3fa9c1
        python3 -c 'import secrets; print(secrets.token_hex(3))' >"$file"
    fi
    cat "$file"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Resource name: name t02-vm -> pf-mf-t02-vm
name() {
    echo "${PREFIX}-${OWNER}-$1"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Public IPv4 address of this computer, used for firewall rules
my_ip() {
    # tr --delete '[:space:]' removes the line break at the end of the answer
    curl --fail --silent --show-error --max-time 10 https://checkip.amazonaws.com | tr --delete '[:space:]'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Password with upper and lower case letters, digits and a symbol
random_password() {
    # Python prints Pf1- and 20 random letters and digits; the program spans
    # three lines inside the single quotes
    python3 -c 'import secrets, string
chars = string.ascii_letters + string.digits
print("Pf1-" + "".join(secrets.choice(chars) for _ in range(20)))'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Google Cloud
require gcloud

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The project created by 01-account/create-project.sh, if not configured
if [[ -z "${GCP_PROJECT:-}" && -s "$STATE_DIR/gcp_project" ]]; then
    # -s: the file exists and is not empty
    GCP_PROJECT="$(cat "$STATE_DIR/gcp_project")"
fi
# gcloud reads its settings from CLOUDSDK_* variables: the project for every
# command, and no questions
export CLOUDSDK_CORE_PROJECT="${GCP_PROJECT:-}" CLOUDSDK_CORE_DISABLE_PROMPTS=1

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_auth() {
    # Succeeds only with a valid login; the token itself is discarded
    gcloud auth print-access-token >/dev/null 2>&1 \
        || die "Not logged in to Google Cloud. Run: gcloud auth login --no-launch-browser"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login() {
    check_auth
    [[ -n "${GCP_PROJECT:-}" ]] \
        || die "No project. Run 01-account/create-project.sh or set GCP_PROJECT in config.env"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# enable_apis <service> ...; idempotent, may take a minute
enable_apis() {
    # "$@" are the names of the APIs, e.g. run.googleapis.com
    gcloud services enable "$@" --quiet
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

labels() {
    echo "course=$COURSE_TAG,lab=$1"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

billing_account() {
    # --format value(...) prints only this field; basename() keeps the part
    # after the last slash
    gcloud billing projects describe "$GCP_PROJECT" --format='value(billingAccountName.basename())'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

project_number() {
    gcloud projects describe "$GCP_PROJECT" --format='value(projectNumber)'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Names of the budgets with this display name. The Budget API needs a quota
# project when called with user credentials, hence --billing-project.
# find_budgets <billing account> <display name>
find_budgets() {
    gcloud billing budgets list --billing-account "$1" --billing-project "$GCP_PROJECT" \
        --filter "displayName=$2" --format 'value(name)'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Settings for tools/tofu.sh (the google provider uses Application Default Credentials)
tofu_provider_vars() {
    # OpenTofu reads a variable x from the environment variable TF_VAR_x
    export TF_VAR_project="$GCP_PROJECT" TF_VAR_region="$GCP_REGION"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

backend_key_arg() {
    echo "prefix=$1"
}
