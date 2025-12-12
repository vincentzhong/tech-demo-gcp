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

resource "google_service_account" "apigw" {
  account_id   = "${var.service_name}-gateway-sa"
  display_name = "${var.service_name} gateway service account"
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
}

resource "google_cloud_run_v2_service_iam_member" "gateway_invoker" {
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.apigw.email}"
}

resource "google_api_gateway_api" "api" {
  api_id = "${var.service_name}-api"
}

locals {
  openapi_content = templatefile("${path.module}/openapi.yaml.tmpl", {
    backend_url = google_cloud_run_v2_service.api.uri
  })
}

resource "google_api_gateway_api_config" "api_config" {
  api           = google_api_gateway_api.api.name
  api_config_id = "v1"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = local.openapi_content
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.apigw.email
    }
  }

  depends_on = [google_cloud_run_v2_service.api]
}

resource "google_api_gateway_gateway" "gateway" {
  name       = "${var.service_name}-gw"
  api        = google_api_gateway_api.api.name
  api_config = google_api_gateway_api_config.api_config.name
  location   = var.region
}

