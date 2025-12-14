# Architecture Overview

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ONE-TIME SETUP                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Developer (Localhost)                                              │
│       │                                                             │
│       ├─► Step 1: terraform apply (bootstrap)                       │
│       │   └─► Creates: GCS bucket, Service Accounts, APIs           │
│       │                                                             │
│       └─► Step 2: terraform apply (app)                             │
│           └─► Creates: Artifact Registry, Cloud Run (placeholder),  │
│                        IAM roles                                    │
│                                                                     │
│  Result: Infrastructure ready, Cloud Run shows "Hello World"        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    ONGOING DEPLOYMENTS (CI/CD)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Developer                                                          │
│       │                                                             │
│       └─► git push to main                                          │
│                │                                                    │
│                ▼                                                    │
│         GitHub Actions                                              │
│                │                                                    │
│                ├─► CI Job                                           │
│                │   ├─► dotnet restore                               │
│                │   ├─► dotnet build                                 │
│                │   └─► dotnet test                                  │
│                │                                                    │
│                └─► Deploy Job                                       │
│                    ├─► docker build (books-api:SHA)                 │
│                    ├─► docker push → Artifact Registry              │
│                    └─► gcloud run deploy                            │
│                        └─► Directly updates Cloud Run               │
│                                                                     │
│  Result: New version deployed in ~30 seconds                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│              INFRASTRUCTURE CHANGES (Rare)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Platform Engineer                                                  │
│       │                                                             │
│       ├─► Edit terraform/app/main.tf                                │
│       │   (e.g., change max_instances, add env vars)                │
│       │                                                             │
│       └─► terraform apply                                           │
│           ├─► Updates infrastructure settings                       │
│           └─► Ignores image (lifecycle.ignore_changes)              │
│                                                                     │
│  Result: Infrastructure updated, application keeps running          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### Terraform (Infrastructure as Code)
**Manages:**
- ✅ Artifact Registry repository
- ✅ Cloud Run service (initial creation)
- ✅ Service accounts and IAM roles
- ✅ Networking and ingress settings
- ✅ Scaling configuration (min/max instances)
- ✅ Environment variables structure

**Does NOT Manage:**
- ❌ Docker images (handled by CI/CD)
- ❌ Application deployments (handled by CI/CD)

### CI/CD (GitHub Actions)
**Manages:**
- ✅ Building Docker images
- ✅ Pushing images to Artifact Registry
- ✅ Deploying new versions to Cloud Run
- ✅ Running tests before deployment
- ✅ Tagging images with Git SHA

**Does NOT Manage:**
- ❌ Infrastructure provisioning (handled by Terraform)
- ❌ IAM roles (handled by Terraform)

## Key Design Decisions

### 1. Separation of Concerns
```
Terraform = "What infrastructure exists?"
CI/CD     = "What code is running?"
```

### 2. Lifecycle Management
```hcl
lifecycle {
  ignore_changes = [
    template[0].containers[0].image,
  ]
}
```
**Why:** Prevents Terraform from reverting CI/CD deployments.

### 3. Direct Deployment via gcloud
```bash
gcloud run deploy books-api --image="${IMAGE}"
```
**Why:** 
- Faster than Terraform (no state locking/planning)
- Doesn't modify Terraform state
- Standard practice for Cloud Run deployments

### 4. Placeholder Image Strategy
```hcl
variable "image" {
  default = "gcr.io/cloudrun/hello"
}
```
**Why:**
- Allows Terraform to create Cloud Run service without building app first
- CI/CD replaces it on first deployment
- No chicken-and-egg problem

## Security Model

```
┌──────────────────────────────────────────────────────────┐
│ GitHub Actions (CI/CD)                                   │
│   Uses: terraform-ci@PROJECT.iam.gserviceaccount.com     │
│   Permissions:                                           │
│     - Artifact Registry Writer                           │
│     - Cloud Run Admin                                    │
│     - Service Account User                               │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ Cloud Run Service                                        │
│   Uses: books-api-sa@PROJECT.iam.gserviceaccount.com     │
│   Permissions:                                           │
│     - Minimal (principle of least privilege)             │
│     - Can be extended for GCS, Cloud SQL, etc.           │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ Public Internet                                          │
│   Authentication: API Key (X-API-KEY header)             │
│   Endpoints:                                             │
│     - GET /health (public, no key required)              │
│     - GET /api/books (requires API key)                  │
└──────────────────────────────────────────────────────────┘
```

## Benefits of This Architecture

| Benefit | Description |
|---------|-------------|
| **Fast Deployments** | ~30s vs ~2min with Terraform |
| **Stable State** | Terraform state only changes for infrastructure |
| **Clear Ownership** | Platform team = Terraform, Dev team = CI/CD |
| **Scalable** | Can deploy 10+ times/day without issues |
| **Safe** | Terraform won't accidentally revert deployments |
| **Industry Standard** | Matches how major companies deploy to Cloud Run |
| **Easy Rollback** | `gcloud run deploy` with previous image tag |
| **Audit Trail** | Cloud Run revision history + CI/CD logs |

