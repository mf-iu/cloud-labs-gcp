# The network design of session 4 (04-network/create-vpc.sh): custom Virtual
# Private Cloud (VPC) with a public and an application subnet. Instead of a
# database subnet, the range 10.20.20.0/24 goes to Cloud SQL
# (service/database.tf): managed databases live in a network of Google,
# connected to this VPC by peering (private services access). Part of base, like
# the APIs: costs nothing and stays until the course ends.
locals {
  name = "${var.prefix}-${var.owner}-t08"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

resource "google_project_service" "this" {
  for_each = toset([
    "compute.googleapis.com", "run.googleapis.com", "artifactregistry.googleapis.com",
    "storage.googleapis.com", "sqladmin.googleapis.com", "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false # other labs use the same APIs
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

resource "google_compute_network" "main" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.this]
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

resource "google_compute_subnetwork" "this" {
  for_each = {
    public = "10.20.0.0/24"
    app    = "10.20.10.0/24"
  }

  name          = "${local.name}-${each.key}"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = each.value
  # reach Google APIs without public IP addresses
  private_ip_google_access = each.key != "public"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Firewall with network tags as in session 4. Cloud Run sends its traffic
# into private ranges through the subnet app with the tag "app" (service.tf):
# to PostgreSQL only, nowhere else in the VPC.
resource "google_compute_firewall" "app_to_db" {
  name               = "${local.name}-allow-postgres"
  network            = google_compute_network.main.id
  direction          = "EGRESS"
  priority           = 1000
  target_tags        = ["app"]
  destination_ranges = ["10.20.20.0/24"]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

resource "google_compute_firewall" "app_deny_vpc" {
  name               = "${local.name}-deny-vpc"
  network            = google_compute_network.main.id
  direction          = "EGRESS"
  priority           = 2000
  target_tags        = ["app"]
  destination_ranges = ["10.20.0.0/16"]

  deny {
    protocol = "all"
  }
}
