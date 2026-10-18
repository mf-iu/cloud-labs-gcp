#!/usr/bin/env bash
# Show the automated backups of the Cloud SQL instance: backup configuration,
# backups and the latest time of a point-in-time restore. Changes nothing.
# Usage: ./backups.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
load_state "$LAB"
[[ -n "${INSTANCE:-}" ]] || die "No database. Run ./create-db.sh first."

# minutes between an ISO 8601 time and now
minutes_ago() {   # minutes_ago <time>
  python3 -c 'import datetime as d, sys
print(round((d.datetime.now(d.timezone.utc) - d.datetime.fromisoformat(sys.argv[1])).total_seconds() / 60))' "$1"
}

log "Backup configuration of $INSTANCE:"
gcloud sql instances describe "$INSTANCE" --format 'yaml(settings.backupConfiguration)'

log "Backups (one a day, the latest seven are kept):"
gcloud sql backups list --instance "$INSTANCE"

if ! latest=$(gcloud sql instances get-latest-recovery-time "$INSTANCE" \
    --format 'value(latestRecoveryTime)' 2>/dev/null) || [[ -z "$latest" ]]; then
  warn "No recovery time yet: point-in-time recovery needs a first backup. Try again in a few minutes."
  exit 0
fi
cat <<INFO

Point-in-time restore possible up to $latest ($(minutes_ago "$latest") minutes ago),
back to the transaction logs of the last seven days.
Data written after the latest recovery time would be lost (RPO: a few minutes).
A restore is a clone: a new instance with a new IP address (RTO: about 10 minutes plus
the switch of the application). Not done here, it would cost a second instance:
  gcloud sql instances clone $INSTANCE $INSTANCE-restored \\
    --point-in-time <time, e.g. $latest>
INFO
