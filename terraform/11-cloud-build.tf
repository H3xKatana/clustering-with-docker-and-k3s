# Cloud Build trigger — auto-build & deploy on push to gcp-native branch
#
# NOTE: Before Terraform can manage this trigger, the GitHub repo must be
# connected to Cloud Build via the console (one-time manual step):
#   1. Go to Cloud Build > Triggers > Connect Repository
#   2. Install the Google Cloud Build GitHub App for H3xKatana/clustering-with-docker-and-k3s
#   3. Then uncomment the resource below and run `terraform apply`
#
# Alternatively, create the trigger manually once:
#   gcloud builds triggers create github \
#     --name="deploy-gcp-native" \
#     --repo-owner="H3xKatana" \
#     --repo-name="clustering-with-docker-and-k3s" \
#     --branch-pattern="^gcp-native$" \
#     --build-config="cloudbuild.yaml" \
#     --included-files="apps/vote-gcp/**,apps/result-gcp/**,apps/worker-gcp/**,apps/seed-data-gcp/**,cloudbuild.yaml" \
#     --region="us-central1"
#
# resource "google_cloudbuild_trigger" "deploy" {
#   name        = "deploy-gcp-native"
#   description = "Build & deploy all -gcp services on push to gcp-native branch"
#   project     = var.project_id
#
#   github {
#     owner = "H3xKatana"
#     name  = "clustering-with-docker-and-k3s"
#     push {
#       branch = "^gcp-native$"
#     }
#   }
#
#   filename = "cloudbuild.yaml"
#
#   included_files = [
#     "apps/vote-gcp/**",
#     "apps/result-gcp/**",
#     "apps/worker-gcp/**",
#     "apps/seed-data-gcp/**",
#     "cloudbuild.yaml",
#   ]
# }
