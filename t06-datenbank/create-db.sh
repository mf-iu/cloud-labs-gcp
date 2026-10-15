#!/usr/bin/env bash
# Create a Cloud SQL for PostgreSQL instance (Enterprise edition, shared
# core db-f1-micro) that only accepts connections from your IP address.
# Takes about 10 minutes.
# Usage: ./create-db.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
load_state "$LAB"
[[ -z "${INSTANCE:-}" ]] || die "Instance $INSTANCE exists already. Run ./destroy-db.sh first."
enable_apis sqladmin.googleapis.com

# Names of deleted instances stay blocked for a week, hence the suffix
instance=$(name "$LAB-db-$(date +%m%d%H%M)")
password=$(random_password)
ip=$(my_ip)

log "Creating Cloud SQL instance $instance (PostgreSQL 17, db-f1-micro, 10 GB) ..."
gcloud sql instances create "$instance" --region "$GCP_REGION" \
  --database-version POSTGRES_17 --edition ENTERPRISE --tier db-f1-micro \
  --storage-size 10 --storage-type SSD \
  --root-password "$password" --authorized-networks "$ip/32" \
  --labels "$(labels "$LAB")" --quiet
save_state "$LAB" INSTANCE "$instance"

gcloud sql databases create placefinder --instance "$instance" --quiet
# The instance has a single IP address of type PRIMARY (public)
host=$(gcloud sql instances describe "$instance" --format 'value(ipAddresses[0].ipAddress)')
save_state "$LAB" DATABASE_URL "postgresql://postgres:$password@$host:5432/placefinder?sslmode=require"

cat <<INFO

Database ready: $host
  Load data:   ./load-cities.sh
  Queries:     ./query.sh       (interactive: ./query.sh --interactive)
  Delete:      ./destroy-db.sh  (do not keep it running!)
The connection string is stored in .state/$LAB.env.
INFO
