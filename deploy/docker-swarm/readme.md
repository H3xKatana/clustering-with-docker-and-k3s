

##  Docker Swarm & Stack Deployment Guide

These notes cover how to initialize a Docker Swarm, manage nodes, deploy services and stacks, and view swarm-related information.

> **Note:**
> The Docker Compose file and images used are created locally. For production, the **best practice** is to build and publish the images to a **Docker registry**, then reference them in the Compose file for use in `docker stack deploy`.

---

### 🔧 1. Initialize Docker Swarm & Add Nodes

```bash
# Initialize a new Swarm (run on the manager node)
docker swarm init

# Get the join command for worker nodes
docker swarm join-token worker

# Get the join command for manager nodes
docker swarm join-token manager

# Join a Swarm (run on another node)
docker swarm join --token <token> <manager-ip>:2377

# Leave the Swarm (run on a node)
docker swarm leave

# Force leave (run on a manager)
docker swarm leave --force
```

---

### 👥 2. Manage Swarm Nodes

```bash
# List all nodes in the swarm (run on manager)
docker node ls

# Inspect a specific node
docker node inspect <node-id>

# Drain a node (prevent it from receiving tasks)
docker node update --availability drain <node-id>

# Reactivate a node
docker node update --availability active <node-id>
```

---

### 📦 3. Deploy Containers with `docker service`

```bash
# Deploy a new service
docker service create \
  --name vote \
  --replicas 3 \
  -p 80:80 \
  dockersamples/examplevotingapp_vote

# List all services
docker service ls

# Inspect service details
docker service inspect <service-name> --pretty

# Scale a service
docker service scale vote=5

# Update the image of a service
docker service update --image newimage:tag <service-name>

# Remove a service
docker service rm <service-name>

# List tasks (containers) of a service
docker service ps <service-name>

# List all running containers
docker container ls

# View service logs
docker service logs <service-name> --follow
```

---

### 🗂️ 4. Deploy Multi-Service Apps with Docker Stack

```bash
# Deploy a stack using docker-compose.yml
docker stack deploy -c docker-compose.yml myapp

# List all stacks
docker stack ls

# List services in a stack
docker stack services myapp

# List tasks (containers) in a stack
docker stack ps myapp

# Remove a stack
docker stack rm myapp
```

---

### ℹ️ 5. General Swarm Info & Status

```bash
# Check Docker Swarm status
docker info

# Quick overview: nodes and services
docker node ls
docker service ls
```
###  Swarm vs Compose 
| Feature                    | `docker-compose`               | `docker stack deploy` (Swarm)       |
| -------------------------- | ------------------------------ | ----------------------------------- |
| Networking                 | Creates custom bridge networks | Uses overlay networks               |
| Scaling                    | `docker-compose up --scale`    | `replicas:` in `docker-compose.yml` |
| Rolling updates, placement | ❌ Not supported                | ✅ Supported via swarm features      |
| Load balancing             | ❌ Manual                       | ✅ Automatic built-in                |
| Orchestration              | ❌ Local only                   | ✅ Distributed with Swarm            |
| Volume behavior            | Shared on host                 | Must be shared across nodes         |



---
---

When converting a `docker-compose.yml` file for **Docker Swarm**, the main change is using the `deploy:` section, which is **only used in Docker Swarm** and ignored by `docker-compose up`.

Here are the **main features you can (and should) add** when targeting Docker Swarm:

---

## ✅ Key `deploy:` Options for Docker Swarm

```yaml
services:
  web:
    image: nginx
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: "0.50"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 256M
      update_config:
        parallelism: 2
        delay: 10s
        failure_action: rollback
```


---

## ✅ Summary: What to Add for Swarm

| Feature          | Keyword           | Purpose                             |
| ---------------- | ----------------- | ----------------------------------- |
| Scaling          | `replicas`        | Number of instances                 |
| Health/restarts  | `restart_policy`  | When/how to restart services        |
| Scheduling       | `placement`       | Restrict nodes to run containers on |
| Resource control | `resources`       | Set CPU/memory limits/reservations  |
| Rolling updates  | `update_config`   | Control how updates happen          |
| Rollbacks        | `rollback_config` | Handle update failures gracefully   |

---


