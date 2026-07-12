.PHONY: help init plan apply destroy output \
        build-vote build-result build-worker-gcp build-seed-data build-all \
        push-vote push-result push-worker-gcp push-seed-data push-all \
        deploy-vote deploy-result deploy-worker-gcp deploy-seed-data \
        update-subscription \
        setup-branch sync-source clean info

TF_DIR      := terraform
TF_KEY      := $(TF_DIR)/terraform-sa-key.json
PROJECT_ID  := $(shell terraform -chdir=$(TF_DIR) output -raw project_id 2>/dev/null || echo "k8s-the-hard-way-tf-morta")
REGION      := $(shell terraform -chdir=$(TF_DIR) output -raw region 2>/dev/null || echo "us-central1")
REPO_PREFIX := $(shell terraform -chdir=$(TF_DIR) output -raw artifact_registry_repo 2>/dev/null || echo "$(REGION)-docker.pkg.dev/$(PROJECT_ID)/vote-app")
DB_PASSWORD ?= vote-app-dev-password
GOOGLE_APPLICATION_CREDENTIALS := $(abspath $(TF_KEY))

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Infrastructure ────────────────────────────────────────────────────────────

$(TF_KEY):
	@echo "Creating Terraform SA key..."
	gcloud iam service-accounts keys create $(TF_KEY) \
		--iam-account=terraform@$(PROJECT_ID).iam.gserviceaccount.com \
		--project=$(PROJECT_ID)

init: export GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS)
init: $(TF_KEY) ## terraform init
	terraform -chdir=$(TF_DIR) init

plan: export GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS)
plan: $(TF_KEY) ## terraform plan
	terraform -chdir=$(TF_DIR) plan

apply: export GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS)
apply: $(TF_KEY) ## terraform apply
	terraform -chdir=$(TF_DIR) apply

destroy: export GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS)
destroy: $(TF_KEY) ## terraform destroy
	terraform -chdir=$(TF_DIR) destroy

output: export GOOGLE_APPLICATION_CREDENTIALS=$(GOOGLE_APPLICATION_CREDENTIALS)
output: $(TF_KEY) ## Show terraform outputs
	terraform -chdir=$(TF_DIR) output

# ─── Build Images ──────────────────────────────────────────────────────────────

build-vote: ## Build vote-gcp image
	docker build -t vote-gcp apps/vote-gcp

build-result: ## Build result-gcp image
	docker build -t result-gcp apps/result-gcp

build-worker-gcp: ## Build worker-gcp image
	docker build -t worker-gcp apps/worker-gcp

build-seed-data: ## Build seed-data-gcp image
	docker build -t seed-data-gcp apps/seed-data-gcp

build-all: build-vote build-result build-worker-gcp build-seed-data ## Build all 4 images

# ─── Push to Artifact Registry ─────────────────────────────────────────────────

push-vote: ## Tag & push vote-gcp
	docker tag vote-gcp $(REPO_PREFIX)/vote-gcp:latest
	docker push $(REPO_PREFIX)/vote-gcp:latest

push-result: ## Tag & push result-gcp
	docker tag result-gcp $(REPO_PREFIX)/result-gcp:latest
	docker push $(REPO_PREFIX)/result-gcp:latest

push-worker-gcp: ## Tag & push worker-gcp
	docker tag worker-gcp $(REPO_PREFIX)/worker-gcp:latest
	docker push $(REPO_PREFIX)/worker-gcp:latest

push-seed-data: ## Tag & push seed-data-gcp
	docker tag seed-data-gcp $(REPO_PREFIX)/seed-data-gcp:latest
	docker push $(REPO_PREFIX)/seed-data-gcp:latest

push-all: push-vote push-result push-worker-gcp push-seed-data ## Push all 4 images

# ─── Cloud Run helpers ─────────────────────────────────────────────────────────

CLOUD_SQL_CONN  := $(PROJECT_ID):$(REGION):vote-app-db
DB_HOST         := /cloudsql/$(CLOUD_SQL_CONN)/.s.PGSQL.5432
DB_ENV_VARS     := DB_USER=app_user,DB_PASSWORD=$(DB_PASSWORD),DB_NAME=votes,DB_HOST=$(DB_HOST)

