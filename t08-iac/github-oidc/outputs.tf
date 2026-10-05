# Store these values as GitHub Actions variables of the repository
# (Settings > Secrets and variables > Actions > Variables).

output "GCP_WORKLOAD_IDENTITY_PROVIDER" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "GCP_SERVICE_ACCOUNT" {
  value = google_service_account.deploy.email
}

output "GCP_REGION" {
  value = var.region
}
