## GCP / Cloud Run Deployment Workflow Notes

You’re reading this exactly right: there really *are* multiple ways to touch GCP, and the confusion usually comes from mixing responsibilities between them.

This note maps your 4 options to **clear roles** and then gives you a **recommended workflow for this project** that avoids “hello image”–style problems.

---

### Your mental model (validated)

You listed these options:

1. **Everything local** – local Docker / emulators, nothing touches real GCP.
2. **Local CLI → real GCP** – `gcloud` from your machine, push images, create services/jobs.
3. **Local Terraform → real GCP** – `terraform apply` from your machine to manage infra.
4. **CI/CD → real GCP** – GitHub Actions builds/pushes images, updates Cloud Run, maybe runs Terraform.

All four are valid tools. The key is:

- **Local stuff (1)** = development + experiments.
- **Terraform (3)** = source of truth for **infrastructure shape** (buckets, jobs, SAs, scheduler).
- **CI/CD (4)** = source of truth for **application deployments** (which image version runs).
- **Local CLI (2)** = debugging, manual overrides, learning; not the main deployment mechanism.

---

### Recommended division of responsibilities

#### 1. Local Docker / emulators (inner dev loop)

**Use for:**

- Fast feedback while coding.
- Running `.NET` API locally (`dotnet run` or `docker run`) and hitting it from Postman/browser.
- Running the Python nightly job locally:
  - `BUCKET_NAME=some-dev-bucket python main.py`
- Verifying your Dockerfile works before pushing:
  - `docker build -t test-nightly src/nightly-job`

**Don’t use for:**

- Managing real GCP resources (no `gcloud deploy` from here as your *normal* pattern).
- Keeping environments in sync – local-only changes are ephemeral.

---

#### 2. Local CLI (`gcloud`) against real GCP

**Good for:**

- **Debugging and inspection:**
  - `gcloud run jobs execute nightly-cleanup-job --region us-central1 --project tech-demo-481009`
  - `gcloud run jobs describe nightly-cleanup-job ...`
- One-off experiments, learning commands.
- Emergency fixes *when CI is broken* (then you later reconcile with Terraform/CI).

**Not ideal for:**

- Regular deployments (you’ll forget what you did, nothing is documented in code).
- Long-term configuration (risk of drift from Terraform).

**Rule of thumb:**  
Use `gcloud` from your laptop to **run things and inspect things**, not to **define long-lived configuration**, unless you plan to copy that config into Terraform right after.

---

#### 3. Terraform from your machine (infra as code)

In this repo:

- `terraform/app` – Cloud Run **service** for API, Artifact Registry repo, IAM, etc.
- `terraform/jobs` – Cloud Run **job**, bucket, SAs, scheduler, IAM.

**Terraform should own:**

- **What exists**:
  - Cloud Run service & job names.
  - Buckets, SAs, IAM roles.
  - Cloud Scheduler schedule (cron/timezone).
- **Stable configuration**:
  - Env vars that are more infra-like (`BUCKET_NAME`).
  - Network settings, regions, scaling parameters, etc.

In `main.tf`, you already see the correct pattern for image fields:

```hcl
lifecycle {
  ignore_changes = [
    template[0].containers[0].image,
  ]
}
```

and for jobs:

```hcl
lifecycle {
  ignore_changes = [
    template[0].template[0].containers[0].image,
    client,
    client_version,
  ]
}
```

That says: **Terraform manages the job/service, but does *not* fight over the image**. This is what you want.

**When to run Terraform locally:**

- You added/changed:
  - A bucket
  - A scheduler job or its schedule
  - A service account or IAM binding
  - New env var that’s more infra-level
- Then:

```powershell
cd terraform/app    # or terraform/jobs
terraform plan -var "project_id=tech-demo-481009"
terraform apply -var "project_id=tech-demo-481009"
```

**What Terraform should *not* do here:**

- Decide *which build* of your app is deployed (no per-commit image tags). That’s CI/CD’s job.

---

#### 4. CI/CD (GitHub Actions) as the deploy mechanism

You now have:

- `ci-cd.yml` for the API.
- `deploy-nightly-job.yml` for the nightly job.

They do:

- Build Docker images.
- Push to Artifact Registry.
- Update Cloud Run service/job to point at the new image.

**This should be your primary way to:**

- Deploy new versions of the API (`ci-cd.yml`).
- Deploy new versions of the nightly job (`deploy-nightly-job.yml`).

That’s how you avoid the “hello image” problem:

- Terraform creates the job/service **once** (with a placeholder image), then:
- CI/CD is the **only thing** that regularly changes the image field.
- Terraform’s `ignore_changes` on `image` prevents it from resetting the image back to `hello` on later `terraform apply`.

---

### Concrete workflow for this repo

#### A. When you change **API code**

1. Develop locally (`dotnet test`, maybe `docker build` if you like).
2. Commit + push to `main`.
3. **API CI/CD** runs (`ci-cd.yml`):
   - Builds image from root `Dockerfile`.
   - Pushes to Artifact Registry.
   - Runs `gcloud run deploy` to update the Cloud Run service.
4. No manual `gcloud run deploy` or Terraform needed.

#### B. When you change the **nightly job Python code**

1. Develop locally:
   - `cd src/nightly-job`
   - `BUCKET_NAME=your-dev-bucket python main.py` (optional).
   - `docker build -t local-nightly .` (optional).
2. Commit + push to `main`.
3. **Nightly job CI/CD** runs (`deploy-nightly-job.yml`):
   - `docker build -t "$IMAGE" ./src/nightly-job`
   - `docker push "$IMAGE"`
   - `gcloud run jobs update nightly-cleanup-job --image "$IMAGE" ...`
4. Validate in GCP: run job once, check logs, check bucket.

#### C. When you change **infrastructure** (bucket, scheduler, etc.)

1. Modify files under `terraform/app` or `terraform/jobs`.
2. Locally:

```powershell
cd terraform/jobs   # or app
terraform plan -var "project_id=tech-demo-481009"
terraform apply -var "project_id=tech-demo-481009"
```

3. Verify in console (Scheduler, IAM, Cloud Run).

Later, you might move this to a Terraform pipeline, but local is fine to start.

#### D. When you **debug**

- Use **console / `gcloud`** to:
  - Run jobs (`gcloud run jobs execute ...`).
  - Inspect config (`gcloud run jobs describe ...`).
  - View logs (Cloud Logging).
- If you temporarily change something via `gcloud run jobs update ...`, either:
  - Intend it as your new deployment method (and maybe remove Terraform control), or
  - Copy that change back into CI/CD or Terraform so you don’t forget.

---

### Mental shortcut to avoid “hello image” again

- **Terraform = “what exists and how it’s wired.”**  
  Buckets, jobs, schedulers, SA roles, env vars. Image field is *owned by CI/CD* (use `ignore_changes` to enforce that).

- **CI/CD = “which build runs.”**  
  Build, push, update Cloud Run. Never use Terraform to flip image tags here.

- **Local CLI = “observe and poke.”**  
  For running, describing, and debugging, not regular deployments.
