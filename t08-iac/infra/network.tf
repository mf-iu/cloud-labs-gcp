# APIs and the network from lab t04

locals {
  name = "${var.prefix}-${var.owner}-t08"
}

resource "google_project_service" "this" {
  for_each = toset([
    "compute.googleapis.com", "run.googleapis.com", "artifactregistry.googleapis.com",
    "storage.googleapis.com", "sqladmin.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false # other labs use the same APIs
}

resource "google_compute_network" "main" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.this]
}

resource "google_compute_subnetwork" "this" {
  for_each = {
    public = "10.20.0.0/24"
    app    = "10.20.10.0/24"
    db     = "10.20.20.0/24"
  }

  name                     = "${local.name}-${each.key}"
  network                  = google_compute_network.main.id
  region                   = var.region
  ip_cidr_range            = each.value
  private_ip_google_access = each.key != "public"
}

# Firewall rules with network tags: lb -> app -> db
resource "google_compute_firewall" "https" {
  name          = "${local.name}-allow-https"
  network       = google_compute_network.main.id
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lb"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "api" {
  name        = "${local.name}-allow-api"
  network     = google_compute_network.main.id
  direction   = "INGRESS"
  source_tags = ["lb"]
  target_tags = ["app"]

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }
}

resource "google_compute_firewall" "postgres" {
  name        = "${local.name}-allow-postgres"
  network     = google_compute_network.main.id
  direction   = "INGRESS"
  source_tags = ["app"]
  target_tags = ["db"]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}
