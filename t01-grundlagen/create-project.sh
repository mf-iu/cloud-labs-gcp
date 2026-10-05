#!/usr/bin/env bash
# Create a Google Cloud project for the course and link it to the billing
# account of the free trial. The project id is stored in .state/gcp_project.
# Usage: ./create-project.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_auth
# Project ids are global: 6-30 characters, lowercase letters, digits, hyphens
project="${GCP_PROJECT:-$(name "$(suffix)")}"

if gcloud projects describe "$project" >/dev/null 2>&1; then
  log "Project $project exists already."
else
  log "Creating project $project ..."
  gcloud projects create "$project" --name "PlaceFinder $OWNER" --labels "course=$COURSE_TAG"
fi

billing="${GCP_BILLING_ACCOUNT:-$(gcloud billing accounts list --filter=open=true \
  --format='value(name.basename())' --limit=1)}"
[[ -n "$billing" ]] || die "No open billing account. Activate the free trial in the console first."
log "Linking billing account $billing ..."
gcloud billing projects link "$project" --billing-account "$billing" >/dev/null

echo "$project" >"$STATE_DIR/gcp_project"
gcloud config set project "$project"
# OpenTofu and the client libraries bill API quota to this project
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
  gcloud auth application-default set-quota-project "$project"
else
  warn "No Application Default Credentials yet. Run: gcloud auth application-default login --no-launch-browser"
fi
log "Project $project is ready. Next: ./check-cli.sh and ./create-budget.sh"
