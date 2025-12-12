variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default region for resources"
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Name for the Terraform state bucket (must be globally unique)"
  type        = string
}

variable "state_bucket_location" {
  description = "Location/region for the state bucket"
  type        = string
  default     = "US"
}

