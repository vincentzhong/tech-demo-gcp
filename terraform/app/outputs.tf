output "cloud_run_url" {
  description = "Cloud Run service URL (direct access)"
  value       = google_cloud_run_v2_service.api.uri
}

output "api_key" {
  description = "API key for authentication (send in X-API-KEY header)"
  value       = var.api_key
  sensitive   = true
}