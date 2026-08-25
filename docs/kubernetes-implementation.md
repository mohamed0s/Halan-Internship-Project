# Kubernetes Implementation — Architecture & Runbook

This document captures the complete Kubernetes deployment architecture for the Halan Internship Project, reflecting the actual current state of `infra/k8s/`.

---

## 🏛️ Architecture Overview

The system runs in the `halan` namespace across a 3-tier microservices architecture. All external traffic enters through a single Nginx Ingress Controller and flows down to the appropriate backend services.

```mermaid
graph TD
    User([Internet / User])
    Ingress[Nginx Ingress Controller<br/>Cluster-Level L7 Routing]

    subgraph K8s Cluster [Kubernetes Cluster]
        subgraph NS [Namespace: halan]
            SvcNginx[Service: halan-nginx<br/>ClusterIP: 80]
            PodNginx[Pods: halan-nginx<br/>Port: 8080<br/>2–5 Replicas via HPA]

            SvcBackend[Service: halan-backend<br/>ClusterIP: 5000]
            PodBackend[Pods: halan-backend<br/>Port: 5000<br/>2–6 Replicas via HPA]

            SvcDB[Service: halan-db-postgresql-primary<br/>ClusterIP: 5432]
            PodDB[(StatefulSet: halan-db-postgresql-0<br/>Primary + Read Replica)]
        end
    end

    User -->|HTTP| Ingress
    Ingress -->|path: /| SvcNginx
    SvcNginx --> PodNginx
    PodNginx -->|Reverse Proxy /api/| SvcBackend
    SvcBackend --> PodBackend
    PodBackend -->|Reads/Writes| SvcDB
    SvcDB --> PodDB
```

---

## 📦 Component Breakdown

### 1. Frontend — Nginx
- **Deployment method:** Bitnami `bitnami/nginx` Helm chart
- **Chart values:** `infra/k8s/helm/nginx/nginx-values.yaml`
- **Key config:**
  - Runs non-root on port `8080` internally
  - Custom `serverBlock` in values configures Nginx as a reverse proxy: all `/api/` requests are forwarded to `halan-backend:5000`
  - HPA managed directly via Helm values (`autoscaling.enabled: true`)
  - Exposed internally via ClusterIP Service

### 2. Backend — Python Flask
- **Deployment method:** Custom Helm chart at `infra/k8s/helm/backend/`
- **Chart structure:**
  ```text
  helm/backend/
  ├── Chart.yaml          ← Chart identity & version
  ├── values.yaml         ← All configurable parameters
  └── templates/
      ├── deployment.yaml ← Pod spec with health probes & resource limits
      ├── service.yaml    ← ClusterIP Service to expose the backend
      └── hpa.yaml        ← HPA (conditional on autoscaling.enabled)
  ```
