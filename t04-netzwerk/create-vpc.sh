#!/usr/bin/env bash
# Create the PlaceFinder network design from session 4 on Google Cloud:
# custom VPC with public, application and database subnets in GCP_REGION
# and firewall rules that use network tags instead of subnets.
#
# Usage: ./create-vpc.sh [--with-vm] [--with-nat]
#   --with-vm   test VM in the public subnet (SSH from your IP only)
#   --with-nat  Cloud NAT for the application subnet (about 1 USD per day!)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t04
with_vm=false
with_nat=false
for arg in "$@"; do
  case "$arg" in
    --with-vm) with_vm=true ;;
    --with-nat) with_nat=true ;;
    *) die "Unknown option: $arg" ;;
  esac
done
check_login
enable_apis compute.googleapis.com
vpc=$(name vpc)
if gcloud compute networks describe "$vpc" >/dev/null 2>&1; then
  die "VPC $vpc exists already. Run ./destroy-vpc.sh first."
fi
save_state "$LAB" VPC "$vpc"

log "Creating VPC $vpc (custom subnet mode, the VPC itself is global) ..."
gcloud compute networks create "$vpc" --subnet-mode custom --quiet

subnet() {   # subnet <name> <cidr> [extra flags]
  gcloud compute networks subnets create "$1" --network "$vpc" --region "$GCP_REGION" \
    --range "$2" "${@:3}" --quiet
}
log "Creating regional subnets in $GCP_REGION ..."
subnet "$(name public)" 10.20.0.0/24
# Private Google Access: reach Google APIs without public IP addresses
subnet "$(name app)" 10.20.10.0/24 --enable-private-ip-google-access
subnet "$(name db)" 10.20.20.0/24 --enable-private-ip-google-access

firewall() {   # firewall <name> <ports> <source flag> <target tag>
  gcloud compute firewall-rules create "$(name "$1")" --network "$vpc" \
    --direction INGRESS --allow "$2" "$3" --target-tags "$4" --quiet
}
log "Creating firewall rules: lb (443 from anywhere), app (8000 from lb), db (5432 from app) ..."
firewall t04-allow-https tcp:443 --source-ranges=0.0.0.0/0 lb
firewall t04-allow-api tcp:8000 --source-tags=lb app
firewall t04-allow-postgres tcp:5432 --source-tags=app db
# Without rules, a VPC denies all incoming and allows all outgoing traffic

if $with_nat; then
  warn "Cloud NAT costs about 0.045 USD per hour plus data. Delete it today!"
  gcloud compute routers create "$(name router)" --network "$vpc" --region "$GCP_REGION" --quiet
  gcloud compute routers nats create "$(name nat)" --router "$(name router)" \
    --region "$GCP_REGION" --auto-allocate-nat-external-ips \
    --nat-custom-subnet-ip-ranges "$(name app)" --quiet
  save_state "$LAB" NAT true
fi

if $with_vm; then
  [[ -f "$SSH_PUBLIC_KEY" ]] || die "SSH key $SSH_PUBLIC_KEY not found."
  firewall t04-allow-ssh tcp:22 "--source-ranges=$(my_ip)/32" ssh
  gcloud compute instances create "$(name "$LAB-vm")" --zone "$GCP_ZONE" \
    --machine-type e2-micro --subnet "$(name public)" \
    --image-family ubuntu-2404-lts-amd64 --image-project ubuntu-os-cloud \
    --metadata "ssh-keys=ubuntu:$(cat "$SSH_PUBLIC_KEY")" \
    --tags ssh --labels "$(labels "$LAB")" --quiet
  save_state "$LAB" INSTANCE "$(name "$LAB-vm")"
  public_ip=$(gcloud compute instances describe "$(name "$LAB-vm")" --zone "$GCP_ZONE" \
    --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
  log "Test VM: ssh ubuntu@$public_ip"
fi

log "Network created. Overview:"
gcloud compute networks subnets list --network "$vpc" \
  --format 'table(name, region.basename(), ipCidrRange, privateIpGoogleAccess)'
gcloud compute firewall-rules list --filter "network~$vpc\$" \
  --format 'table(name, sourceRanges.list(), sourceTags.list(), targetTags.list(), allowed[].map().firewall_rule().list())'
log "Delete everything with ./destroy-vpc.sh"
