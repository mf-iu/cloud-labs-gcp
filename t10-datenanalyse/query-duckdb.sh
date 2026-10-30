#!/usr/bin/env bash

# Run query_duckdb.py with the HMAC key of the reader service account.
#
# Usage: ./query-duckdb.sh

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

require uv
check_login
cd "$(dirname "$0")"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

tofu_out() {
    # output -raw prints one output of the OpenTofu configuration without quotes
    "$REPO_ROOT/tools/tofu.sh" infra output -raw "$1"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

bucket=$(tofu_out bucket)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Passed as environment variables, so the secret does not show up in "ps"
GCS_HMAC_ID=$(tofu_out hmac_access_id)
GCS_HMAC_SECRET=$(tofu_out hmac_secret)
# export passes the HMAC key to uv and DuckDB, which reads buckets with it
export GCS_HMAC_ID GCS_HMAC_SECRET
uv run query_duckdb.py "$bucket"
