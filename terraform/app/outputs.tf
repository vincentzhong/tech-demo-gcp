output "cloud_run_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "api_gateway_url" {
  value = google_api_gateway_gateway.gateway.default_hostname
}

output "api_key" {
  value     = var.api_key
  sensitive = true
}

