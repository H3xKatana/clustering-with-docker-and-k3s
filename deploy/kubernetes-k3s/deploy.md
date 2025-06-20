
## 🚀 Deploying with K3s (Lightweight Kubernetes)

Follow these steps to set up and deploy your application using [K3s](https://k3s.io) — a lightweight Kubernetes distribution by Rancher.

---

### ✅ 1. Install K3s

Install K3s using the official installation script:

```bash
curl -sfL https://get.k3s.io | sh -
```

After installation, K3s will automatically start the Kubernetes server and configure `kubectl`.

---

### ✅ 2. Verify Cluster Status

Use the following command to verify your node is up and ready:

```bash
sudo kubectl get nodes
```

You should see your node listed with a `Ready` status.

---

### ✅ 3. Deploy Your Resources
# simple deployment for testing only
Apply your Kubernetes configuration files:

```bash
kubectl create -f pods/
kubectl create -f services/
```
oR 
```bash
kubectl apply -f pods/
kubectl apply -f services/
```
> Make sure your YAML files are properly configured inside the `pods/` and `services/` directories.

> Apply vs Create : Apply is like create but if resources already exits it will update the changes but create will fail in case object already exists
---

### ✅ 4. Monitor Deployment

Check the status of your pods and services:

```bash
kubectl get pods
kubectl get svc
```

---

