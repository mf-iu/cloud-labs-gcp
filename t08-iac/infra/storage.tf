# Object storage as in session 7 (t07-objektspeicher/create-bucket.sh):
# private bucket with CORS for the map and lifecycle rules
resource "google_storage_bucket" "data" {
  name                        = "${local.name}-${var.suffix}-data"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # lab only: "tofu destroy" deletes the objects as well
  depends_on                  = [google_project_service.this]

  cors {
    origin          = ["http://localhost:5173"]
    method          = ["GET", "HEAD"]
    response_header = ["Range", "ETag", "Content-Length", "Content-Range"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age            = 30
      matches_prefix = ["raw/"]
    }
  }

  lifecycle_rule {
    action {
      type = "AbortIncompleteMultipartUpload"
    }
    condition {
      age = 1
    }
  }
}

# Cloud Run cannot pull from ghcr.io directly, but through a remote
# repository of Artifact Registry in front of it (pull-through cache). The
# CI pipeline of PlaceFinder pushes to ghcr.io; nobody pushes here.
resource "google_artifact_registry_repository" "ghcr" {
  repository_id = "${local.name}-ghcr"
  location      = var.region
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  description   = "ghcr.io (public images)"
  depends_on    = [google_project_service.this]

  remote_repository_config {
    description = "ghcr.io"
    docker_repository {
      custom_repository {
        uri = "https://ghcr.io"
      }
    }
  }

  # cached images older than 30 days go away; a new pull fetches them again
  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }
}

locals {
  # ghcr.io/<user>/placefinder -> <region>-docker.pkg.dev/<project>/<repo>/<user>/placefinder
  image_repository = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.ghcr.repository_id}/${trimprefix(var.placefinder_image, "ghcr.io/")}"
}
