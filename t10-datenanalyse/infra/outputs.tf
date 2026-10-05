output "bucket" {
  value = google_storage_bucket.lake.name
}

output "dataset" {
  value = google_bigquery_dataset.lab.dataset_id
}

output "hmac_access_id" {
  value = google_storage_hmac_key.reader.access_id
}

output "hmac_secret" {
  value     = google_storage_hmac_key.reader.secret
  sensitive = true
}
