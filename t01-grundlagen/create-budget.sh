#!/usr/bin/env bash
# Create a monthly budget for the course project. Google sends e-mails to
# the billing administrators at 50 % and 80 % of the actual costs and at
# 100 % of the forecast. The budget counts costs before credits: during the
# free trial the credits pay for everything, so a budget with credits would
# always stay at 0.
# Usage: ./create-budget.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
enable_apis billingbudgets.googleapis.com
billing=$(billing_account)
budget_name=$(name monthly-budget)

# Display names are not unique: look for an existing budget first
if [[ -n "$(find_budgets "$billing" "$budget_name")" ]]; then
  log "Budget $budget_name exists already. To change it, run ./delete-budget.sh first."
  exit 0
fi

# Without a currency code the amount is in the currency of the billing account
log "Creating budget $budget_name ($BUDGET_AMOUNT per month) ..."
gcloud billing budgets create --billing-account "$billing" \
  --billing-project "$GCP_PROJECT" \
  --display-name "$budget_name" \
  --budget-amount "$BUDGET_AMOUNT" \
  --credit-types-treatment exclude-all-credits \
  --filter-projects "projects/$GCP_PROJECT" \
  --threshold-rule percent=0.5 \
  --threshold-rule percent=0.8 \
  --threshold-rule percent=1.0,basis=forecasted-spend
log "Done. Check it in the console: Billing > Budgets & alerts."
