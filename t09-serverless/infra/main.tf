# Daily GeoNames update as Cloud Run function (2nd gen), called by Cloud
# Scheduler with an OIDC token. Cloud Build installs the dependencies.

locals {
  name = "${var.prefix}-${var.owner}-t09"
}

resource "google_project_service" "this" {
  for_each = toset([
    "cloudfunctions.googleapis.com", "run.googleapis.com", "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com", "cloudscheduler.googleapis.com", "storage.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Bucket for the change files and, under source/, the function code
resource "google_storage_bucket" "data" {
  name                        = "${local.name}-${var.suffix}-data"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  depends_on                  = [google_project_service.this]
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/../build/function.zip"
  excludes    = ["__pycache__", ".venv", "out"]
}

# The object name contains the hash, so every code change triggers a new build
resource "google_storage_bucket_object" "source" {
  name   = "source/function-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.data.name
  source = data.archive_file.source.output_path
}

# Identity of the function: may write objects into the bucket, nothing else
resource "google_service_account" "function" {
  account_id   = "${local.name}-sync"
  display_name = "GeoNames sync function (lab t09)"
}

resource "google_storage_bucket_iam_member" "function" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectUser"
  member = google_service_account.function.member
}

resource "google_cloudfunctions2_function" "sync" {
  name     = "${local.name}-geonames-sync"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "sync"
    source {
      storage_source {
        bucket = google_storage_bucket.data.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    timeout_seconds       = 120
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.function.email
    environment_variables = {
      DATA_BUCKET  = google_storage_bucket.data.name
      DATABASE_URL = var.database_url
    }
  }

  depends_on = [google_project_service.this]
}

# Cloud Scheduler calls the function as this service account
resource "google_service_account" "scheduler" {
  account_id   = "${local.name}-scheduler"
  display_name = "Cloud Scheduler for the GeoNames sync (lab t09)"
}

resource "google_cloud_run_service_iam_member" "scheduler" {
  location = var.region
  service  = google_cloudfunctions2_function.sync.name
  role     = "roles/run.invoker"
  member   = google_service_account.scheduler.member
}

resource "google_cloud_scheduler_job" "daily" {
  name      = "${local.name}-geonames-daily"
  region    = var.region
  schedule  = var.schedule
  time_zone = "Europe/Berlin"

  retry_config {
    retry_count = 2
  }

  http_target {
    uri         = google_cloudfunctions2_function.sync.service_config[0].uri
    http_method = "POST"

    oidc_token {
      service_account_email = google_service_account.scheduler.email
      audience              = google_cloudfunctions2_function.sync.service_config[0].uri
    }
  }

  depends_on = [google_project_service.this]
}
