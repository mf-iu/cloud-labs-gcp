#!/usr/bin/env bash

# Delete the VM (with its boot disk) and the firewall rule.
#
# Usage: ./destroy-vm.sh

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

LAB=t02
check_login
# Read what create-vm.sh saved in .state/t02.env
load_state "$LAB"
# Both joined are empty only if neither exists; { ...; } groups the two commands
[[ -n "${INSTANCE:-}${FIREWALL_RULE:-}" ]] || { log "Nothing to delete."; exit 0; }
confirm "Delete VM ${INSTANCE:-?} and its firewall rule?" || exit 0

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [[ -n "${INSTANCE:-}" ]]; then
    gcloud compute instances delete "$INSTANCE" --zone "$ZONE" --quiet
fi
if [[ -n "${FIREWALL_RULE:-}" ]]; then
    gcloud compute firewall-rules delete "$FIREWALL_RULE" --quiet
fi
clear_state "$LAB"
log "VM deleted."
