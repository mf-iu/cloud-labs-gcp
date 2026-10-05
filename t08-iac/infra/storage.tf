# Object storage for raw data and map tiles, registry for the images

resource "google_storage_bucket" "data" {
  name                        = "${local.name}-${var.suffix}-data"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # lab only: "tofu destroy" deletes the objects as well
  depends_on                  = [google_project_service.this]
}

resource "google_artifact_registry_repository" "images" {
  repository_id = "${local.name}-images"
  location      = var.region
  format        = "DOCKER"
  depends_on    = [google_project_service.this]

  # Keep only the five newest images
  cleanup_policies {
    id     = "keep-five"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
  cleanup_policies {
    id     = "delete-older"
    action = "DELETE"
    condition {
      tag_state = "ANY"
    }
  }
}

# Pull-through cache for ghcr.io: Cloud Run cannot pull from ghcr.io
# directly, but from an Artifact Registry remote repository in front of it
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

locals {
  # ghcr.io/<user>/placefinder -> <region>-docker.pkg.dev/<project>/<repo>/<user>/placefinder
  image = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.ghcr.repository_id}/${trimprefix(var.placefinder_image, "ghcr.io/")}:${var.image_tag}"
}
