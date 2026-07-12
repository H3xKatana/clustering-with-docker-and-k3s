terraform {
  required_version = ">= 1.14"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google" {
  alias   = "beta"
  project = var.project_id
  region  = var.region
}