- **Configuration injection:**
  - Non-sensitive env vars (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`) loaded from `ConfigMap: backend-config`
  - Database password loaded from `Secret: halan-db-secret`
- **Health probes:**
  - `livenessProbe` — polls `GET /health` every 20s; restarts pod after 3 failures
  - `readinessProbe` — polls `GET /health` every 10s; removes pod from Service endpoints after 3 failures
- **Resource management:**
  - Requests: `100m CPU`, `128Mi RAM`
  - Limits: `250m CPU`, `256Mi RAM`
- **HPA:** Scales between 2 and 6 replicas when average CPU exceeds 50% of requests

### 3. Database — PostgreSQL
- **Deployment method:** Bitnami `bitnami/postgresql` Helm chart
- **Chart values:** `infra/k8s/helm/postgres/postgres-values.yaml`
- **Architecture:** `replication` mode — 1 Primary StatefulSet pod + 2 Read Replica pods
- **Storage:** PVC backed by `longhorn` StorageClass (use `standard` on Minikube)
- **Credentials:** Pulled from pre-existing Secret `halan-db-secret`
- **Why StatefulSet?** Each pod gets a stable DNS name (`halan-db-postgresql-primary-0`), its own PVC that survives restarts, and ordered startup/shutdown for safe replica election.

---

## ⚙️ Standalone Cluster Resources

These resources are **not** managed by any Helm chart because their lifecycle is independent of any single service.

| File | Resource | Managed by ArgoCD? | Reason |
|:-----|:---------|:-------------------|:-------|
| `namespace.yaml` | Namespace `halan` | ✅ `halan-infra` | Bootstrap resource — must exist before everything else |
| `config/backend-config.yaml` | ConfigMap | ❌ Bootstrap only | Shared app config — applied once via `bootstrap.sh` |
| `config/secrets.yaml` | Secret | ❌ Bootstrap only | Sensitive credentials — human-managed (use Vault/Sealed Secrets in prod) |
| `ingress.yaml` | Ingress | ✅ `halan-infra` | Cluster-level routing — grows independently as new services are added |
| `job.yaml` | Job | ❌ Excluded | One-off DB migration — excluded from ArgoCD via `directory.exclude` to avoid `Degraded` state after completion |
| `cronjob.yaml` | CronJob | ✅ `halan-infra` | Recurring schedule — long-lived resource, safe for ArgoCD to reconcile |

---

## 🔀 ArgoCD Application Summary

All releases are managed by ArgoCD via `infra/k8s/argocd/`. These files are applied once during bootstrap; after that ArgoCD takes full control.

| ArgoCD App | Chart Source | Chart | Values File | Namespace |
|:-----------|:------------|:------|:------------|:----------|
| `halan-nginx` | Bitnami (remote) | `bitnami/nginx@25.0.21` | `helm/nginx/nginx-values.yaml` | `halan` |
| `halan-postgres` | Bitnami (remote) | `bitnami/postgresql@18.8.12` | `helm/postgres/postgres-values.yaml` | `halan` |
| `halan-backend` | Git (local) | `helm/backend/` (custom) | `helm/backend/values.yaml` | `halan` |
| `halan-infra` | Git (local) | Raw YAML directory | `infra/k8s/` | `halan` |

> **Multi-source Apps**: `halan-nginx` and `halan-postgres` use the ArgoCD [multi-source pattern](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/) — chart from Bitnami, values from this Git repo.

---

## 🌐 Internal Service Discovery (CoreDNS)

No IP addresses are hardcoded anywhere. All inter-service communication uses Kubernetes DNS:

| From | To | DNS Name |
|:-----|:---|:---------|
| Nginx pod | Flask backend | `http://halan-backend:5000` |
| Flask pod | PostgreSQL | `halan-db-postgresql-primary:5432` |

---

## ♻️ GitOps with ArgoCD (Phase 13)

ArgoCD runs in the `argocd` namespace and continuously reconciles the cluster state with this Git repository using an **App of Apps** pattern — one `Application` resource per service, each defined in `infra/k8s/argocd/`.

**Self-healing behavior:** If someone manually runs `kubectl edit` or `kubectl scale`, ArgoCD detects the **drift** between Git (source of truth) and the cluster, and automatically reverts the change within minutes.

**Full GitOps loop:**
```
Developer pushes code to main
       ↓
GitHub Actions (CI)
  - Builds Docker image, scans with Trivy, pushes to DockerHub
  - Updates image tag (sha-XXXXXXX) in Helm values file
  - Commits & pushes values.yaml back to Git [skip ci]
       ↓
ArgoCD detects values.yaml change (~3 min polling)
  - Re-renders Helm templates with new image tag
  - Applies rolling update to the cluster
  - Monitors rollout; reverts on failure (selfHeal: true)
       ↓
Zero-downtime deployment complete
```

### Bootstrap Procedure (One-time only)

```bash
# 1. Apply namespace, ConfigMaps, and Secrets
kubectl apply -f infra/k8s/namespace.yaml
kubectl apply -f infra/k8s/config/
kubectl apply -f infra/k8s/job.yaml  # One-shot DB migration

# 2. Hand over control to ArgoCD (never touch kubectl for deployments again)
kubectl apply -f infra/k8s/argocd/
```

> `infra/k8s/bootstrap.sh` automates the above. It is the **only** time you run deployment commands manually.

---

## 🔒 Security Notes

| Topic | Current Approach | Production Recommendation |
|:------|:----------------|:--------------------------|
| Database credentials | `config/secrets.yaml` (plaintext in Git) | HashiCorp Vault or Bitnami Sealed Secrets |
| Container privileges | Non-root user (`appuser`) in Docker image | ✅ Already production-ready |
| Network isolation | All services on `ClusterIP` — only Ingress is externally reachable | ✅ Already production-ready |
| TLS termination | Not yet configured | Add cert-manager + Let's Encrypt Ingress annotations |
