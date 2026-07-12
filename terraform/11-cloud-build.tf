# Cloud Build trigger — auto-build & deploy on push to gcp-native branch
# Uses 2nd-gen Cloud Build with GitHub App connection (google-beta provider)

resource "google_cloudbuild_trigger" "deploy" {
  provider    = google.beta
  name        = "deploy-gcp-native"
  description = "Build & deploy all -gcp services on push to gcp-native branch"
  project     = var.project_id
  location    = "us-central1"

  repository_event_config {
    repository = "projects/${var.project_id}/locations/us-central1/connections/main-gh/repositories/clustering-with-docker-and-k3s"
    push {
      branch = "^gcp-native$"
    }
  }

  service_account = "projects/${var.project_id}/serviceAccounts/${google_service_account.worker_sa.email}"

  filename = "cloudbuild.yaml"

  included_files = [
    "apps/vote-gcp/**",
    "apps/result-gcp/**",
    "apps/worker-gcp/**",
    "apps/seed-data-gcp/**",
    "cloudbuild.yaml",
  ]
}
