terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project
  region  = var.region

  default_labels = {
    course = "cloud-computing"
    lab    = "t09"
  }
}
