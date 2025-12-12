terraform {
  required_version = ">= 1.8.0"

  backend "gcs" {
    bucket = "CHANGEME-state-bucket"
    prefix = "terraform/state/app"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

