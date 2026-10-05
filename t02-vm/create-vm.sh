#!/usr/bin/env bash
# Create a Compute Engine VM that installs and runs PlaceFinder via cloud-init.
# The VM uses the always free e2-micro in GCP_FREE_ZONE (a US region).
# Usage: ./create-vm.sh [git ref]   (default ref: t01)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t02
ref="${1:-t01}"
zone="${VM_ZONE:-$GCP_FREE_ZONE}"
check_login
[[ -f "$SSH_PUBLIC_KEY" ]] || die "SSH key $SSH_PUBLIC_KEY not found. Create one: ssh-keygen -t ed25519"
enable_apis compute.googleapis.com

vm=$(name "$LAB-vm")
ip=$(my_ip)
log "Creating firewall rule (SSH and port 8000 from $ip only) ..."
gcloud compute firewall-rules create "$(name "$LAB-allow")" --network default \
  --direction INGRESS --allow tcp:22,tcp:8000 --source-ranges "$ip/32" \
  --target-tags "$vm" --quiet
save_state "$LAB" FIREWALL_RULE "$(name "$LAB-allow")"

user_data=$(mktemp)
trap 'rm -f "$user_data"' EXIT
render "$(dirname "$0")/cloud-init.yaml" "REPO=$PLACEFINDER_REPO" "REF=$ref" >"$user_data"

log "Creating e2-micro with Ubuntu 24.04 in $zone ..."
gcloud compute instances create "$vm" --zone "$zone" \
  --machine-type e2-micro \
  --image-family ubuntu-2404-lts-amd64 --image-project ubuntu-os-cloud \
  --boot-disk-size 30GB --boot-disk-type pd-standard \
  --metadata-from-file "user-data=$user_data" \
  --metadata "ssh-keys=ubuntu:$(cat "$SSH_PUBLIC_KEY")" \
  --tags "$vm" --labels "$(labels "$LAB")" --quiet
save_state "$LAB" INSTANCE "$vm"
save_state "$LAB" ZONE "$zone"

public_ip=$(gcloud compute instances describe "$vm" --zone "$zone" \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
save_state "$LAB" PUBLIC_IP "$public_ip"

cat <<INFO

VM $vm is running.
  SSH:          ssh ubuntu@$public_ip   (or: gcloud compute ssh $vm --zone $zone)
  cloud-init:   ssh ubuntu@$public_ip cloud-init status --wait
  API:          http://$public_ip:8000/places?q=Erfurt
  Delete:       ./destroy-vm.sh
INFO
wait_for_http "http://$public_ip:8000/health" 900 || warn "Check the log on the VM: journalctl -u placefinder"
