#!/usr/bin/env bash

# Delete the budget created by create-budget.sh.
#
# Usage: ./delete-budget.sh

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
billing=$(billing_account)
budget_name=$(name monthly-budget)
budgets=$(find_budgets "$billing" "$budget_name")
# { ...; } groups both commands: they run if there is no budget
[[ -n "$budgets" ]] || { log "No budget $budget_name."; exit 0; }
confirm "Delete budget $budget_name?" || exit 0

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Display names are not unique; delete every budget with this name
# $budgets without quotes: the loop runs once for each name in the list
for budget in $budgets; do
    gcloud billing budgets delete "$budget" --billing-project "$GCP_PROJECT"
done
log "Budget deleted."
