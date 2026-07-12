# GCP Cloud Run Deployment

This directory documents the GCP-native deployment of the Example Voting App using **Cloud Run**, **PubSub**, and **Cloud SQL**.

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
│ (.NET 8)       │  │  (Node.js)   │
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
       │
       │ users vote
       │
  ┌────┴────┐
  │ Browser │
  └─────────┘
```

## Services

### vote-gcp (Python/Flask)
- **Role**: Web UI for voting
- **Endpoint**: `POST /` — accepts form data (`vote=a` or `vote=b`)
- **PubSub**: Publishes vote as JSON `{voter_id, vote}` to the `votes` topic
- **Port**: 8080 (Cloud Run)
- **Dependencies**: `google-cloud-pubsub` (no Redis)

### worker-gcp (C# .NET 8)
- **Role**: Processes votes from PubSub, writes to database
- **Endpoint**: `POST /` — receives PubSub push (base64-encoded JSON)
- **Database**: Cloud SQL Postgres via Unix socket (`/cloudsql/...`)
- **Table**: Auto-creates `votes(id, vote)` on startup
- **Error handling**: Unique violation → updates existing vote

### result-gcp (Node.js/Express)
- **Role**: Web UI for live results
- **Database**: Polls Postgres every 1s with `SELECT vote, COUNT(id)...`
- **WebSocket**: Streams scores via Socket.IO
- **Connection**: Cloud SQL via Unix socket (`/cloudsql/...`)

### seed-data-gcp (Python)
- **Role**: Cloud Run Job to populate sample data
- **Database**: Direct Postgres insert via `psycopg2`
- **Data**: 10 votes (5 cats, 5 dogs)

## Terraform Infrastructure

All resources are defined in `terraform/` (root of this repo):

| File | Resources | Labels |
|---|---|---|
| `00-locals.tf` | Common label definitions | — |
| `03-services.tf` | 5 enabled APIs | — |
| `04-cloud-sql.tf` | Postgres instance, database, user | ✅ |
| `05-artifact-registry.tf` | Docker repo | ✅ |
| `06-pubsub.tf` | Topic, push subscription | ✅ |
| `07-iam.tf` | 4 SAs, 8 IAM bindings | — |
| `09-cloud-run.tf` | 3 Cloud Run services + public IAM | — |
| `10-cloud-run-job.tf` | 1 Cloud Run Job | ✅ |
| `11-cloud-build.tf` | 1 Cloud Build trigger | — |

Labels: `env=dev`, `project=002-gcp-github-cicd-pipline`, `provider=terraform`, `author=0xkatana`

## CI/CD (Cloud Build)

Trigger: **deploy-gcp-native**

- **Event**: Push to `gcp-native` branch
- **Build**: Cloud Build builds all 4 images (tagged with commit SHA + latest)
- **Deploy**: Same build updates all 3 Cloud Run services
- **Service account**: `worker-gcp-sa` (Cloud Build Builder + Run Developer roles)
- **File filter**: Only runs when `apps/*-gcp/**` or `cloudbuild.yaml` changes

### Config file

[cloudbuild.yaml](../../cloudbuild.yaml) defines the build pipeline:

```yaml
steps:
  # Build all images
  - docker build -t vote-gcp ...
  - docker build -t result-gcp ...
  - docker build -t worker-gcp ...
  - docker build -t seed-data-gcp ...

  # Push to Artifact Registry
  # Deploy with gcloud run deploy
```

## Cost (monthly estimate)

| Resource | Cost |
|---|---|
| Cloud SQL db-f1-micro | ~$7.68 |
| Cloud Run (3 services, demo traffic) | ~$0 (free tier) |
| PubSub | ~$0 (free tier) |
| Artifact Registry (~1.5GB) | ~$0.10 |
| **Total** | **~$7.78/month** |

## Deploy

See the main [README.md](../../README.md) for full deploy instructions.
