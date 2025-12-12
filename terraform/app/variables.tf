variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for resources"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Artifact Registry repository id"
  type        = string
  default     = "demo-api"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "books-api"
}

variable "image" {
  description = "Container image for the API"
  type        = string
}

variable "api_key" {
  description = "API key required by the service"
  type        = string
  sensitive   = true
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 3
}

