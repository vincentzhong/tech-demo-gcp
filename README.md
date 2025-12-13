# GCP Demo Books API (.NET + Cloud Run + Terraform)

Containerized ASP.NET Core Web API (controller/service/repo) with API-key auth middleware, deployed to Cloud Run (direct access), provisioned via Terraform (bootstrap + app stacks), and shipped with GitHub Actions CI/CD.

## Endpoints
- `GET /health` (no auth)
- `GET /api/books` (requires header `X-API-KEY: <key>`)

## Repo Structure
- `src/Api` — ASP.NET Core Web API with API key filter, books controller, service, and in-memory repo
- `tests/Api.UnitTests` — xUnit tests (service + API key filter)
- `Dockerfile` — multi-stage build to port 8080
- `terraform/bootstrap` — enables APIs, creates remote state bucket + Terraform service account
- `terraform/app` — Artifact Registry, Cloud Run, IAM; uses remote GCS backend
- `.github/workflows/ci-cd.yml` — build/test, image push, terraform plan/apply (main)

## Prereqs

**This is project-level Terraform** — it assumes you already have a GCP project with billing enabled.

### Required before running Terraform:
- ✅ **GCP project exists** (create manually via Console or `gcloud projects create`)
- ✅ **Billing account linked** to the project (enable in Console or `gcloud billing projects link`)
- ✅ **Permissions** to create resources in the project (Owner or Editor role)
- ✅ Terraform >= 1.8, Docker, .NET 9 SDK locally if running manually

### What Terraform covers:
- ✅ Enables required GCP APIs
- ✅ Creates remote state bucket (GCS)
- ✅ Creates service accounts (Terraform CI, Cloud Run)
- ✅ Creates Artifact Registry repository
- ✅ Creates Cloud Run service (publicly accessible)
- ✅ Configures IAM roles and bindings

### What Terraform does NOT cover:
- ❌ Project creation
- ❌ Billing account setup/linking
- ❌ Organization/folder structure
- ❌ Network/VPC configuration (uses default)
- ❌ Firewall rules (uses defaults)

## Before You Start

> **💡 Note:** This README provides commands for both **Bash/Linux/macOS** and **PowerShell/Windows**. Use the syntax appropriate for your shell.

**If you don't have a GCP project yet:**

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
# Create project (requires org/billing account)
gcloud projects create <YOUR_PROJECT> --name="TechDemo GCP"

# Link billing account (replace BILLING_ACCOUNT_ID)
gcloud billing projects link <YOUR_PROJECT> --billing-account=BILLING_ACCOUNT_ID
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
# Create project (requires org/billing account)
gcloud projects create <YOUR_PROJECT> --name="TechDemo GCP"

# Link billing account (replace BILLING_ACCOUNT_ID)
gcloud billing projects link <YOUR_PROJECT> --billing-account=BILLING_ACCOUNT_ID
```
</details>

**Replace these placeholders before running Terraform commands:**

1. **`<YOUR_PROJECT>`** → Your GCP project ID (e.g., `my-demo-project-123456`)
   - Find it: `gcloud projects list` or GCP Console
   - Used in: all `terraform apply` commands and `gcloud config set project`

2. **`<UNIQUE_BUCKET>`** → A globally unique bucket name for Terraform state (e.g., `my-demo-tf-state-123456`)
   - Must be globally unique across all GCP projects
   - Used in: bootstrap step only

3. **`<YOUR_BUCKET>`** → The actual bucket name created in step 1 (same as `<UNIQUE_BUCKET>` you used)
   - Copy from bootstrap output: `state_bucket_name = ...`
   - Used in: app stack `terraform init -backend-config`

4. **`<YOUR_API_KEY>`** → A secret string for API authentication (e.g., `demo-secret-key-abc123`)
   - Generate any secure random string
   - Used in: app stack `terraform apply` and GitHub Actions secret

**Example values:**
- `<YOUR_PROJECT>` = `techdemo-gcp-2024`
- `<UNIQUE_BUCKET>` = `techdemo-gcp-tf-state-2024`
- `<YOUR_API_KEY>` = `demo-api-key-secret-xyz789`

## Local dev

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
dotnet test
dotnet run --project src/Api/Api.csproj
# call with key from appsettings.Development.json (X-API-KEY: dev-api-key)
curl -H "X-API-KEY: dev-api-key" http://localhost:5251/api/books
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
dotnet test
dotnet run --project src/Api/Api.csproj
# call with key from appsettings.Development.json (X-API-KEY: dev-api-key)
Invoke-WebRequest -Uri "http://localhost:5251/api/books" -Headers @{"X-API-KEY"="dev-api-key"}
# Or using curl (if available in PowerShell)
curl -H "X-API-KEY: dev-api-key" http://localhost:5251/api/books
```
</details>

## Terraform

