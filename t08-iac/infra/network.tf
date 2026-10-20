# The network design of session 4 (t04-netzwerk/create-vpc.sh): custom VPC
# with a public and an application subnet. Instead of a database subnet,
# the range 10.20.20.0/24 goes to Cloud SQL: managed databases live in a
# network of Google, connected to this VPC by peering (private services
# access).
locals {
  name = "${var.prefix}-${var.owner}-t08"
}

resource "google_project_service" "this" {
  for_each = toset([
    "compute.googleapis.com", "run.googleapis.com", "artifactregistry.googleapis.com",
    "storage.googleapis.com", "sqladmin.googleapis.com", "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
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
  }

  name          = "${local.name}-${each.key}"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = each.value
  # reach Google APIs without public IP addresses
  private_ip_google_access = each.key != "public"
}

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

# Private services access: reserved range and peering to Google's network
resource "google_compute_global_address" "db" {
  count         = var.enable_database ? 1 : 0
  name          = "${local.name}-db-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.20.20.0"
  prefix_length = 24
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "db" {
  count                   = var.enable_database ? 1 : 0
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.db[0].name]
  # Google may still count the deleted database as a user of the connection
  # for a while; then destroy removes the peering instead
  deletion_policy = "REMOVE_PEERING"
}
