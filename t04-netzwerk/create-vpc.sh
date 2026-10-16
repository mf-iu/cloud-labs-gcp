#!/usr/bin/env bash
# Create the PlaceFinder network design from session 4 on Google Cloud:
# custom VPC with public, application and database subnets in GCP_REGION
# and firewall rules that use network tags instead of subnets.
#
# Usage: ./create-vpc.sh [--with-vm] [--with-nat]
#   --with-vm   two test VMs: a bastion in the public subnet (SSH from your IP
#               only) and a VM without external address in the application
#               subnet (SSH only from the bastion); check with ./check-vpc.sh
#   --with-nat  Cloud NAT for the application subnet (charged per VM and hour)
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
clear_state "$LAB"   # values of an earlier run
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
  warn "Cloud NAT costs 0.0014 USD per VM and hour, 0.005 USD per NAT address and hour, plus data. Delete it today!"
  gcloud compute routers create "$(name router)" --network "$vpc" --region "$GCP_REGION" --quiet
  gcloud compute routers nats create "$(name nat)" --router "$(name router)" \
    --region "$GCP_REGION" --auto-allocate-nat-external-ips \
    --nat-custom-subnet-ip-ranges "$(name app)" --quiet
  save_state "$LAB" NAT true
fi

if $with_vm; then
  [[ -f "$SSH_PUBLIC_KEY" ]] || die "SSH key $SSH_PUBLIC_KEY not found. Create it in the WSL shell, not in the dev container: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
  firewall t04-allow-ssh tcp:22 "--source-ranges=$(my_ip)/32" ssh
  firewall t04-allow-ssh-from-bastion tcp:22 --source-tags=ssh app

  vm() {   # vm <name> <subnet> <network tag> <options for the external address...>
    gcloud compute instances create "$(name "$LAB-$1")" --zone "$GCP_ZONE" \
      --machine-type e2-micro --subnet "$(name "$2")" "${@:4}" \
      --image-family ubuntu-2404-lts-amd64 --image-project ubuntu-os-cloud \
      --metadata "ssh-keys=ubuntu:$(cat "$SSH_PUBLIC_KEY")" \
      --tags "$3" --labels "$(labels "$LAB")" --quiet
  }
  log "Creating the bastion in subnet public and a private VM in subnet app ..."
  vm bastion public ssh
  vm private app app --no-address
  save_state "$LAB" INSTANCES "$(name "$LAB-bastion") $(name "$LAB-private")"
  save_state "$LAB" ZONE "$GCP_ZONE"
  ip_of() {   # ip_of <name> <field>
    gcloud compute instances describe "$(name "$LAB-$1")" --zone "$GCP_ZONE" --format "value($2)"
  }
  bastion_ip=$(ip_of bastion 'networkInterfaces[0].accessConfigs[0].natIP')
  private_ip=$(ip_of private 'networkInterfaces[0].networkIP')
  save_state "$LAB" SSH_USER ubuntu
  save_state "$LAB" BASTION_IP "$bastion_ip"
  save_state "$LAB" PRIVATE_IP "$private_ip"
  log "Bastion:    ssh ubuntu@$bastion_ip"
  log "Private VM: ssh -J ubuntu@$bastion_ip ubuntu@$private_ip"
  log "Check both: ./check-vpc.sh (the VMs need about a minute to start SSH)"
fi

log "Network created. Overview:"
gcloud compute networks subnets list --network "$vpc" \
  --format 'table(name, region.basename(), ipCidrRange, privateIpGoogleAccess)'
gcloud compute firewall-rules list --filter "network~$vpc\$" \
  --format 'table(name, sourceRanges.list(), sourceTags.list(), targetTags.list(), allowed[].map().firewall_rule().list())'
log "Delete everything with ./destroy-vpc.sh"
