#!/usr/bin/env bash

# Run SQL in BigQuery: on the own external table and on the public
# Overture Maps dataset. Each query may bill at most 20 GB, the free tier
# covers 1 TiB of queries per month.
#
# Usage: ./bigquery.sh ["SQL"]

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

require bq
check_login
cd "$(dirname "$0")"
# output -raw prints one output of the OpenTofu configuration without quotes
dataset=$("$REPO_ROOT/tools/tofu.sh" infra output -raw dataset)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# query <title> <sql>
query() {
    printf '\n\033[1;36m--- %s\033[0m\n' "$1"
    # --maximum_bytes_billed stops a query that would scan more than 20 GB
    bq query --project_id "$GCP_PROJECT" --use_legacy_sql=false \
        --maximum_bytes_billed=20000000000 --format=pretty "$2"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [[ -n "${1:-}" ]]; then
    query "Own query" "$1"
    exit 0
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The SQL is a text in double quotes over several lines; \` is a backtick for
# BigQuery, not a command substitution
query "External table: largest places per country" "
  SELECT country_code, COUNT(*) AS places,
         ARRAY_AGG(name ORDER BY population DESC LIMIT 1)[OFFSET(0)] AS largest
  FROM \`$GCP_PROJECT.$dataset.places\`
  GROUP BY country_code ORDER BY places DESC LIMIT 10"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

query "External table: distance from Erfurt with GEOGRAPHY" "
  SELECT name, population,
         ROUND(ST_DISTANCE(ST_GEOGFROMWKB(geom), ST_GEOGPOINT(11.03, 50.98)) / 1000) AS km
  FROM \`$GCP_PROJECT.$dataset.places\`
  WHERE country_code = 'DE'
  ORDER BY km LIMIT 10"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Overture Maps in the BigQuery public datasets (data stored in the US)
query "Overture Maps: places around Erfurt" "
  SELECT names.primary AS name, ROUND(confidence, 2) AS confidence
  FROM \`bigquery-public-data.overture_maps.place\`
  WHERE bbox.xmin BETWEEN 10.90 AND 11.20 AND bbox.ymin BETWEEN 50.90 AND 51.10
  ORDER BY confidence DESC LIMIT 15"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

log "Bytes processed per query: see the job history in the BigQuery console."
