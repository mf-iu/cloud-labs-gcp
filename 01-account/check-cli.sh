#!/usr/bin/env bash

# Check gcloud, the logins, the project and its billing account.
# First, without config.env and login: the tools of the provider, and
# cloud-labs-local and placefinder next to this repository. With
# --tools-only, only that: the dev container runs it so when it is created,
# after tools/check-tools.sh of cloud-labs-local.
#
# Usage: ./check-cli.sh [--tools-only]

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Without errexit: a missing tool is reported, and the script goes on with the
# next one
set -o nounset -o pipefail
# Absolute path of the folder above this script, i.e. of the repository
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# report <status> <tool> <text>
report() {
    local color=32
    # { ...; } groups commands: both run if the status is not OK (31 = red, 32 =
    # green)
    [[ "$1" == OK ]] || { color=31; failed=1; }
    # %-8s prints the text left-aligned in a column 8 characters wide
    printf '  \033[1;%sm%-8s\033[0m %-16s %s\n' "$color" "$1" "$2" "$3"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# version_ge 2.32.1 2.32 -> true
version_ge() {
    # Sort both versions as versions (2.9 before 2.10); if the minimum comes
    # first, the version is high enough
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort --version-sort | head --lines 1)" == "$2" ]]
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# check <tool> <minimum version or -> <command printing the version ...>
check() {
    local tool=$1 min=$2 version
    # shift 2 drops tool and minimum; "$@" is then the command that prints the
    # version
    shift 2
    if ! command -v "$tool" >/dev/null 2>&1; then
        report MISSING "$tool" "not installed"
        return
    fi
    # Run the command and keep the first number like 1.2 or 1.2.3 of its output
    version="$("$@" 2>&1 | grep --only-matching --extended-regexp '[0-9]+\.[0-9]+(\.[0-9]+)?' | sed --quiet 1p)"
    if [[ "$min" != - ]] && ! version_ge "${version:-0}" "$min"; then
        report "TOO OLD" "$tool" "${version:-unknown}, at least $min needed"
    else
        report OK "$tool" "${version:-installed}"
    fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

printf '\033[1;36m==>\033[0m Tools of the provider and folders next to this repository\n'
check gcloud - gcloud --version
check bq - bq version
for dir in cloud-labs-local placefinder; do
    if [[ -d "$repo_root/../$dir" ]]; then
        report OK "$dir" "$(cd "$repo_root/../$dir" && pwd)"
    else
        report MISSING "$dir" "clone it next to this repository (cloud-labs-local/00-setup)"
    fi
done
if (( failed )); then
    printf '\n\033[1;31mSomething is missing.\033[0m Clone the folders in the WSL shell, then\n'
    printf 'rebuild the dev container (VS Code: "Dev Containers: Rebuild Container").\n'
    exit 1
fi
# ${1:-} is the first argument, or empty if there is none
[[ "${1:-}" != --tools-only ]] || exit 0

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# sed --quiet 1p prints only the first line
log "$(gcloud version 2>/dev/null | sed --quiet 1p)"
check_login
# --format table(...) prints the chosen fields as a table
gcloud config list --format='table(core.account, core.project)'
log "Project: $GCP_PROJECT, region: $GCP_REGION, free VM zone: $GCP_FREE_ZONE"
gcloud billing projects describe "$GCP_PROJECT" \
    --format='table(billingAccountName, billingEnabled)'

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# OpenTofu and the Python libraries use a login of their own, the Application
# Default Credentials
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    log "Application Default Credentials (for OpenTofu and Python): OK"
else
    warn "No Application Default Credentials. Run: gcloud auth application-default login --no-launch-browser"
fi
