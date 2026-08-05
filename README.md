# Halan Internship Project

A lightweight, containerized Python microservice designed for scalable cloud deployment. This repository contains the core application backend, container specifications, and security policies.

---

## 🏗️ System Architecture

- **Runtime**: Python 3.11 (WSGI Web Service)
- **Framework**: Flask
- **Container Base**: `python:3.11-slim` (Debian-based minimal userspace)
- **Security Profile**: Non-root container process execution (`appuser:appgroup`)
- **Default Port**: `5000` (Configurable via `PORT` environment variable)

---

## 🚀 Quickstart Guide

### Prerequisites
- [Docker Engine](https://docs.docker.com/engine/install/) 20.10+ installed on host Linux/EC2.

### 1. Build Container Image
```bash
docker build -t halan-app:v1 .
```

### 2. Run Application Container
```bash
docker run -d --name halan-web -p 5000:5000 halan-app:v1
```

### 3. Verify Service Health
```bash
curl http://127.0.0.1:5000
```

---

## ⚙️ Environment Configuration

| Variable | Description | Default |
| :--- | :--- | :--- |
| `PORT` | Network port for the application server | `5000` |
| `PYTHONDONTWRITEBYTECODE` | Prevents Python from writing `.pyc` files to disk | `1` |
| `PYTHONUNBUFFERED` | Flushes stdout/stderr logs immediately to Docker stream | `1` |

---

## 🔒 Security & Container Standards

- **Least Privilege Execution**: The application process drops root privileges during image compilation and executes under an unprivileged system user (`appuser`).
- **Layer Optimization**: Dependency installations use `--no-cache-dir` to minimize filesystem layer size and reduce attack surface area.
- **Context Exclusion**: Build artifacts, virtual environments, and local metadata are excluded via `.dockerignore` and `.gitignore`.

---

## 🗺️ Project Roadmap

- [x] **Phase 1**: Core Web Server Containerization & Security Baseline
- [ ] **Phase 2**: Database Integration & Data Persistence
- [ ] **Phase 3**: Multi-Container Orchestration (Docker Compose)
- [ ] **Phase 4**: CI/CD Automation & Cloud Deployment