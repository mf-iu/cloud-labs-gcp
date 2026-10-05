output "function_url" {
  value = google_cloudfunctions2_function.sync.service_config[0].uri
}

output "function_name" {
  value = google_cloudfunctions2_function.sync.name
}

output "bucket" {
  value = google_storage_bucket.data.name
}