deploy-vote: ## Deploy vote-gcp to Cloud Run (public)
	gcloud run deploy vote-gcp \
		--image $(REPO_PREFIX)/vote-gcp:latest \
		--region $(REGION) \
		--allow-unauthenticated \
		--add-cloudsql-instances $(CLOUD_SQL_CONN) \
		--set-env-vars "PUBSUB_TOPIC_ID=votes,GOOGLE_CLOUD_PROJECT=$(PROJECT_ID)"

deploy-result: ## Deploy result-gcp to Cloud Run (public)
	gcloud run deploy result-gcp \
		--image $(REPO_PREFIX)/result-gcp:latest \
		--region $(REGION) \
		--allow-unauthenticated \
		--add-cloudsql-instances $(CLOUD_SQL_CONN) \
		--set-env-vars "$(DB_ENV_VARS)"

deploy-worker-gcp: ## Deploy worker-gcp to Cloud Run (internal — PubSub push only)
	gcloud run deploy worker-gcp \
		--image $(REPO_PREFIX)/worker-gcp:latest \
		--region $(REGION) \
		--no-allow-unauthenticated \
		--add-cloudsql-instances $(CLOUD_SQL_CONN) \
		--set-env-vars "$(DB_ENV_VARS)"

deploy-seed-data: ## Create/update seed-data-gcp as Cloud Run Job
	gcloud run jobs create seed-data-gcp \
		--image $(REPO_PREFIX)/seed-data-gcp:latest \
		--region $(REGION) \
		--add-cloudsql-instances $(CLOUD_SQL_CONN) \
		--set-env-vars "$(DB_ENV_VARS)" 2>/dev/null || \
	gcloud run jobs update seed-data-gcp \
		--image $(REPO_PREFIX)/seed-data-gcp:latest \
		--region $(REGION)

update-subscription: ## Point PubSub push subscription to worker-gcp URL
	@echo "Fetching worker-gcp URL..."; \
	WORKER_URL=$$(gcloud run services describe worker-gcp --region=$(REGION) --format='value(status.url)'); \
	WORKER_SA=$$(terraform -chdir=$(TF_DIR) output -raw worker_sa_email); \
	echo "Worker URL: $$WORKER_URL"; \
	echo "Worker SA:  $$WORKER_SA"; \
	gcloud pubsub subscriptions update worker-votes-sub \
		--push-endpoint=$$WORKER_URL \
		--push-auth-service-account=$$WORKER_SA

# ─── Git Branching ─────────────────────────────────────────────────────────────

setup-branch: ## Create & push gcp-native branch
	git checkout -b gcp-native
	git push origin gcp-native

sync-source: ## Fetch original app source from GitHub (reference copies in apps/)
	mkdir -p apps/vote apps/result apps/worker apps/seed-data
	@echo "Downloading original app source from H3xKatana/clustering-with-docker-and-k3s..."
	gh api repos/H3xKatana/clustering-with-docker-and-k3s/contents/apps/vote --jq '.[] | "\(.download_url) \(.name)"' | \
		while read url name; do curl -sL "$$url" -o "apps/vote/$$name"; done
	gh api repos/H3xKatana/clustering-with-docker-and-k3s/contents/apps/result --jq '.[] | "\(.download_url) \(.name)"' | \
		while read url name; do curl -sL "$$url" -o "apps/result/$$name"; done
	gh api repos/H3xKatana/clustering-with-docker-and-k3s/contents/apps/worker --jq '.[] | "\(.download_url) \(.name)"' | \
		while read url name; do curl -sL "$$url" -o "apps/worker/$$name"; done
	gh api repos/H3xKatana/clustering-with-docker-and-k3s/contents/apps/seed-data --jq '.[] | "\(.download_url) \(.name)"' | \
		while read url name; do curl -sL "$$url" -o "apps/seed-data/$$name"; done
	gh api repos/H3xKatana/clustering-with-docker-and-k3s/contents/apps/compose.yml --jq '.download_url' | \
		xargs curl -sL -o apps/compose.yml

# ─── Utilities ─────────────────────────────────────────────────────────────────

clean: ## Remove local Docker images
	docker rmi vote-gcp result-gcp worker-gcp seed-data-gcp 2>/dev/null || true

info: ## Show configured project details
	@echo "──────────────────────────────────────────────"
	@echo " Project  : $(PROJECT_ID)"
	@echo " Region   : $(REGION)"
	@echo " Repo     : $(REPO_PREFIX)"
	@echo " DB Host  : $(DB_HOST)"
	@echo " TF Key   : $(TF_KEY)"
	@echo "──────────────────────────────────────────────"
