# Read by service (terraform_remote_state) and later configurations

output "network_id" {
  value = google_compute_network.main.id
}

output "app_subnet_id" {
  description = "Subnet for Direct VPC egress of Cloud Run"
  value       = google_compute_subnetwork.this["app"].id
}

output "bucket" {
  value = google_storage_bucket.data.name
}

output "image_repository" {
  description = "ghcr.io through Artifact Registry, without tag"
  value       = local.image_repository
}

output "service_account_email" {
  value = google_service_account.placefinder.email
}

output "service_account_member" {
  value = google_service_account.placefinder.member
}
