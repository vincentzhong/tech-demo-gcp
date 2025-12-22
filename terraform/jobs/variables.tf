variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "job_name" {
  description = "Name of the Cloud Run Job"
  type        = string
  default     = "nightly-cleanup-job"
}

variable "job_image" {
  description = "Container image for the job"
  type        = string
  # Default to a public placeholder for initial infrastructure provision.
  # The actual application code will be deployed via CI/CD.
  default     = "us-docker.pkg.dev/cloudrun/container/hello" 
}
