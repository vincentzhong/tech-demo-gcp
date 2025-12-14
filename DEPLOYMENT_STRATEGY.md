# Deployment Strategy

## Approach: Infrastructure First, Application via Direct CI/CD Deployment

This project follows the **industry best practice** of separating infrastructure provisioning from application deployment.

**Key Principle:** Terraform manages infrastructure, CI/CD manages application code.

## Why This Approach?

### ✅ Advantages

1. **Separation of Concerns**
   - Terraform manages infrastructure (Cloud Run service, IAM, networking)
   - CI/CD manages application code (Docker images, deployments)

2. **No Manual Image Building**
   - Developers never manually build/push Docker images
   - All deployments go through the same tested pipeline
   - Consistent, repeatable process

3. **Single Source of Truth**
   - CI/CD pipeline is the only way to deploy application code
   - Full audit trail of all deployments
   - Easy rollbacks via Git history

4. **Terraform Stability**
   - Terraform state doesn't change on every code commit
   - Infrastructure changes are deliberate and tracked
   - `lifecycle.ignore_changes` prevents drift from CI/CD deployments

5. **Developer Experience**
   - Simple workflow: `git push` → automatic deployment
   - No need to understand Docker/Artifact Registry
   - Focus on code, not infrastructure

### ❌ Alternative Approach (Not Recommended)

**Manual image building before Terraform:**
- ❌ Requires manual Docker commands
- ❌ Different process for initial setup vs. ongoing deployments
- ❌ No audit trail for manual image pushes
- ❌ "Works on my machine" problems
- ❌ Terraform state changes on every deployment

## How It Works

### Initial Setup (One-time)

1. **Bootstrap** (Step 1)
   - Creates GCS bucket for Terraform state
   - Creates service accounts
   - Enables required GCP APIs

2. **Provision Infrastructure** (Step 2)
   - Terraform creates Artifact Registry, Cloud Run service, IAM
   - Uses placeholder image: `gcr.io/cloudrun/hello`
   - Cloud Run service is created but shows "Hello World"

3. **Configure CI/CD** (Steps 3-4)
   - Create service account key
   - Add GitHub secrets and variables

4. **First Deployment** (Step 5)
   - Push to `main` branch
   - CI/CD builds real Docker image
   - Pushes to Artifact Registry
   - Terraform updates Cloud Run with real image
   - Your Books API is now live!

### Ongoing Deployments

Every push to `main`:
1. CI job: Build and test .NET application
2. Deploy job: Build Docker image → Push to registry → **Deploy directly via `gcloud run deploy`**
3. Cloud Run automatically serves the new version (no Terraform involved)

### Terraform Lifecycle Management

```hcl
resource "google_cloud_run_v2_service" "api" {
  # ... configuration ...

  # Let CI/CD manage image deployments directly via gcloud
  # Terraform only manages infrastructure configuration
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}
```

This tells Terraform: "I created the Cloud Run service, but CI/CD manages the image via `gcloud run deploy`. Don't try to revert it."

### CI/CD Deployment Command

```bash
gcloud run deploy books-api \
  --image="${IMAGE}" \
  --region=us-central1 \
  --platform=managed \
  --allow-unauthenticated \
  --set-env-vars="ApiKeySettings__Key=${API_KEY}" \
  --quiet
```

This directly updates the Cloud Run service without Terraform, which is:
- ✅ **Faster** - No Terraform state locking or planning overhead
- ✅ **Cleaner** - Terraform state doesn't change on every deployment
- ✅ **Standard** - How most production systems deploy to Cloud Run

## Comparison

| Aspect | Direct Deployment (✅ This Project) | Via Terraform (Alternative) | Manual First (❌ Not Recommended) |
|--------|-------------------------------------|----------------------------|-----------------------------------|
| **Deployment Method** | `gcloud run deploy` | `terraform apply` | Manual build/push |
| **Terraform State** | Stable (ignores images) | Changes every deployment | Changes every deployment |
| **Deployment Speed** | Fast (~30s) | Slower (~2min) | N/A |
| **CI/CD Complexity** | Simple | Simple | Complex initial setup |
| **Best Practice** | ✅ Industry standard | ⚠️ Works but slower | ❌ Avoid |
| **Rollback** | `gcloud run deploy` old image | `terraform apply` old image | Manual |
| **Audit Trail** | CI/CD logs + Cloud Run revisions | Terraform state + CI/CD | Incomplete |

## Best Practices Applied

1. ✅ **Infrastructure as Code** - All infrastructure in Terraform
2. ✅ **GitOps** - Git is the source of truth
3. ✅ **Immutable Infrastructure** - New image for every deployment
4. ✅ **Automated Testing** - Tests run before deployment
5. ✅ **Least Privilege** - Separate service accounts for Terraform and Cloud Run
6. ✅ **Secrets Management** - API keys in GitHub Secrets, not in code
7. ✅ **Audit Trail** - All deployments tracked in CI/CD logs

## Summary

**This project uses the industry-standard approach:**

1. ✅ **Terraform** provisions infrastructure with placeholder image
2. ✅ **CI/CD** deploys application directly via `gcloud run deploy`
3. ✅ **`lifecycle.ignore_changes`** prevents Terraform from reverting deployments
4. ✅ **Fast deployments** - No Terraform overhead for application updates
5. ✅ **Stable Terraform state** - Only changes when infrastructure changes
6. ✅ **Clear separation** - Infrastructure vs. Application concerns

**Why this is best practice:**
- 🚀 **Performance** - Deployments are 3-4x faster than via Terraform
- 🔒 **Safety** - Terraform won't accidentally revert production deployments
- 📊 **Scalability** - Can deploy 10+ times per day without Terraform state bloat
- 🎯 **Industry Standard** - How Google, Netflix, Spotify deploy to Cloud Run
- 🛠️ **Maintainability** - Clear ownership (Platform team = Terraform, Dev team = gcloud)

The initial "Hello World" placeholder is temporary and gets replaced on the first CI/CD run.

