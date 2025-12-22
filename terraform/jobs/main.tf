provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. GCS Bucket for Reports
resource "google_storage_bucket" "reports_bucket" {
  name          = "${var.project_id}-nightly-reports"
  location      = var.region
  force_destroy = true # For demo purposes only

  uniform_bucket_level_access = true
}

# 2. Service Account for the Job
resource "google_service_account" "job_runner" {
  account_id   = "nightly-job-runner"
  display_name = "Nightly Job Runner SA"
}

# Grant Job SA access to the bucket
resource "google_storage_bucket_iam_member" "job_bucket_access" {
  bucket = google_storage_bucket.reports_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.job_runner.email}"
}

# 3. Cloud Run Job
resource "google_cloud_run_v2_job" "nightly_job" {
  name     = var.job_name
  location = var.region

  template {
    template {
      service_account = google_service_account.job_runner.email
      containers {
        image = var.job_image
        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.reports_bucket.name
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# 4. Scheduler Identity
resource "google_service_account" "scheduler_sa" {
  account_id   = "nightly-job-scheduler"
  display_name = "Nightly Job Scheduler SA"
}

# Grant Scheduler SA permission to invoke the Job
resource "google_cloud_run_v2_job_iam_member" "invoke_job" {
  location = google_cloud_run_v2_job.nightly_job.location
  name     = google_cloud_run_v2_job.nightly_job.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

# 5. Cloud Scheduler Job
resource "google_cloud_scheduler_job" "nightly_trigger" {
  name             = "trigger-nightly-job"
  description      = "Triggers the Cloud Run nightly job"
  schedule         = "0 3 * * *" # Runs at 3:00 AM daily
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.nightly_job.name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }
}
