# Service accounts for each *-gcp Cloud Run service
resource "google_service_account" "vote_sa" {
  account_id   = "vote-gcp-sa"
  display_name = "Vote GCP Service Account"
  description  = "For vote-gcp Cloud Run service"
}

resource "google_service_account" "result_sa" {
  account_id   = "result-gcp-sa"
  display_name = "Result GCP Service Account"
  description  = "For result-gcp Cloud Run service"
}

resource "google_service_account" "worker_sa" {
  account_id   = "worker-gcp-sa"
  display_name = "Worker GCP Service Account"
  description  = "For worker-gcp Cloud Run service"
}

resource "google_service_account" "seed_sa" {
  account_id   = "seed-gcp-sa"
  display_name = "Seed Data GCP Service Account"
  description  = "For seed-data-gcp Cloud Run Job"
}

# Vote SA can publish to PubSub
resource "google_pubsub_topic_iam_member" "vote_publisher" {
  topic  = google_pubsub_topic.votes.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.vote_sa.email}"
}

# Worker SA can receive from PubSub
resource "google_pubsub_subscription_iam_member" "worker_subscriber" {
  subscription = google_pubsub_subscription.worker_push.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.worker_sa.email}"
}

# All services need cloudsql.client to connect via Unix socket
resource "google_project_iam_member" "vote_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.vote_sa.email}"
}

resource "google_project_iam_member" "result_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.result_sa.email}"
}

resource "google_project_iam_member" "worker_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.worker_sa.email}"
}

resource "google_project_iam_member" "seed_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.seed_sa.email}"
}

# Worker SA needs run.invoker on worker-gcp Cloud Run service for PubSub push
resource "google_cloud_run_service_iam_member" "worker_invoker" {
  location = var.region
  service  = "worker-gcp"
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.worker_sa.email}"
}

# Worker SA needs Cloud Build + Cloud Run Deploy for the trigger
resource "google_project_iam_member" "worker_cloudbuild" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.worker_sa.email}"
}

resource "google_project_iam_member" "worker_run_deploy" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.worker_sa.email}"
}
