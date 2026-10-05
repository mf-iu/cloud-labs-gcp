# Lab t11: bucket for MLflow artifacts and models, PlaceFinder with the
# /estimate endpoint on Cloud Run. The service account may read the models.

locals {
  name = "${var.prefix}-${var.owner}-t11"
}

resource "google_project_service" "this" {
  for_each = toset(["run.googleapis.com", "storage.googleapis.com", "artifactregistry.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "ml" {
  name                        = "${local.name}-${var.suffix}-ml"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  depends_on                  = [google_project_service.this]
}

# Pull-through cache for ghcr.io (Cloud Run cannot pull from ghcr.io directly)
resource "google_artifact_registry_repository" "ghcr" {
  repository_id = "${local.name}-ghcr"
  location      = var.region
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  depends_on    = [google_project_service.this]

  remote_repository_config {
    description = "ghcr.io (public images)"
    common_repository {
      uri = "https://ghcr.io"
    }
  }
}

resource "google_service_account" "estimate" {
  account_id   = "${local.name}-estimate"
  display_name = "PlaceFinder /estimate (lab t11)"
}

resource "google_storage_bucket_iam_member" "estimate" {
  bucket = google_storage_bucket.ml.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.estimate.member
}

resource "google_cloud_run_v2_service" "estimate" {
  name                 = "${local.name}-estimate"
  location             = var.region
  deletion_protection  = false
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true

  template {
    service_account = google_service_account.estimate.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.ghcr.repository_id}/${trimprefix(var.placefinder_image, "ghcr.io/")}:${var.image_tag}"

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      env {
        name  = "MODEL_URI"
        value = "gs://${google_storage_bucket.ml.name}/${var.model_object}"
      }
    }
  }

  depends_on = [google_project_service.this]
}
