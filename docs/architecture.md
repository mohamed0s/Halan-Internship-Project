# Halan Internship Project - System Architecture & Runbook

## Core Architecture
This project is engineered as a cloud-native, 3-tier enterprise application modularized for container orchestration, declarative infrastructure provisioning, and observability.

### Tier 1: Presentation Tier (`frontend/`)
- **Web Server**: Nginx (Alpine Linux distribution footprint)
- **UI Stack**: Glassmorphic HTML/CSS interface with responsive status monitoring across all 3 tiers.
- **Reverse Proxy**: Listens on public Port `4000` mapped internally to container Port `80`. Proxy-passes all `/api/` path traffic directly to the internal backend container `http://webapp:5000/api/` over the `halan-net` private bridge network, solving CORS and enforcing port security.

### Tier 2: Backend Microservice (`backend/`)
- **Runtime**: Python 3.11 (WSGI Flask Web Application)
- **REST API**: Serves JSON endpoints (`/api/name`) queried dynamically from PostgreSQL.
- **Container Strategy**: Multi-layer built image from `python:3.11-slim`, dropping administrative privileges immediately after dependency resolution to run under unprivileged user `appuser`.

### Tier 3: Data Persistence (`db/`)
- **Engine**: PostgreSQL 15 (Alpine Linux footprint)
- **State Management**: Docker Named Volume (`halan_pg_data`) mapped to `/var/lib/postgresql/data`.
- **Declarative Initialization**: SQL scripts placed in `db/init/` are evaluated alphabetically (`01-init.sql`) on initial schema creation via `/docker-entrypoint-initdb.d/`.

---

## Network Topology & Communication Flow

```
[ Client Browser ] ---> (Public Port 4000) ---> [ Nginx (frontend:80) ]
                                                       |
                                        (Internal Docker Bridge: halan-net)
                                                       |
                                                       v
                                                [ Flask (webapp:5000) ]
                                                       |
                                        (Internal Docker Bridge: halan-net)
                                                       |
                                                       v
                                                [ Postgres (db:5432) ] <---> [ Volume: halan_pg_data ]
```

---

## Infrastructure as Code & DevOps Readiness
- **Terraform (`infra/terraform/`)**: Configured for declarative infrastructure deployment across AWS target topologies (VPC, EKS, RDS).
- **Kubernetes Manifests (`infra/k8s/`)**: Target deployment definitions for Kubernetes ConfigMaps, Secrets, Services, and Horizontal Pod Autoscalers.
- **Observability (`monitoring/`)**: Prometheus metric scraping integration and Grafana visual dashboard definitions.
