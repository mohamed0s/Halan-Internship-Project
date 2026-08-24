# Halan Internship Project

A cloud-native, 3-tier enterprise application deployed on Kubernetes using Helm charts, GitOps principles (ArgoCD), and production-grade observability.

---

## 🏗️ Repository Structure

```text
halan-internship-project/
├── .github/
│   └── workflows/                   # CI: builds and pushes Docker images to DockerHub
├── docs/                            # Technical documentation & runbooks
│   ├── architecture.md              # Docker-era system architecture
│   ├── kubernetes-implementation.md # Kubernetes deployment documentation
│   ├── k8s-architecture.md          # Migration plan & design decisions
│   └── ci-cd-pipeline.md            # CI/CD pipeline documentation
├── frontend/                        # Nginx web server + HTML/CSS UI
├── backend/                         # Python Flask REST API
├── db/                              # PostgreSQL init SQL scripts
├── infra/
│   ├── terraform/                   # AWS infrastructure (VPC, EKS, RDS)
│   └── k8s/                         # All Kubernetes manifests & Helm values
│       ├── namespace.yaml           # Cluster namespace definition
│       ├── ingress.yaml             # Cluster-level L7 routing (standalone)
│       ├── job.yaml                 # One-off database migration job
│       ├── cronjob.yaml             # Recurring scheduled task
│       ├── config/
│       │   ├── backend-config.yaml  # Non-sensitive ConfigMap (DB_HOST, DB_PORT, etc.)
│       │   └── secrets.yaml         # Database credentials (use Vault/Sealed Secrets in prod)
│       ├── helm/
│       │   ├── nginx/               # Bitnami Nginx chart values (frontend)
│       │   ├── postgres/            # Bitnami PostgreSQL chart values (database)
│       │   └── backend/             # Custom Helm chart for Flask backend
│       │       ├── Chart.yaml
│       │       ├── values.yaml
│       │       └── templates/
│       │           ├── deployment.yaml
│       │           ├── service.yaml
│       │           └── hpa.yaml
│       └── deploy.sh                # Bootstrap script (first-time cluster setup only)
├── monitoring/                      # Prometheus & Grafana configs
├── docker-compose.yml               # Local development environment
└── .env.example                     # Required environment variable reference
```

---

## 🚀 Option A: Local Development (Docker Compose)

The fastest way to run the full stack locally.

