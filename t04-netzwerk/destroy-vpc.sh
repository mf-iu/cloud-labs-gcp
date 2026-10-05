#!/usr/bin/env bash
# Delete everything created by create-vpc.sh, in reverse order.
# Usage: ./destroy-vpc.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t04
check_login
load_state "$LAB"
[[ -n "${VPC:-}" ]] || { log "Nothing to delete."; exit 0; }
confirm "Delete VPC $VPC with subnets, firewall rules, Cloud NAT and test VM?" || exit 0

if [[ -n "${INSTANCE:-}" ]]; then
  gcloud compute instances delete "$INSTANCE" --zone "$GCP_ZONE" --quiet
fi
if [[ -n "${NAT:-}" ]]; then
  gcloud compute routers delete "$(name router)" --region "$GCP_REGION" --quiet
fi
for rule in $(gcloud compute firewall-rules list --filter "network~$VPC\$" --format 'value(name)'); do
  gcloud compute firewall-rules delete "$rule" --quiet
done
for subnet in "$(name public)" "$(name app)" "$(name db)"; do
  gcloud compute networks subnets delete "$subnet" --region "$GCP_REGION" --quiet || true
done
gcloud compute networks delete "$VPC" --quiet
clear_state "$LAB"
log "Network deleted."
