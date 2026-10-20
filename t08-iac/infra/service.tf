# PlaceFinder on Cloud Run as in session 3: public, scaling to zero. Traffic
# into private ranges, e.g. to PostgreSQL, goes through the subnet app of the
# VPC (Direct VPC egress) with the network tag "app" for the firewall. The
# CI pipeline of PlaceFinder pushes the images to ghcr.io; the deploy
# workflow (deploy.example.yml) rolls out new versions.

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

locals {
  # with a database: connection string without password, the password comes
  # from Secret Manager as PGPASSWORD (libpq reads it); DATABASE_INIT loads
  # the places from the image into the empty database
  database_env = var.enable_database ? {
    DATABASE_URL  = "postgresql://postgres@${google_sql_database_instance.db[0].private_ip_address}:5432/placefinder?sslmode=require"
    DATABASE_INIT = "true"
  } : {}
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
      max_instance_count = var.max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.this["app"].id
        tags       = ["app"]
      }
    }

    containers {
      image = "${local.image_repository}:${var.image_tag}"

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      dynamic "env" {
        for_each = local.database_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.enable_database ? [1] : []
        content {
          name = "PGPASSWORD"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.db[0].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  # The deploy workflow sets new images with gcloud; without this, the next
  # apply would roll back to image_tag (drift between pipeline and OpenTofu)
  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }

  depends_on = [
    google_project_service.this,
    google_secret_manager_secret_iam_member.db,
    google_secret_manager_secret_version.db,
  ]
}
