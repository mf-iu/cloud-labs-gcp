# PlaceFinder on Cloud Run, public and scaling to zero

resource "google_service_account" "placefinder" {
  account_id   = "${local.name}-run"
  display_name = "PlaceFinder on Cloud Run (lab t08)"
}

# The service may read and write objects in the data bucket
resource "google_storage_bucket_iam_member" "placefinder" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectUser"
  member = google_service_account.placefinder.member
}

resource "google_cloud_run_v2_service" "placefinder" {
  name                 = "${local.name}-placefinder"
  location             = var.region
  deletion_protection  = false
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true # public API without IAM check

  template {
    service_account = google_service_account.placefinder.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = local.image

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "DATA_BUCKET"
        value = google_storage_bucket.data.name
      }
    }
  }

  depends_on = [google_project_service.this]
}
