# Kubernetes Core Architecture

This document covers the core Kubernetes resources deployed in the Halan Internship Project.

## 🏛️ General Overview

The system is deployed entirely within the `halan` namespace, leveraging Kubernetes to orchestrate a 3-tier microservices architecture consisting of a Nginx frontend, a Python Flask backend, and a PostgreSQL database.

All traffic is routed through a single cluster-level Nginx Ingress Controller.

## 🔑 Core Concepts & Design Decisions

### Namespaces
All application resources live in the `halan` namespace (defined in `infra/k8s/namespace.yaml`). This provides logical isolation, easier cleanup, and allows for namespace-scoped resource quotas and RBAC if needed in the future.

### Ingress & Routing
- **File:** `infra/k8s/ingress.yaml`
- **Controller:** RKE2's default Nginx Ingress Controller
- **Strategy:** We use a single Ingress resource to route all traffic. The Ingress object replaces traditional `nginx.conf` reverse proxy logic by instructing the cluster's ingress controller to map routes dynamically:
  - `/*` routes to the `halan-nginx` frontend service on port 80.
  - `/api/*` routes to the `halan-backend` service on port 5000.

### Workloads: Deployments vs StatefulSets
- **Backend & Frontend (Deployments):** Both the Nginx frontend and Flask backend are deployed as Kubernetes `Deployments` (managed via Helm). Deployments are ideal for stateless applications. They support zero-downtime rolling updates and Horizontal Pod Autoscaling (HPA).
- **PostgreSQL (StatefulSet):** The database requires stable, persistent state. A `StatefulSet` provides unique network identities (`halan-db-postgresql-0`), ordered pod creation/deletion, and stable persistent storage attachments.

### Persistent Volume Claims (PVC) & Storage
- **Storage Class:** `longhorn`
- **Why Longhorn?** Kubernetes doesn't provide a default block storage out of the box for bare-metal or generic VMs. Longhorn is deployed to the cluster to provide distributed, replicated block storage.
- **Usage:** 
  - PostgreSQL uses a PVC to persist `/bitnami/postgresql/data`.
  - The daily backup CronJob (`db-backup-pvc.yaml`) uses a 5Gi `ReadWriteOnce` PVC to store `pg_dump` backups. `ReadWriteOnce` is sufficient as only one backup job pod writes to it at a time.

### Jobs & CronJobs
- **One-off Jobs:** The database seed process (`db-seed`) runs as a single-execution Kubernetes Job. Instead of running manually, it is triggered by an ArgoCD PostSync hook (detailed in `argocd.md`).
- **CronJobs:** We run a daily PostgreSQL backup using a Kubernetes `CronJob` (`infra/k8s/cronjob.yaml`). This spins up a pod at 02:00 UTC every day, executes `pg_dump`, gzips the output, saves it to the Longhorn PVC, and automatically prunes backups older than 7 days. It uses `restartPolicy: OnFailure` to automatically retry the backup if the pod dies mid-execution.

## 🌐 Internal Service Discovery
No IP addresses are hardcoded in the application. Microservices locate each other using Kubernetes CoreDNS:
- The Frontend resolves the backend via the `halan-backend` service name.
- The Backend connects to the database via `halan-db-postgresql-primary:5432`.

## 🛡️ Health Probes
We heavily utilize Kubernetes Liveness and Readiness probes (specifically in the backend Helm chart):
- **Liveness Probes:** Restart a pod if it gets stuck (e.g., deadlocks in Flask).
- **Readiness Probes:** Temporarily remove a pod from the Service load balancer if it's too busy or starting up, ensuring users don't hit unready pods.
