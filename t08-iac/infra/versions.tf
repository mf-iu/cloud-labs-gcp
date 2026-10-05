terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Remote state in Cloud Storage; the bucket comes from .state/backend.hcl
  backend "gcs" {}
}

# Credentials: gcloud auth application-default login
provider "google" {
  project = var.project
  region  = var.region

  default_labels = {
    course = "cloud-computing"
    lab    = "t08"
  }
}
