output "service_url" {
  description = "HTTPS endpoint of PlaceFinder"
  value       = google_cloud_run_v2_service.placefinder.uri
}

output "service_name" {
  description = "For the deploy workflow (repository variable SERVICE_NAME)"
  value       = google_cloud_run_v2_service.placefinder.name
}

output "image_repository" {
  description = "For the deploy workflow (repository variable IMAGE_REPOSITORY): ghcr.io through Artifact Registry"
  value       = local.image_repository
}

output "bucket" {
  value = google_storage_bucket.data.name
}

output "database" {
  description = "Private address of PostgreSQL (only with enable_database = true)"
  value       = var.enable_database ? google_sql_database_instance.db[0].private_ip_address : null
}
