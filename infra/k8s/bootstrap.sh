#!/bin/bash
set -e

echo "🚀 Bootstrapping RKE2 Cluster for GitOps..."
echo "⚠️  NOTE: This script is ONLY for the initial cluster setup."
echo "Once ArgoCD is running, all deployments are managed automatically via Git."

echo "1. Applying Namespace..."
kubectl apply -f namespace.yaml

echo "2. Applying ConfigMaps and Secrets..."
kubectl apply -f config/

echo "3. Handing over control to ArgoCD (App of Apps)..."
# This file doesn't exist yet! You will create it next.
kubectl apply -f argocd/

echo "✅ Bootstrap complete! Check ArgoCD UI to watch the synchronization."
