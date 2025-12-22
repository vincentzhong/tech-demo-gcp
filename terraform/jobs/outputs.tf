output "bucket_name" {
  value = google_storage_bucket.reports_bucket.name
}

output "job_name" {
  value = google_cloud_run_v2_job.nightly_job.name
}

output "scheduler_job" {
  value = google_cloud_scheduler_job.nightly_trigger.name
}
