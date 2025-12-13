provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Docker images for API"
  format        = "DOCKER"
}

resource "google_service_account" "cloud_run" {
  account_id   = "${var.service_name}-sa"
  display_name = "${var.service_name} service account"
}

resource "google_cloud_run_v2_service" "api" {
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.cloud_run.email
    containers {
      image = var.image
      ports {
        container_port = 8080
      }
      env {
        name  = "ApiKeySettings__Key"
        value = var.api_key
      }
    }
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  ingress = "INGRESS_TRAFFIC_ALL"

  # Ignore changes to the image tag - let CI/CD manage deployments
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Allow unauthenticated access (API key auth handled in middleware)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
