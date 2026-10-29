# Optional PostgreSQL (enable_database = true): Cloud SQL with a private
# address from the range 10.20.20.0/24 of the VPC of base, without a public
# one.
# Unlike session 6, it cannot be loaded from your computer; PlaceFinder loads
# the places itself at startup (DATABASE_INIT, service.tf).

resource "random_password" "db" {
  count   = var.enable_database ? 1 : 0
  length  = 24
  special = false
}

# The name of a deleted instance stays blocked for about a week; a new
# random part after every destroy allows destroy and apply in a row
resource "random_id" "db" {
  count       = var.enable_database ? 1 : 0
  byte_length = 2
}

resource "google_sql_database_instance" "db" {
  count               = var.enable_database ? 1 : 0
  name                = "${local.name}-db-${random_id.db[0].hex}"
  region              = var.region
  database_version    = "POSTGRES_18"                # as in session 6
  root_password       = random_password.db[0].result # also in the state!
  deletion_protection = false
  depends_on          = [google_service_networking_connection.db]

  settings {
    edition   = "ENTERPRISE"
    tier      = "db-f1-micro"
    disk_size = 10

    ip_configuration {
      ipv4_enabled    = false # no public address
      private_network = local.base.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_sql_database" "placefinder" {
  count    = var.enable_database ? 1 : 0
  name     = "placefinder"
  instance = google_sql_database_instance.db[0].name
  # PlaceFinder keeps connections open; deleting the instance removes the
  # database anyway
  deletion_policy = "ABANDON"
}

# The password in Secret Manager; only the service account may read it
resource "google_secret_manager_secret" "db" {
  count     = var.enable_database ? 1 : 0
  secret_id = "${local.name}-db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db" {
  count       = var.enable_database ? 1 : 0
  secret      = google_secret_manager_secret.db[0].id
  secret_data = random_password.db[0].result
}

resource "google_secret_manager_secret_iam_member" "db" {
  count     = var.enable_database ? 1 : 0
  secret_id = google_secret_manager_secret.db[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.base.service_account_member
}

# Private services access: reserved range and peering to Google's network
resource "google_compute_global_address" "db" {
  count         = var.enable_database ? 1 : 0
  name          = "${local.name}-db-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.20.20.0"
  prefix_length = 24
  network       = local.base.network_id
}

resource "google_service_networking_connection" "db" {
  count                   = var.enable_database ? 1 : 0
  network                 = local.base.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.db[0].name]
  # Google may still count the deleted database as a user of the connection
  # for a while; then destroy removes the peering instead
  deletion_policy = "REMOVE_PEERING"
}
