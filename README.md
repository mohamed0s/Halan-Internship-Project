# Halan Internship Project

A scalable, cloud-native enterprise application engineered with a 3-tier modular microservices architecture. Designed for automated CI/CD deployment, declarative infrastructure provisioning (Terraform/Kubernetes), and real-time operational observability.

---

## 🏗️ Repository Hierarchy & Structure

```text
halan-internship-project/
├── .github/
│   └── workflows/            # CI/CD Automation pipelines (GitHub Actions / ArgoCD triggers)
├── docs/                     # Dedicated technical specifications & architectural runbooks
│   ├── architecture.md       # Core system architecture runbook
│   └── setup-guide.md
├── frontend/                 # Presentation Tier (Nginx Web Server / Glassmorphic UI / Reverse Proxy)
│   ├── src/
│   │   ├── index.html
│   │   └── styles.css
│   ├── Dockerfile
│   └── nginx.conf
├── backend/                  # Application Tier (Python Flask REST API / Business Logic)
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
├── db/                       # Database Tier (SQL Migration & Seed Initialization Scripts)
│   └── init/
│       └── 01-init.sql
├── infra/                    # Infrastructure as Code (IaC) & Cloud Provisioning
│   ├── terraform/            # AWS VPC, RDS, EKS cluster terraform configuration
│   └── k8s/                  # Declarative Kubernetes Manifests (Deployments, Services, Ingress, Secrets)
├── monitoring/               # Observability Tier
│   ├── prometheus/           # Metrics data scraping configs
│   └── grafana/              # System visualization dashboard definitions
├── docker-compose.yml        # Orchestration root manifest for Local Integration / Dev stacks
├── .env                      # Local runtime environment secrets (Ignored in Git)
├── .env.example              # Safe reference placeholder mapping required environmental variables
├── .gitignore
└── README.md                 # Living repository architecture overview
```

---

## 🚀 Quickstart Guide (Declarative Deployment)

### Prerequisites
- [Docker Engine](https://docs.docker.com/engine/install/) & Docker Compose plugin installed.
- Copy `.env.example` to `.env` and assign your custom local secure passwords:
  ```bash
  cp .env.example .env
  ```

### 1. Launch 3-Tier Enterprise Infrastructure
Execute a single declarative command to initialize networks, build application services, attach persistent storage, and seed initial database tables:
```bash
docker compose up -d --build
```

### 2. Verify Service Health & Readiness
Check Docker Compose readiness probes across database and backend tiers:
```bash
docker compose ps
```

### 3. Verify System Endpoints

#### Test Frontend UI (Nginx - Port 4000)
Open your browser to `http://localhost:4000` or test via CLI:
```bash
curl -I http://127.0.0.1:4000
```

#### Test End-to-End API Integration (Nginx Reverse Proxy -> Flask -> Postgres)
```bash
curl http://127.0.0.1:4000/api/name
```
*Expected Output*:
```json
{
  "name": "Mohamed",
  "source": "PostgreSQL Database",
  "status": "success"
}
```

---

## ⚙️ Environment Configuration (`.env`)

| Variable | Description | Example Value |
| :--- | :--- | :--- |
| `POSTGRES_DB` | Database schema name | `halandb` |
| `POSTGRES_USER` | Admin database user account | `pguser` |
| `POSTGRES_PASSWORD` | Cryptographic database password | `super_secret_password` |
| `DB_PORT` | PostgreSQL listening port | `5432` |

---

## 🔒 Security & Cloud Native Standards

- **Nginx Reverse Proxy & Port Isolation**: Public access is strictly restricted to Port 4000. Backend Python (`5000`) and Database (`5432`) ports are isolated inside the internal `halan-net` bridge network and hidden from public exposure.
- **Least Privilege Execution**: The backend Python process drops root privileges during Docker image compilation and executes strictly under an unprivileged system user (`appuser`).
- **Automated Health Probes**: Docker Compose startup sequencing enforces `condition: service_healthy` utilizing active `pg_isready` socket polling before initiating dependent backend applications.
- **Layer & Build Optimization**: Application binaries reside inside dedicated subdirectory contexts (`backend/` and `frontend/`), shielding container daemon transfers from unneeded workspace files.
- **Secrets Decoupling**: Sensitive runtime variables are dynamically evaluated via `.env` interpolation and shielded via `.gitignore` and `.dockerignore`.

---

## 🗺️ Engineering Roadmap

- [x] **Phase 1**: Core Web Server Containerization & Non-Root Security Baseline
- [x] **Phase 2**: Declarative Database Orchestration & Volume Persistence
- [x] **Phase 3**: Monorepo Modular Restructuring (Enterprise Cloud-Native Topology)
- [x] **Phase 4**: Dedicated Presentation Tier & Nginx Reverse Proxying
- [ ] **Phase 5**: Terraform Cloud Provisioning & Kubernetes Cluster Integration
- [ ] **Phase 6**: Prometheus & Grafana Telemetry Observability Integration