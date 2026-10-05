# Optional PostgreSQL (enable_database = true). Reachable only from
# admin_cidrs; connecting the Cloud Run service is part of the exercise.

resource "random_password" "db" {
  count   = var.enable_database ? 1 : 0
  length  = 24
  special = false
}

resource "google_sql_database_instance" "db" {
  count               = var.enable_database ? 1 : 0
  name                = "${local.name}-db-${var.suffix}"
  region              = var.region
  database_version    = "POSTGRES_17"
  root_password       = random_password.db[0].result
  deletion_protection = false
  depends_on          = [google_project_service.this]

  settings {
    edition   = "ENTERPRISE"
    tier      = "db-f1-micro"
    disk_size = 10

    ip_configuration {
      ipv4_enabled = true

      dynamic "authorized_networks" {
        for_each = var.admin_cidrs
        content {
          name  = "admin-${authorized_networks.key}"
          value = authorized_networks.value
        }
      }
    }
  }
}

resource "google_sql_database" "placefinder" {
  count    = var.enable_database ? 1 : 0
  name     = "placefinder"
  instance = google_sql_database_instance.db[0].name
}
