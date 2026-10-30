# The identity of PlaceFinder on Cloud Run, part of base: service accounts
# cost nothing, and github-oidc lets the deploy workflow act as this one.
resource "google_service_account" "placefinder" {
  account_id   = "${local.name}-run"
  display_name = "PlaceFinder on Cloud Run (lab t08)"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The service may read and write objects in the data bucket
resource "google_storage_bucket_iam_member" "placefinder" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectUser"
  member = google_service_account.placefinder.member
}
