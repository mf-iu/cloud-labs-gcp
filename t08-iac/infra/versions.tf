terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # Remote state in Cloud Storage; bucket and prefix come from tools/tofu.sh
  # (.state/backend.hcl, written by t08-iac/bootstrap-state.sh)
  backend "gcs" {}
}

# Credentials: Application Default Credentials
# (gcloud auth application-default login, see t01-grundlagen)
provider "google" {
  project = var.project
  region  = var.region

  # Every resource that supports labels gets these (tools/find-leftovers.sh)
  default_labels = {
    course = "cloud-computing"
    lab    = "t08"
  }
}
