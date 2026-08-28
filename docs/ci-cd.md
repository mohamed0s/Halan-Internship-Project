# CI/CD Pipeline (GitHub Actions)

This document explains the Continuous Integration (CI) side of our deployment pipeline. 

It is important to remember that **GitHub Actions does not deploy to Kubernetes directly.** It only builds images, scans them, and writes the new image tag back to Git. ArgoCD (our CD tool) takes over from there (see `argocd.md`).

## ⚙️ The Pipeline Workflow

The pipeline is defined in `.github/workflows/docker-image.yml`. It runs automatically whenever code is pushed to the `main` branch.

### 1. Change Detection (`dorny/paths-filter`)
Building Docker images is slow and expensive. The very first step of the pipeline analyzes the Git commit to see exactly which files changed.
- If only backend Python files changed, it sets an output flag `backend = true`.
- If only frontend HTML/CSS changed, it sets `frontend = true`.

The downstream build jobs read these flags. If the backend didn't change, the backend build job skips entirely, saving significant time.

### 2. Building Images (Docker Buildx)
If a service needs building, the pipeline uses **Docker Buildx**.
It extracts metadata (like the Git commit SHA) and uses it to tag the Docker image. 
For example, if the Git commit is `a1b2c3d`, the resulting image will be tagged `mohamed0s/halan-backend:sha-a1b2c3d`.

### 3. Security Scanning (Trivy)
Before pushing the image anywhere, the pipeline runs **Trivy**, an open-source vulnerability scanner. Trivy inspects the Docker image for known OS-level or library-level vulnerabilities (CVEs) and will fail the build if `CRITICAL` or `HIGH` vulnerabilities are found.

### 4. Pushing to Docker Hub
If the scan passes, the image is pushed to Docker Hub using the `DOCKER_USERNAME` and `DOCKERHUB_TOKEN` secrets stored in GitHub.

### 5. The GitOps Trigger (Updating values.yaml)
This is the most critical step bridging CI and CD.

Once the new image (`sha-a1b2c3d`) is pushed to Docker Hub, the Kubernetes cluster needs to know about it.
The pipeline runs a `sed` command to find and replace the image tag in the application's Helm `values.yaml` file:

```bash
# It replaces the old tag with the new sha-a1b2c3d
sed -i "s/tag: .*/tag: sha-a1b2c3d/g" infra/k8s/helm/backend/values.yaml
```

Finally, the pipeline uses the `GITHUB_TOKEN` to **commit and push** this changed `values.yaml` file straight back to the `main` branch. 
It uses `[skip ci]` in the commit message so that this automated push doesn't accidentally trigger a second pipeline run.

Once this commit hits the `main` branch, ArgoCD detects it and applies the update to the cluster.
