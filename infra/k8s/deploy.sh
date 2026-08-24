#!/bin/bash
set -e

echo "🚀 Starting Bootstrap Deployment to RKE2..."
echo "⚠️  NOTE: Once ArgoCD is set up (GitOps), this script is no longer used for application deployments!"

echo "1. Applying Namespace..."
kubectl apply -f namespace.yaml

echo "2. Applying ConfigMaps and Secrets..."
kubectl apply -f config/

echo "3. Deploying Postgres Database (Helm)..."
helm upgrade --install halan-postgres helm/postgres/postgresql-18.8.12.tgz \
  -f helm/postgres/postgres-values.yaml -n halan

echo "4. Deploying Nginx Frontend (Helm)..."
helm upgrade --install halan-nginx helm/nginx/nginx-25.0.21.tgz \
  -f helm/nginx/nginx-values.yaml -n halan

echo "5. Deploying Backend Application (Custom Helm Chart)..."
helm upgrade --install halan-backend helm/backend/ \
  -f helm/backend/values.yaml -n halan

echo "6. Applying Cluster-Level Routing (Ingress)..."
kubectl apply -f ingress.yaml

echo "7. Applying Batch Jobs and CronJobs..."
kubectl apply -f job.yaml
kubectl apply -f cronjob.yaml

echo "✅ All resources deployed successfully! Run 'kubectl get all -n halan' to check status."
