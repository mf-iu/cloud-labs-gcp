# Keyless deployment from GitHub Actions with Workload Identity Federation:
# the workflow exchanges its OIDC token for a short-lived token of the
# service account below (no JSON key).

locals {
  name    = "${var.prefix}-${var.owner}"
  pool_id = coalesce(var.pool_id, "${local.name}-github")
}

resource "google_project_service" "this" {
  for_each = toset([
    "iam.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = local.pool_id
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  # Only this repository and branch, not forks or pull requests
  attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.ref == 'refs/heads/${var.github_branch}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy" {
  account_id   = "${local.name}-github-deploy"
  display_name = "GitHub Actions deployment"
}

# Workflows of the repository may act as the service account
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# Push images and deploy Cloud Run revisions in this project
resource "google_project_iam_member" "deploy" {
  for_each = toset(["roles/artifactregistry.writer", "roles/run.developer"])

  project = var.project
  role    = each.value
  member  = google_service_account.deploy.member
}

# Cloud Run runs the new revision as the service account of t08-iac/infra
resource "google_service_account_iam_member" "act_as_runtime" {
  service_account_id = "projects/${var.project}/serviceAccounts/${local.name}-t08-run@${var.project}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deploy.member
}
