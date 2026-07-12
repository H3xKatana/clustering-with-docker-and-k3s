# Cloud Run services for vote-gcp, result-gcp, worker-gcp
# Image is managed by Cloud Build triggers — Terraform ignores image changes

locals {
  image_prefix = "${var.region}-docker.pkg.dev/${var.project_id}/vote-app"
}

# ─── vote-gcp (public, no Cloud SQL) ─────────────────────────────────────────

resource "google_cloud_run_service" "vote_gcp" {
  name     = "vote-gcp"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "${local.image_prefix}/vote-gcp:latest"
        ports {
          container_port = 8080
        }
        env {
          name  = "PUBSUB_TOPIC_ID"
          value = "votes"
        }
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }
      service_account_name = google_service_account.vote_sa.email
    }
    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.postgres.connection_name
        "autoscaling.knative.dev/maxScale"      = "10"
      }
    }
  }

  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
    ]
  }
}

resource "google_cloud_run_service_iam_member" "vote_public" {
  location = var.region
  service  = google_cloud_run_service.vote_gcp.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ─── result-gcp (public, connects to Cloud SQL) ──────────────────────────────

resource "google_cloud_run_service" "result_gcp" {
  name     = "result-gcp"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "${local.image_prefix}/result-gcp:latest"
        ports {
          container_port = 8080
        }
        env {
          name  = "DB_USER"
          value = google_sql_user.app_user.name
        }
        env {
          name  = "DB_PASSWORD"
          value = var.db_password
        }
        env {
          name  = "DB_NAME"
          value = google_sql_database.votes.name
        }
        env {
          name  = "DB_HOST"
          value = "/cloudsql/${google_sql_database_instance.postgres.connection_name}"
        }
      }
      service_account_name = google_service_account.result_sa.email
    }
    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.postgres.connection_name
        "autoscaling.knative.dev/maxScale"      = "10"
      }
    }
  }

  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
    ]
  }
}

resource "google_cloud_run_service_iam_member" "result_public" {
  location = var.region
  service  = google_cloud_run_service.result_gcp.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ─── worker-gcp (internal — PubSub push only) ────────────────────────────────

resource "google_cloud_run_service" "worker_gcp" {
  name     = "worker-gcp"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "${local.image_prefix}/worker-gcp:latest"
        ports {
          container_port = 8080
        }
        env {
          name  = "DB_USER"
          value = google_sql_user.app_user.name
        }
        env {
          name  = "DB_PASSWORD"
          value = var.db_password
        }
        env {
          name  = "DB_NAME"
          value = google_sql_database.votes.name
        }
        env {
          name  = "DB_HOST"
          value = "/cloudsql/${google_sql_database_instance.postgres.connection_name}"
        }
      }
      service_account_name = google_service_account.worker_sa.email
    }
    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.postgres.connection_name
        "autoscaling.knative.dev/maxScale"      = "5"
      }
    }
  }

  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
    ]
  }
}
