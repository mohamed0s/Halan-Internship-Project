# ArgoCD & GitOps

This document outlines how ArgoCD manages continuous deployment (CD) for the Halan Internship Project using GitOps principles.

## 🔄 The GitOps Philosophy

Instead of manually running `kubectl apply` or `helm upgrade`, we treat this Git repository as the **single source of truth** for the desired state of the cluster.

ArgoCD continuously monitors the `main` branch. If the actual state in the Kubernetes cluster diverges from the Git repository (due to a commit, or if someone manually modifies a resource via `kubectl`), ArgoCD detects the **drift** and automatically reconciles the cluster to match Git.

## 🚀 The Deployment Loop
1. A developer pushes code, or GitHub Actions finishes building a new Docker image.
2. The CI pipeline updates the image tag in the specific Helm `values.yaml` file and automatically pushes a commit back to Git (with `[skip ci]`).
3. ArgoCD polls the repository (every ~3 minutes) and detects the updated `values.yaml`.
4. ArgoCD re-renders the Helm templates and applies a rolling update to the cluster, resulting in a zero-downtime deployment.

## 🗂️ Multiple Independent Applications

All services are managed declaratively with ArgoCD. Instead of configuring applications manually in the ArgoCD UI, we define individual ArgoCD `Application` YAML files (one per service) in `infra/k8s/argocd/`. These are applied once to the cluster with `kubectl apply -f argocd/`, and ArgoCD takes over from there.

**This is NOT the App of Apps pattern.** In App of Apps, a single parent `Application` watches a directory of other `Application` YAMLs and applies them for you. Here, we apply the `Application` manifests directly — each is an independent, peer-level application managed by ArgoCD.

### Application Manifest Inventory
- **`longhorn.yaml`**: Deploys Longhorn storage (wave 1). Must be ready before anything that needs PVCs.
- **`istio-base.yaml`** and **`istiod.yaml`**: Deploy Istio CRDs and control plane (wave 1).
- **`halan-postgres.yaml`**: Deploys the PostgreSQL database (wave 3).
- **`halan-backend.yaml`**: Deploys the custom Flask backend Helm chart (wave 3).
- **`halan-nginx.yaml`**: Deploys the Nginx frontend (wave 3).
- **`halan-infra.yaml`**: Deploys raw Kubernetes manifests from `infra/k8s/` — namespace, ingress, cronjobs, PVCs (wave 3).
- **`halan-db-seed.yaml`**: Manages the database seeding process (PostSync hook, wave 3).
- **Observability Apps**: `elasticsearch.yaml`, `kibana.yaml`, `kube-prometheus.yaml`, `fluent-bit.yaml` (waves 4–5).
- **Mesh Observability**: `kiali.yaml` — service mesh dashboard.

## 🌊 Sync Waves

Order of deployment matters. You cannot deploy the backend API before the database is ready. ArgoCD solves this using **Sync Waves**. 

We annotate our `Application` resources with `argocd.argoproj.io/sync-wave`. ArgoCD deploys lower waves first and waits for them to become "Healthy" before moving to the next wave.

- **Wave 1**: Storage & Service Mesh infrastructure (Longhorn, Istio base CRDs, Istiod control plane)
- **Wave 3**: Application services (PostgreSQL, Backend, Nginx, Infra manifests, DB seed)
- **Wave 4 & 5**: Observability components (ELK, Prometheus)

## 🪝 PostSync Hooks (`db-seed`)

Database migrations and seeding require special handling. A Kubernetes `Job` typically runs to completion and stays in the cluster. If ArgoCD tracks it normally, it might try to continuously reconcile or re-create it, causing conflicts.

In `halan-db-seed.yaml` and its associated Helm chart, we use ArgoCD Hooks:
```yaml
annotations:
  argocd.argoproj.io/hook: PostSync
  argocd.argoproj.io/hook-delete-policy: HookSucceeded
```
- **`PostSync`**: Tells ArgoCD to run this Job *only once* after the main sync (wave) has completed successfully.
- **`HookSucceeded`**: Tells ArgoCD to automatically delete the Job resource from the cluster once it finishes successfully, keeping the cluster clean.

## 🔀 Multi-Source Applications

For third-party tools like ELK and Prometheus, we use ArgoCD's **Multi-Source** feature. 
This allows us to pull the *Helm Chart* directly from the official upstream repository (e.g., `https://helm.elastic.co`), but pull the *`values.yaml` configuration file* from our own Git repository.

Example from `elasticsearch.yaml`:
```yaml
sources:
  - repoURL: https://helm.elastic.co
    chart: elasticsearch
    targetRevision: "8.5.1"
    helm:
      valueFiles:
        - $values/infra/k8s/helm/elasticsearch/elasticsearch-values.yaml
  - repoURL: https://github.com/mohamed0s/Halan-Internship-Project
    targetRevision: HEAD
    ref: values # This creates the $values reference used above
```


## 🙈 Ignoring Differences (ignoreDifferences)

Sometimes, Kubernetes controllers (like Istio) mutate resources after they are deployed, injecting fields that aren't in our Git repository. This causes ArgoCD to constantly show the application as "OutOfSync".

To fix this, we use the `ignoreDifferences` configuration in our ArgoCD `Application` manifest. For example, to prevent sync issues with Istio's ValidatingWebhookConfiguration, we tell ArgoCD to ignore the `failurePolicy` field which Istio automatically manages:

```yaml
spec:
  ignoreDifferences:
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      name: istiod-default-validator
      jsonPointers:
        - /webhooks/0/failurePolicy
```
