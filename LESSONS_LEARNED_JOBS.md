# Lessons Learned: Cloud Run Jobs & Deployment

This document captures the challenges faced and solutions implemented while adding a "Nightly Job" to the GCP environment.

## 1. Local Development vs. Cloud Build
**Issue:**  
We attempted to build the Docker image locally key using `docker build`, but the local Docker daemon was not running or configured correctly on Windows.
```text
ERROR: error during connect ... The system cannot find the file specified.
```

**Attempted Fix:**  
We tried to offload the build to **Cloud Build** using `gcloud builds submit`.

## 2. Permissions & Identity
**Issue:**  
Running `gcloud builds submit` failed initially because the active user (`vincent.einnoc@gmail.com`) lacked permissions.
```text
ERROR: (gcloud.builds.submit) PERMISSION_DENIED: The caller does not have permission.
```

**Attempted Fix:**  
We activated the project's Service Account using the local key file:
```bash
gcloud auth activate-service-account --key-file=sa-key.json
```
However, this *also* failed because the `terraform-ci` service account (rightfully) did not have the **Cloud Build Editor** role correctly assigned for manual builds, only for CI/CD usage.

## 3. The "Chicken vs. Egg" Deployment Problem
**Issue:**  
Terraform requires a Docker image to *exist* before it can create a Cloud Run Job. However, we couldn't build our custom image manually due to the issues above. This created a blockage: we couldn't deploy infrastructure without the image, and we couldn't deploy the image (via CI/CD) without the infrastructure (Artifact Registry) being fully ready/linked.

**Solution: The "Placeholder" Strategy**  
We modified the Terraform configuration to use a public "Hello World" image for the *initial* deployment.

*   **terraform/jobs/variables.tf**:
    ```hcl
    variable "job_image" {
      default = "us-docker.pkg.dev/cloudrun/container/hello" 
    }
    ```

This allowed Terraform to successfully create the Cloud Run Job and IAM bindings. Once the infrastructure existed, we simply pushed our code to GitHub, where the **CI/CD pipeline** (which has correct permissions) built the real Python image and updated the Job.

**Key Learning:**  
For new services, always design Terraform to handle an "initial bootstrap" state using standard public images. This decouples infrastructure provisioning from application code delivery.

## 4. API Enablement
**Issue:**  
Terraform failed to create the Cloud Scheduler job because the API wasn't enabled.
```text
Error: Error creating Job: googleapi: Error 403: Cloud Scheduler API has not been used...
```

**Solution:**  
Enabled the API via CLI:
```bash
gcloud services enable cloudscheduler.googleapis.com
```

## 5. Security Best Practice (Terraform Ignore Changes)
**Technique:**  
We used the `lifecycle` block to prevent Terraform from fighting with CI/CD.
```hcl
resource "google_cloud_run_v2_job" "nightly_job" {
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image, # Let CI/CD manage the image version
    ]
  }
}
```
This ensures that when CI/CD deploys `nightly-job:sha-abc`, Terraform doesn't try to revert it back to "Hello World" (or an old version) on the next apply.
