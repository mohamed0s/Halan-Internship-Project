#!/bin/bash

# Kill any existing background port-forwards spawned by this script on exit
trap 'kill $(jobs -p) 2>/dev/null' EXIT

echo "🚀 Starting dashboard port-forwards..."

# Fetch dynamic passwords
ARGOCD_PW=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
KIBANA_PW="KuzJAt78BFbYYz62" # Pinned in elasticsearch-values.yaml

# Run port-forwards in the background
# We use unique local ports to avoid any collisions (like Longhorn vs ArgoCD)
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
kubectl port-forward svc/kibana-kibana -n logging 5601:5601 > /dev/null 2>&1 &
kubectl port-forward svc/kube-prometheus-grafana -n monitoring 3000:80 > /dev/null 2>&1 &
kubectl port-forward svc/kube-prometheus-kube-prome-prometheus -n monitoring 9090:9090 > /dev/null 2>&1 &
kubectl port-forward svc/kube-prometheus-kube-prome-alertmanager -n monitoring 9093:9093 > /dev/null 2>&1 &
kubectl port-forward svc/kiali -n istio-system 20001:20001 > /dev/null 2>&1 &
kubectl port-forward svc/tracing -n istio-system 16686:80 > /dev/null 2>&1 &
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8082:80 > /dev/null 2>&1 &

echo ""
echo "✅ All dashboards are now accessible!"
echo ""
echo "=========================================================================="
echo " DASHBOARD      | LOCAL URL                 | CREDENTIALS                 "
echo "=========================================================================="
echo " ArgoCD         | http://localhost:8080     | admin : ${ARGOCD_PW:-Not Found}"
echo " Kibana         | http://localhost:5601     | elastic : ${KIBANA_PW}      "
echo " Grafana        | http://localhost:3000     | admin : admin               "
echo " Prometheus     | http://localhost:9090     | (No Auth)                   "
echo " Alertmanager   | http://localhost:9093     | (No Auth)                   "
echo " Kiali          | http://localhost:20001    | (No Auth)                   "
echo " Jaeger         | http://localhost:16686    | (No Auth)                   "
echo " Longhorn       | http://localhost:8082     | (No Auth)                   "
echo "=========================================================================="
echo ""
echo "Press Ctrl+C to stop all port-forwards and exit."

# Keep the script running so the background jobs stay alive
wait
