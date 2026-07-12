# Example Voting App — GCP Native Edition

A fully serverless, GCP-hosted version of the [Example Voting App](https://github.com/dockersamples/example-voting-app).  
No VPS, no Redis, no GKE — everything runs on **Cloud Run**, **PubSub**, and **Cloud SQL**.

---

## Architecture

```
                    ┌─────────────┐
                    │   Cloud SQL │
                    │  (Postgres) │
                    └──┬──▲───────┘
         ┌─────────────┘  │
         ▼                │
┌────────────────┐  ┌──────────────┐
│  worker-gcp    │  │  result-gcp  │
│ (.NET 8 HTTP)  │  │  (Node.js)   │
│ PubSub push    │  │  polls DB    │
│  → writes DB   │  │  → WebSocket │
└──────▲─────────┘  └──────┬───────┘
       │                    │
       │ PubSub push        │ public
       │ (OIDC auth)        │
       │                    │
┌──────┴─────────┐  ┌──────┴───────┐
│   PubSub       │  │   Browser    │
│  votes topic   │  │  (WebSocket) │
└──────▲─────────┘  └──────────────┘
       │
       │ publish
       │
┌──────┴─────────┐
│  vote-gcp      │
│  (Python/Flask)│
│  public HTTP   │
└──────┬─────────┘
       │ users vote
       │
  ┌────┴────┐
  │ Browser │
  └─────────┘
```

### Service breakdown

| Service | Language | Role | Public? |
|---|---|---|---|
| **vote-gcp** | Python/Flask | Web UI for voting. Publishes votes to PubSub. | ✅ Yes |
| **worker-gcp** | C# .NET 8 | HTTP endpoint for PubSub push. Decodes vote, writes to Postgres. | ❌ No (PubSub only) |
| **result-gcp** | Node.js/Express | Web UI for results. Polls Postgres every 1s, streams via Socket.IO. | ✅ Yes |
| **seed-data-gcp** | Python | Cloud Run Job. Inserts sample votes into Postgres. | — (Job) |

### What changed from the original

| Original | GCP-native replacement |
|---|---|
| Redis queue (`rpush`/`blpop`) | PubSub topic + push subscription |
| Self-hosted Postgres container | Cloud SQL (db-f1-micro) |
| GitHub Actions → Docker Hub → VPS | Cloud Build → Artifact Registry → Cloud Run |
| Gunicorn on port 80 | Cloud Run on port 8080 |
| Apache Bench for seed data | Python script, direct Postgres insert |

---

## Infrastructure (Terraform)

All GCP resources are defined in `terraform/`:

```
terraform/
├── 00-locals.tf          # Common labels (env, project, author)
├── 01-provider.tf        # Google provider config
├── 02-variables.tf       # Input variables
├── 03-services.tf        # Enabled GCP APIs (5 services)
├── 04-cloud-sql.tf       # Cloud SQL Postgres instance
├── 05-artifact-registry.tf # Docker image repository
├── 06-pubsub.tf          # Topic + push subscription
├── 07-iam.tf             # Service accounts + IAM bindings
├── 08-outputs.tf         # Terraform outputs
├── 09-cloud-run.tf       # 3 Cloud Run services
├── 10-cloud-run-job.tf   # 1 Cloud Run Job (seed data)
└── 11-cloud-build.tf     # Cloud Build trigger (commented out)
```

**25 resources** total, all labeled with `env=dev`, `project=002-gcp-github-cicd-pipline`, `provider=terraform`.

---

## Deploy from scratch

### Prerequisites

- A GCP project with billing enabled
- `gcloud` CLI authenticated with owner/editor permissions
- `terraform` CLI installed
- This repo cloned

### 1. Set up Terraform

```bash
cd terraform

# Auth as your user (the Terraform SA will be created by cloud-init or manually)
gcloud auth application-default login

# Initialize
terraform init

# Apply
terraform apply
```

This creates:
- Artifact Registry repository
- PubSub topic + push subscription
- 4 service accounts + IAM bindings
- Cloud SQL Postgres instance (db-f1-micro)
- Cloud Run services (vote-gcp, result-gcp, worker-gcp)
- Cloud Run Job (seed-data-gcp)

### 2. Build & push container images

```bash
# Using Cloud Build (no local Docker needed)
gcloud builds submit apps/vote-gcp \
  --tag us-central1-docker.pkg.dev/YOUR_PROJECT/vote-app/vote-gcp:latest
gcloud builds submit apps/result-gcp \
  --tag us-central1-docker.pkg.dev/YOUR_PROJECT/vote-app/result-gcp:latest
gcloud builds submit apps/worker-gcp \
  --tag us-central1-docker.pkg.dev/YOUR_PROJECT/vote-app/worker-gcp:latest
gcloud builds submit apps/seed-data-gcp \
  --tag us-central1-docker.pkg.dev/YOUR_PROJECT/vote-app/seed-data-gcp:latest
```

Or using the Makefile:

```bash
# Set project-specific vars first
export PROJECT_ID=your-project
export REGION=us-central1
export REPO_PREFIX=$REGION-docker.pkg.dev/$PROJECT_ID/vote-app

make build-all   # local Docker (if available)
make push-all    # tag & push to Artifact Registry
```

### 3. Deploy

```bash
# Terraform already created the services. Update their images:
gcloud run deploy vote-gcp --image $REPO_PREFIX/vote-gcp:latest --region $REGION
gcloud run deploy result-gcp --image $REPO_PREFIX/result-gcp:latest --region $REGION
gcloud run deploy worker-gcp --image $REPO_PREFIX/worker-gcp:latest --region $REGION

# Deploy & run seed job
gcloud run jobs update seed-data-gcp --image $REPO_PREFIX/seed-data-gcp:latest --region $REGION
gcloud run jobs execute seed-data-gcp --region $REGION

# Point PubSub subscription to the worker URL
gcloud pubsub subscriptions update worker-votes-sub \
  --push-endpoint $(gcloud run services describe worker-gcp --region $REGION --format='value(status.url)') \
  --push-auth-service-account worker-gcp-sa@$PROJECT_ID.iam.gserviceaccount.com
```

Or simply:

```bash
make deploy-all
make update-subscription
make run-seed
```

---

## CI/CD (Cloud Build)

A `cloudbuild.yaml` is included for automatic build-and-deploy on push to `gcp-native` branch:

```bash
# 1. Connect your GitHub repo at:
#    https://console.cloud.google.com/cloud-build/triggers?project=YOUR_PROJECT
#
# 2. Install the Google Cloud Build GitHub App for this repo
#
# 3. Uncomment the trigger in terraform/11-cloud-build.tf and apply:
cd terraform
terraform apply
```

Once connected, every push to `gcp-native` that touches `apps/*-gcp/**` will:
1. Build all 4 Docker images (tagged with commit SHA + `latest`)
2. Push to Artifact Registry
3. Deploy all 3 Cloud Run services with the new images

---

## URLs (current deployment)

- **Vote app**: https://vote-gcp-561706057114.us-central1.run.app
- **Result app**: https://result-gcp-561706057114.us-central1.run.app

---

## Makefile reference

```bash
make help          # List all targets
make init          # terraform init
make plan          # terraform plan
make apply         # terraform apply
make build-all     # Build all 4 images locally
make push-all      # Tag & push to Artifact Registry
make deploy-all    # Deploy all services
make update-subscription  # Point PubSub → worker-gcp URL
make run-seed      # Execute seed-data job
```
