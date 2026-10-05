#!/usr/bin/env bash
# Delete the Cloud SQL instance including its backups.
# Usage: ./destroy-db.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
load_state "$LAB"
[[ -n "${INSTANCE:-}" ]] || { log "Nothing to delete."; exit 0; }
confirm "Delete Cloud SQL instance $INSTANCE including all data?" || exit 0
gcloud sql instances delete "$INSTANCE" --quiet
clear_state "$LAB"
log "Database deleted."
