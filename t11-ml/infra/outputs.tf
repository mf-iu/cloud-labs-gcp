output "service_url" {
  value = google_cloud_run_v2_service.estimate.uri
}

output "service_name" {
  value = google_cloud_run_v2_service.estimate.name
}

output "bucket" {
  value = google_storage_bucket.ml.name
}

output "model_uri" {
  value = "gs://${google_storage_bucket.ml.name}/${var.model_object}"
}

output "mlflow_artifacts_destination" {
  value = "gs://${google_storage_bucket.ml.name}/mlflow"
}
