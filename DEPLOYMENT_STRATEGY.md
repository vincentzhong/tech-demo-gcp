# Deployment Strategy

## Approach: Infrastructure First, Application via CI/CD

This project follows the **industry best practice** of separating infrastructure provisioning from application deployment.

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
2. Deploy job: Build Docker image → Push to registry → Terraform apply
3. Cloud Run automatically serves the new version

### Terraform Lifecycle Management

```hcl
resource "google_cloud_run_v2_service" "api" {
  # ... configuration ...
  
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}
```

This tells Terraform: "I created the Cloud Run service, but CI/CD manages the image. Don't try to revert it."

## Comparison

| Aspect | Infrastructure First (✅ Recommended) | Manual Image First (❌ Not Recommended) |
|--------|--------------------------------------|----------------------------------------|
| Initial Setup | Terraform with placeholder image | Build/push image manually, then Terraform |
| Ongoing Deployments | `git push` (automatic) | `git push` (automatic) |
| Manual Steps | None after setup | Required for initial setup |
| Consistency | All deployments identical | Different initial vs. ongoing |
| Audit Trail | Complete in CI/CD | Missing initial deployment |
| Terraform State | Stable (ignores image changes) | Changes on every deployment |
| Developer Experience | Simple, automated | Complex initial setup |
| Rollback | Via Git/CI/CD | Via Git/CI/CD |

## Best Practices Applied

1. ✅ **Infrastructure as Code** - All infrastructure in Terraform
2. ✅ **GitOps** - Git is the source of truth
3. ✅ **Immutable Infrastructure** - New image for every deployment
4. ✅ **Automated Testing** - Tests run before deployment
5. ✅ **Least Privilege** - Separate service accounts for Terraform and Cloud Run
6. ✅ **Secrets Management** - API keys in GitHub Secrets, not in code
7. ✅ **Audit Trail** - All deployments tracked in CI/CD logs

## Summary

**Use the placeholder image approach** because:
- It's the industry standard
- It's more maintainable
- It's more secure
- It's easier for developers
- It follows GitOps principles

The initial "Hello World" placeholder is temporary and gets replaced on the first CI/CD run.

