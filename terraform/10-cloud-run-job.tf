# Cloud Run Job for seed-data-gcp — run once to populate the database

resource "google_cloud_run_v2_job" "seed_data" {
  name     = "seed-data-gcp"
  location = var.region
  project  = var.project_id
  labels   = local.common_labels

  template {
    template {
      containers {
        image = "${local.image_prefix}/seed-data-gcp:latest"
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
        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
      service_account = google_service_account.seed_sa.email
      max_retries     = 3
      timeout         = "600s"
      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.postgres.connection_name]
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}
