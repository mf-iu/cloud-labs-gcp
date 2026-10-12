#!/usr/bin/env bash
# List resources of the course project that still exist, especially those
# that cost money by the hour. Deletes nothing.
# Usage: tools/find-leftovers.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
section() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }

section "VM instances"
gcloud compute instances list --format 'table(name, zone.basename(), machineType.basename(), status)'
section "Cloud NAT routers and reserved IP addresses"
gcloud compute routers list --format 'table(name, region.basename(), network.basename())'
gcloud compute addresses list --format 'table(name, address, status)'
section "Disks and snapshots (cost storage even without a VM)"
gcloud compute disks list --format 'table(name, zone.basename(), sizeGb, status, users.map().basename().list())'
gcloud compute snapshots list --format 'table(name, diskSizeGb, sourceDisk.basename(), status)'
section "Cloud SQL instances"
gcloud sql instances list --format 'table(name, region, settings.tier, state)' 2>/dev/null || echo "Cloud SQL API not enabled"
section "Cloud Run services and functions"
gcloud run services list --format 'table(metadata.name, region, status.url)' 2>/dev/null || echo "Cloud Run API not enabled"
section "API Gateways"
gcloud api-gateway gateways list --format 'table(name.basename(), state)' 2>/dev/null || echo "API Gateway API not enabled"
section "Cloud Scheduler jobs in $GCP_REGION"
gcloud scheduler jobs list --location "$GCP_REGION" --format 'table(name.basename(), schedule, state)' 2>/dev/null || echo "Cloud Scheduler API not enabled"
section "Buckets"
gcloud storage buckets list --format 'table(name, location, labels.lab)'
section "Artifact Registry repositories"
gcloud artifacts repositories list --format 'table(name.basename(), location, sizeBytes)' 2>/dev/null || echo "Artifact Registry API not enabled"
section "Firewall rules and VPCs"
gcloud compute firewall-rules list --format 'table(name, network.basename(), sourceRanges.list())'
gcloud compute networks list --format 'table(name)'
