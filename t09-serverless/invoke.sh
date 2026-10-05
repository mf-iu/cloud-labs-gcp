#!/usr/bin/env bash
# Call the function with your identity token and show the result.
# Usage: ./invoke.sh [YYYY-MM-DD]   (default: yesterday)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
url=$("$REPO_ROOT/tools/tofu.sh" "$REPO_ROOT/t09-serverless/infra" output -raw function_url)
curl -fsS -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$url?date=${1:-}"
echo