### Prerequisites
- [Docker Engine](https://docs.docker.com/engine/install/) & Docker Compose plugin

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/Halan-Internship-Project.git
cd Halan-Internship-Project

# 2. Set up your local environment variables
cp .env.example .env
# Edit .env and set a password for POSTGRES_PASSWORD

# 3. Launch the full 3-tier stack
docker compose up -d --build

# 4. Verify all services are healthy
docker compose ps

# 5. Test the application
curl http://127.0.0.1:4000/api/name
```

**Expected output:**
```json
{
  "name": "Mohamed",
  "source": "PostgreSQL Database",
  "status": "success"
}
```

---

## ☸️ Option B: Kubernetes Cluster Setup (Minikube + Helm)

This is the full production-like setup. Follow these steps in order.

### Prerequisites

| Tool | Version | Install |
|:-----|:--------|:--------|
| [minikube](https://minikube.sigs.k8s.io/docs/start/) | v1.38+ | See link |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | v1.36+ | See link |
| [Helm](https://helm.sh/docs/intro/install/) | v3+ | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \| bash` |

---

### Step 1 — Start the Cluster

```bash
minikube start --driver=docker --cpus=4 --memory=6144
minikube status   # All components should show "Running"
```

---

### Step 2 — Enable Required Addons

```bash
# Ingress controller (routes external traffic into the cluster)
minikube addons enable ingress

# Metrics server (required for HPA to measure CPU)
minikube addons enable metrics-server

# Verify the ingress controller is running
kubectl get pods -n ingress-nginx
```

---

### Step 3 — Add Helm Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

---

### Step 4 — Bootstrap the Cluster

Run the bootstrap script from the `infra/k8s/` directory. This is the **only time** you run this script. After ArgoCD is set up, it takes over all deployments.

```bash
cd infra/k8s/

# Apply the namespace first — everything else lives inside it
kubectl apply -f namespace.yaml

# Apply ConfigMaps and Secrets (database credentials & app config)
kubectl apply -f config/

# Deploy PostgreSQL (Primary + Read Replica via StatefulSet)
helm upgrade --install halan-db helm/postgres/postgresql-18.8.12.tgz \
  -f helm/postgres/postgres-values.yaml -n halan

# Deploy Nginx frontend
helm upgrade --install halan-nginx helm/nginx/nginx-25.0.21.tgz \
  -f helm/nginx/nginx-values.yaml -n halan

# Deploy the Flask backend (custom Helm chart)
helm upgrade --install halan-backend helm/backend/ \
  -f helm/backend/values.yaml -n halan

# Apply cluster-level routing
kubectl apply -f ingress.yaml

# Apply batch jobs
kubectl apply -f job.yaml
kubectl apply -f cronjob.yaml
```

---

### Step 5 — Verify Everything is Running

```bash
# Check all resources in the halan namespace
kubectl get all -n halan

# All pods should be in Running state (may take 1-2 minutes for DB)
# You should see:
# - halan-backend pods (Deployment, 2-6 replicas via HPA)
# - halan-nginx pods (Deployment, 2-5 replicas via Helm HPA)
# - halan-db-postgresql-0 (StatefulSet primary)
# - halan-db-postgresql-read-0 (StatefulSet read replica)
```

---

### Step 6 — Access the Application

```bash
# Get the Minikube cluster IP
export MINIKUBE_IP=$(minikube ip)

# Test the frontend directly via IP (Catch-all Ingress)
curl -I http://$MINIKUBE_IP

# Test the backend API through Nginx reverse proxy
curl http://$MINIKUBE_IP/api/name
```

---

### Step 7 — Set Up ArgoCD (GitOps)

After the initial bootstrap, ArgoCD takes over all future deployments.

```bash
# Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --create-namespace --namespace argocd

# Wait for all ArgoCD pods to be Running
kubectl get pods -n argocd -w

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Access the ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (accept the self-signed cert warning)
# Username: admin | Password: from the command above
```

Once logged in, connect this GitHub repository to ArgoCD and apply the ArgoCD Application manifest to enable fully automated GitOps deployments.

---

## 🔑 Key Architectural Decisions

| Decision | Rationale |
|:---------|:----------|
| **Nginx & PostgreSQL via Bitnami Helm** | Battle-tested charts handle StatefulSets, PVCs, and replication correctly |
| **Backend via Custom Helm Chart** | Gives full control over templates while maintaining Helm release management |
| **Ingress is standalone (not inside any chart)** | Ingress is cluster-level routing — it must grow independently as new services are added |
| **HPA inside the backend chart** | HPA is tightly coupled to the backend Deployment's lifecycle; if you delete the backend, the HPA should go with it |
| **Jobs & CronJobs are standalone** | Decoupled from service lifecycle; a DB migration shouldn't be deleted when you redeploy the backend |
| **Secrets in `config/secrets.yaml`** | For learning only — in production, use HashiCorp Vault or Sealed Secrets |

---

## ⚙️ Environment Configuration

| Variable | Description | Example |
|:---------|:------------|:--------|
| `POSTGRES_DB` | Database schema name | `halandb` |
| `POSTGRES_USER` | Database user | `pguser` |
| `POSTGRES_PASSWORD` | Database password | `your_secure_password` |
| `DB_PORT` | PostgreSQL port | `5432` |

---

## 🗺️ Engineering Roadmap

- [x] **Phase 1**: Docker containerization & non-root security baseline
- [x] **Phase 2**: Docker Compose orchestration with persistent storage
- [x] **Phase 3**: Monorepo restructuring & CI/CD with GitHub Actions
- [x] **Phase 4**: Nginx reverse proxy & presentation tier
- [x] **Phase 5**: Kubernetes migration (Namespace, Deployments, Services, Ingress)
- [x] **Phase 6**: Helm charts (Nginx, PostgreSQL, custom Backend chart)
- [x] **Phase 7**: Resource requests & limits (CPU/Memory QoS)
- [x] **Phase 8**: Horizontal Pod Autoscaler (HPA)
- [x] **Phase 9**: Kubernetes Secrets & ConfigMaps
- [x] **Phase 10**: Persistent Volumes (PostgreSQL StatefulSet + PVC)
- [x] **Phase 11**: Jobs & CronJobs
- [x] **Phase 12**: Ingress (L7 routing)
- [ ] **Phase 13**: ArgoCD (GitOps continuous delivery)
- [ ] **Phase 14**: ELK Stack (centralized logging)
- [ ] **Phase 15**: Service Mesh (Linkerd + distributed tracing)
- [ ] **Phase 16**: Prometheus & Grafana observability