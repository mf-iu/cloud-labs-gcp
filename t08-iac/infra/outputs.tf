output "service_url" {
  description = "HTTPS endpoint of PlaceFinder"
  value       = google_cloud_run_v2_service.placefinder.uri
}

output "service_name" {
  value = google_cloud_run_v2_service.placefinder.name
}

output "bucket" {
  value = google_storage_bucket.data.name
}

output "image_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.images.repository_id}"
}

output "database_url" {
  description = "Connection string (only with enable_database = true)"
  value = var.enable_database ? format("postgresql://postgres:%s@%s:5432/placefinder?sslmode=require",
  random_password.db[0].result, google_sql_database_instance.db[0].public_ip_address) : null
  sensitive = true
}
