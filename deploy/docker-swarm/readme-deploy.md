

## 🚀 Deploying with Docker Swarm

You have **two options** to deploy:

---

### ✅ Option 1: Using `docker-compose` (Development Only)

This is simple but **does not support multiple replicas**:

```bash
docker-compose up --build
```

> Run this from the root of the project. It will build and run all services using local Docker images.

---

### ✅ Option 2: Using Docker Swarm (Recommended for Production)

Since we’re using **locally built images**, build each one manually (in real scenarios, you'd pull from a registry like Docker Hub or GitLab Registry):

#### 🔧 Build Docker Images

```bash
# Result app
docker build -t result:latest ./result

# Worker app
docker build -t worker:latest ./worker

# Vote app (builds final stage of multi-stage Dockerfile)
docker build --target final -t vote:latest ./vote
```

> Adjust paths if needed based on your folder structure.

---

### 🚀 Deploy the Stack

From the `deploy/docker-swarm` folder:

```bash
# Initialize Docker Swarm (only needed once per node)
docker swarm init

# Deploy the app stack
docker stack deploy -c docker-stack.yml vote-app


# to delete 
docker stack rm vote-app
```

