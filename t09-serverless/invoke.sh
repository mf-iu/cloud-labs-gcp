#!/usr/bin/env bash

# Call the function with your identity token and show the result.
#
# Usage: ./invoke.sh [YYYY-MM-DD]   (default: yesterday)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
# output -raw prints one output of the OpenTofu configuration without quotes
url=$("$REPO_ROOT/tools/tofu.sh" "$REPO_ROOT/t09-serverless/infra" output -raw function_url)
# The function accepts only authenticated calls: gcloud prints an identity token
# of your login. ${1:-} is the date given as argument, or empty.
curl --fail --silent --show-error --header "Authorization: Bearer $(gcloud auth print-identity-token)" "$url?date=${1:-}"
echo
