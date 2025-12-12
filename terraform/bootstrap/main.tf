terraform {
  required_version = ">= 1.8.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "apigateway.googleapis.com",
    "serviceusage.googleapis.com"
  ]
}

resource "google_project_service" "enabled" {
  for_each = toset(local.services)
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}

resource "google_storage_bucket" "state" {
  name          = var.state_bucket_name
  location      = var.state_bucket_location
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true
}

resource "google_service_account" "terraform" {
  account_id   = "terraform-ci"
  display_name = "Terraform CI"
}

resource "google_project_iam_member" "terraform_roles" {
  for_each = toset([
    "roles/storage.admin",
    "roles/artifactregistry.admin",
    "roles/run.admin",
    "roles/apigateway.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageAdmin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

output "state_bucket_name" {
  value = google_storage_bucket.state.name
}

output "terraform_service_account_email" {
  value = google_service_account.terraform.email
}

