# Data lake for lab t10: GeoParquet in Cloud Storage, queried with DuckDB
# (HMAC key) and with BigQuery (external table, schema on read)

locals {
  name = "${var.prefix}-${var.owner}-t10"
}

resource "google_project_service" "this" {
  for_each = toset(["storage.googleapis.com", "bigquery.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "lake" {
  name                        = "${local.name}-${var.suffix}-lake"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
  depends_on                  = [google_project_service.this]
}

# DuckDB reads Cloud Storage through its S3-compatible XML API, which
# needs an HMAC key. The key belongs to a service account that may only read.
resource "google_service_account" "reader" {
  account_id   = "${local.name}-reader"
  display_name = "DuckDB reader (lab t10)"
}

resource "google_storage_bucket_iam_member" "reader" {
  bucket = google_storage_bucket.lake.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.reader.member
}

resource "google_storage_hmac_key" "reader" {
  service_account_email = google_service_account.reader.email
}

# BigQuery: dataset in the same location and an external table on the files
resource "google_bigquery_dataset" "lab" {
  dataset_id                 = replace(local.name, "-", "_")
  location                   = var.region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.this]
}

resource "google_bigquery_table" "places" {
  dataset_id          = google_bigquery_dataset.lab.dataset_id
  table_id            = "places"
  deletion_protection = false

  external_data_configuration {
    source_format = "PARQUET"
    autodetect    = false
    source_uris   = ["gs://${google_storage_bucket.lake.name}/places/*.parquet"]
  }

  # Explicit schema, so the table can exist before the first upload
  schema = jsonencode([
    { name = "geonameid", type = "INTEGER" },
    { name = "name", type = "STRING" },
    { name = "asciiname", type = "STRING" },
    { name = "latitude", type = "FLOAT" },
    { name = "longitude", type = "FLOAT" },
    { name = "feature_code", type = "STRING" },
    { name = "country_code", type = "STRING" },
    { name = "admin1_code", type = "STRING" },
    { name = "population", type = "INTEGER" },
    { name = "timezone", type = "STRING" },
    { name = "modification_date", type = "DATE" },
    { name = "geom", type = "BYTES", description = "WKB, see export_geoparquet.py" },
  ])
}
