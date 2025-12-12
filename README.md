# GCP Demo Books API (.NET + Cloud Run + Terraform)

Containerized ASP.NET Core Web API (controller/service/repo) with API-key auth, deployed to Cloud Run, fronted by API Gateway, provisioned via Terraform (bootstrap + app stacks), and shipped with GitHub Actions CI/CD.

## Endpoints
- `GET /health` (no auth)
- `GET /api/books` (requires header `X-API-KEY: <key>`)

## Repo Structure
- `src/Api` — ASP.NET Core Web API with API key filter, books controller, service, and in-memory repo
- `tests/Api.UnitTests` — xUnit tests (service + API key filter)
- `Dockerfile` — multi-stage build to port 8080
- `terraform/bootstrap` — enables APIs, creates remote state bucket + Terraform service account
- `terraform/app` — Artifact Registry, Cloud Run, API Gateway, IAM; uses remote GCS backend
- `.github/workflows/ci-cd.yml` — build/test, image push, terraform plan/apply (main)

## Prereqs
- GCP project + billing enabled
- Service account key for CI with at least: `storage.admin`, `artifactregistry.admin`, `run.admin`, `apigateway.admin`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `serviceusage.serviceUsageAdmin`
- Terraform >= 1.8, Docker, .NET 9 SDK locally if running manually

## Local dev
```bash
dotnet test
dotnet run --project src/Api/Api.csproj
# call with key from appsettings.Development.json (X-API-KEY: dev-api-key)
curl -H "X-API-KEY: dev-api-key" http://localhost:5251/api/books
```

## Terraform
### 0) Authenticate locally (human/high-priv)
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT
```

### 1) Bootstrap (run once with human creds)
Creates state bucket + Terraform CI service account + enables APIs.
```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var="project_id=YOUR_PROJECT" \
  -var="state_bucket_name=UNIQUE_BUCKET" \
  -var="region=us-central1"
```
Outputs: state bucket name and Terraform service account email.

### 2) App stack (uses remote GCS backend)
Set backend to the bootstrap bucket:
```bash
cd terraform/app
terraform init -backend-config="bucket=YOUR_BUCKET"
terraform plan \
  -var="project_id=YOUR_PROJECT" \
  -var="region=us-central1" \
  -var="repository_id=demo-api" \
  -var="service_name=books-api" \
  -var="image=us-central1-docker.pkg.dev/YOUR_PROJECT/demo-api/books-api:latest" \
  -var="api_key=YOUR_API_KEY"
terraform apply -auto-approve
```
Outputs: Cloud Run URL, API Gateway hostname, API key (echoed from input).

### 3) Prepare CI service account key (outside Terraform)
Use the bootstrap-created SA (output). Create one JSON key and store it securely (for GitHub Actions `GCP_SA_KEY`):
```bash
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=terraform-ci@YOUR_PROJECT.iam.gserviceaccount.com
```
Prefer workload identity if available; use keys only for the demo pipeline.

### 4) Switch CI/CD to the service account
- Add secrets: `GCP_SA_KEY` (JSON), `API_KEY`.
- Add vars: `GCP_PROJECT_ID`, `GCP_REGION`, `GAR_REPOSITORY`, `SERVICE_NAME`, `TF_STATE_BUCKET`.
- Pipeline will build/test, build+push image, and run Terraform with the remote backend bucket.

## GitHub Actions CI/CD
- Triggers: PR (build/test), main (build/test, build+push image, terraform plan/apply).
- Required repo secrets/vars:
  - Secrets: `GCP_SA_KEY` (JSON), `API_KEY`
  - Vars: `GCP_PROJECT_ID`, `GCP_REGION` (`us-central1` default), `GAR_REPOSITORY` (`demo-api` default), `SERVICE_NAME` (`books-api` default), `TF_STATE_BUCKET` (bootstrap bucket)
- Image name: `${region}-docker.pkg.dev/${project}/${repo}/${service}:$GITHUB_SHA`
- Terraform backend bucket passed via `-backend-config` in the workflow.

## Calling the API (after deploy)
```bash
curl -H "X-API-KEY: <your-key>" https://<gateway-host>/api/books
```

## Notes
- API key is enforced in the controller layer via `ApiKeyAuthFilter`.
- Repository layer is mocked/in-memory for demo; swap with real persistence as needed.
- API Gateway forwards to Cloud Run using its own service account with Run Invoker.