### 0) Authenticate locally (human/high-priv)

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
gcloud auth login
gcloud config set project <YOUR_PROJECT>  # Replace with your GCP project ID
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
gcloud auth login
gcloud config set project <YOUR_PROJECT>  # Replace with your GCP project ID
```
</details>

### 1) Bootstrap (run once with human creds)
Creates state bucket + Terraform CI service account + enables APIs.

**Replace placeholders:**
- `<YOUR_PROJECT>` → Your GCP project ID
- `<UNIQUE_BUCKET>` → Globally unique bucket name (e.g., `my-demo-tf-state-123456`)

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var="project_id=<YOUR_PROJECT>" \
  -var="state_bucket_name=<UNIQUE_BUCKET>" \
  -var="region=us-central1"
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
cd terraform/bootstrap
terraform init
terraform apply `
  -var="project_id=<YOUR_PROJECT>" `
  -var="state_bucket_name=<UNIQUE_BUCKET>" `
  -var="region=us-central1"
```

> **💡 Note:** In PowerShell, use backtick (`` ` ``) for line continuation instead of backslash (`\`).

</details>

**Outputs:** state bucket name and Terraform service account email. **Save the bucket name** for step 2.

### 2) App stack (provision infrastructure with placeholder image)
Deploy the infrastructure (Artifact Registry, Cloud Run service, IAM) with a placeholder image. The real application will be deployed via CI/CD.

> **💡 Best Practice:** This approach separates infrastructure provisioning (Terraform) from application deployment (CI/CD). The initial deployment uses a public placeholder image (`gcr.io/cloudrun/hello`), and CI/CD will deploy your actual application.

**Replace placeholders:**
- `<YOUR_BUCKET>` → The bucket name from step 1 output
- `<YOUR_PROJECT>` → Your GCP project ID (same as step 1)
- `<YOUR_API_KEY>` → A secure random string for API authentication

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
cd terraform/app
terraform init -backend-config="bucket=<YOUR_BUCKET>"
terraform plan \
  -var="project_id=<YOUR_PROJECT>" \
  -var="region=us-central1" \
  -var="repository_id=demo-api" \
  -var="service_name=books-api" \
  -var="api_key=<YOUR_API_KEY>"
terraform apply \
  -var="project_id=<YOUR_PROJECT>" \
  -var="region=us-central1" \
  -var="repository_id=demo-api" \
  -var="service_name=books-api" \
  -var="api_key=<YOUR_API_KEY>" \
  -auto-approve
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
cd terraform/app
terraform init -backend-config="bucket=<YOUR_BUCKET>"
terraform plan `
  -var="project_id=<YOUR_PROJECT>" `
  -var="region=us-central1" `
  -var="repository_id=demo-api" `
  -var="service_name=books-api" `
  -var="api_key=<YOUR_API_KEY>"
terraform apply `
  -var="project_id=<YOUR_PROJECT>" `
  -var="region=us-central1" `
  -var="repository_id=demo-api" `
  -var="service_name=books-api" `
  -var="api_key=<YOUR_API_KEY>" `
  -auto-approve
```

> **💡 Note:** In PowerShell, use backtick (`` ` ``) for line continuation instead of backslash (`\`).

</details>

**Outputs:** Cloud Run URL (direct access), API key (echoed from input).

> **⚠️ Note:** The Cloud Run service will initially show the placeholder "Hello World" page. After setting up CI/CD (steps 3-4) and pushing to `main`, your actual Books API will be deployed.

> **💡 Why repeat variables in both `plan` and `apply`?** Terraform doesn't save variable values between commands. You must provide them to both `plan` and `apply`, or use a `.tfvars` file to avoid repetition.

<details>
<summary><b>Optional: Use a .tfvars file to avoid repetition</b></summary>

Create a file `terraform/app/terraform.tfvars` (this file is gitignored):

```hcl
project_id    = "tech-demo-481009"
region        = "us-central1"
repository_id = "demo-api"
service_name  = "books-api"
api_key       = "your-secret-api-key-here"
```

Then you can simply run:
```bash
terraform plan
terraform apply -auto-approve
```

Terraform automatically loads `terraform.tfvars` if it exists.

> **⚠️ Security:** Never commit `terraform.tfvars` to Git if it contains secrets! It's already in `.gitignore`.

</details>

### 3) Prepare CI service account key (for GitHub Actions)
Create a JSON key for the Terraform service account created in step 1.

**Replace placeholder:**
- `<YOUR_PROJECT>` → Your GCP project ID

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=terraform-ci@<YOUR_PROJECT>.iam.gserviceaccount.com
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
gcloud iam service-accounts keys create sa-key.json `
  --iam-account=terraform-ci@<YOUR_PROJECT>.iam.gserviceaccount.com
```
</details>

> **⚠️ Security Note:** Prefer workload identity if available; use service account keys only for demo/testing purposes. Keep the `sa-key.json` file secure and never commit it to version control.

### 4) Configure GitHub Actions secrets and variables
Set up the required secrets and variables for the CI/CD pipeline.

**Required GitHub Secrets:**
- `GCP_SA_KEY` → Content of `sa-key.json` file (entire JSON)
- `API_KEY` → Your API key from step 2 (e.g., `<YOUR_API_KEY>`)

**Required GitHub Variables:**
- `GCP_PROJECT_ID` → Your GCP project ID (e.g., `tech-demo-481009`)
- `GCP_REGION` → Region (e.g., `us-central1`)
- `GAR_REPOSITORY` → Artifact Registry repo name (e.g., `demo-api`)
- `SERVICE_NAME` → Cloud Run service name (e.g., `books-api`)
- `TF_STATE_BUCKET` → Terraform state bucket from step 1 output

> **💡 How to add in GitHub:**
> 1. Go to your repository → **Settings** → **Secrets and variables** → **Actions**
> 2. Click **New repository secret** to add `GCP_SA_KEY` and `API_KEY`
> 3. Click **Variables** tab → **New repository variable** to add the 5 variables above

### 5) Deploy your application via CI/CD
Push to the `main` branch to trigger the deployment pipeline.

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
git add .
git commit -m "Initial deployment"
git push origin main
```
</details>

**What happens:**
1. ✅ CI job runs: builds and tests the .NET application
2. ✅ Deploy job runs (on `main` only):
   - Builds Docker image with commit SHA tag
   - Pushes image to Artifact Registry
   - Runs Terraform to update Cloud Run with the new image
3. ✅ Your Books API is now live!

> **💡 Note:** After the first successful deployment, all future deployments happen automatically when you push to `main`. Terraform manages infrastructure, CI/CD manages application deployments.

## GitHub Actions CI/CD
- Triggers: PR (build/test), main (build/test, build+push image, terraform plan/apply).
- Required repo secrets/vars:
  - **Secrets**: `GCP_SA_KEY` (JSON), `API_KEY`
  - **Vars**: `GCP_PROJECT_ID`, `GCP_REGION` (`us-central1` default), `GAR_REPOSITORY` (`demo-api` default), `SERVICE_NAME` (`books-api` default), `TF_STATE_BUCKET` (bootstrap bucket)
- Image name: `${region}-docker.pkg.dev/${project}/${repo}/${service}:$GITHUB_SHA`
- Terraform backend bucket passed via `-backend-config` in the workflow.

## Calling the API (after deploy)
Replace placeholders:
- `<your-key>` → The API key you set in step 2 (`<YOUR_API_KEY>`)
- `<cloud-run-url>` → The Cloud Run URL from step 2 output (e.g., `https://books-api-xxxxx.run.app`)

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
# Call the protected /api/books endpoint
curl -H "X-API-KEY: <your-key>" <cloud-run-url>/api/books

# Call the public /health endpoint (no API key required)
curl <cloud-run-url>/health
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
# Call the protected /api/books endpoint
Invoke-WebRequest -Uri "<cloud-run-url>/api/books" -Headers @{"X-API-KEY"="<your-key>"}

# Or using curl (if available in PowerShell)
curl -H "X-API-KEY: <your-key>" <cloud-run-url>/api/books

# Call the public /health endpoint (no API key required)
Invoke-WebRequest -Uri "<cloud-run-url>/health"
# Or
curl <cloud-run-url>/health
```
</details>

## Troubleshooting

### Terraform State Lock Issues

If Terraform crashes or is interrupted, the state may remain locked. You'll see an error like:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  ...
```

**To force unlock the state:**

<details>
<summary><b>Bash/Linux/macOS</b></summary>

```bash
# For bootstrap stack
cd terraform/bootstrap
terraform force-unlock <LOCK_ID>

# For app stack
cd terraform/app
terraform force-unlock <LOCK_ID>
```
</details>

<details>
<summary><b>PowerShell/Windows</b></summary>

```powershell
# For bootstrap stack
cd terraform/bootstrap
terraform force-unlock <LOCK_ID>

# For app stack
cd terraform/app
terraform force-unlock <LOCK_ID>
```
</details>

Replace `<LOCK_ID>` with the ID shown in the error message.

> **⚠️ Warning:** Only force-unlock if you're certain no other Terraform process is running. Force-unlocking while another process is running can corrupt your state!

## Notes
- **API key authentication** is implemented as middleware (applies globally except `/health` endpoint).
- **Repository layer** is mocked/in-memory for demo; swap with real persistence as needed.
- **Cloud Run** is publicly accessible; API key validation happens in the application middleware.
- **PowerShell users**: Use backtick (`` ` ``) for line continuation in multi-line commands instead of backslash (`\`).
- **Security**: Never commit service account keys (`sa-key.json`) or API keys to version control. Add them to `.gitignore`.
