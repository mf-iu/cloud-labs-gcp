#!/usr/bin/env bash
# Delete the state bucket with all versions. Only do this after every
# OpenTofu configuration has been destroyed (tofu destroy)!
# Usage: ./destroy-state.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
bucket="$(name "$(suffix)-tfstate")"
gcloud storage buckets describe "gs://$bucket" >/dev/null 2>&1 || { log "No state bucket."; exit 0; }
gcloud storage ls --recursive "gs://$bucket"
confirm "Delete state bucket gs://$bucket with all state versions?" || exit 0
gcloud storage rm --recursive --all-versions "gs://$bucket"
rm --force "$STATE_DIR/backend.hcl"
log "State bucket deleted."
