# Helm Package Management

This document explains how Helm is utilized in the Halan Internship Project to manage complex Kubernetes deployments, standardize configuration, and orchestrate third-party applications.

## 📦 Why Helm?
Helm acts as a package manager for Kubernetes. Instead of writing dozens of hardcoded YAML files, Helm allows us to:
- Define templates for Kubernetes resources.
- Inject configuration dynamically via `values.yaml` files.
- Group related resources (like a Deployment, Service, and HPA) into a single logical "Release".
- Easily install, upgrade, and rollback applications.

## 🏗️ Chart Structure in this Project

All Helm-related files are located under `infra/k8s/helm/`. We employ two primary strategies: Custom Charts and Upstream Chart Overrides.

### 1. Custom Charts (`backend/` and `db-seed/`)
We built custom Helm charts for resources that require specific, tailored logic.

**Backend Chart (`helm/backend/`):**
- Provides full control over the Flask API deployment.
- Contains templates for a Deployment, Service, and an optional Horizontal Pod Autoscaler (HPA).
- Environment variables (like DB host/port) and secrets are dynamically injected from Kubernetes ConfigMaps and Secrets referenced in `values.yaml`.
- The CI/CD pipeline dynamically updates the `image.tag` value in this chart's `values.yaml` during automated deployments.

**DB Seed Chart (`helm/db-seed/`):**
- Replaces raw, duplicated `job.yaml` and `configmap.yaml` files.
- Acts as a single source of truth for the database initialization process.
- Uses Helm's `.Files.Get` function to dynamically read the canonical SQL script (`db/init/01-init.sql` via a symlink) and inject it directly into a ConfigMap template.
- Applies ArgoCD PostSync hooks to ensure the Job runs exactly when needed.

### 2. Upstream Chart Overrides
For complex, battle-tested infrastructure components, we rely on official upstream charts rather than reinventing the wheel. We maintain custom `values.yaml` files to override default settings to suit our environment.

- **Nginx (`helm/nginx/`):** We override the Bitnami Nginx chart to run as a non-root user (port 8080) and inject a custom `serverBlock` that configures it as a reverse proxy, routing `/api/` traffic to the backend service.
- **PostgreSQL (`helm/postgres/`):** We override the Bitnami PostgreSQL chart to enable replication (1 primary, 2 read replicas) and configure Longhorn PVCs.
- **ELK & Prometheus:** We previously used Bitnami charts but migrated to the official upstream charts (`elastic/*` and `prometheus-community/*`) after Bitnami removed their images from Docker Hub. Our custom values files (`elasticsearch-values.yaml`, `kibana-values.yaml`, `kube-prometheus-values.yaml`) heavily modify these charts to adjust resource limits, disable unnecessary sub-charts, and configure ingress.

## 🛠️ Typical Helm Workflow (Local Testing)
While ArgoCD handles actual deployments (see `argocd.md`), you can use Helm locally to debug templates.

To see what YAML Helm *would* generate without actually applying it:
```bash
# Navigate to the chart directory
cd infra/k8s/helm/backend/

# Run a template dry-run
helm template my-release . -f values.yaml
```
This is an invaluable tool for troubleshooting template syntax errors or verifying that values are injected correctly.
