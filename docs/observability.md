# Observability (Metrics & Logs)

This project implements a production-grade observability stack, separated into two main domains: **Logging** (ELK Stack) and **Metrics** (Prometheus Stack). 

Both stacks are deployed using ArgoCD and heavily modified official upstream Helm charts.

---

## 🪵 Centralized Logging (ELK Stack)

When you have multiple replicas of frontend and backend pods, manually reading logs with `kubectl logs` becomes impossible. We use the ELK stack to aggregate all logs into a single, searchable database.

### Components
1. **Elasticsearch (`elastic/elasticsearch`)**: The NoSQL search engine and database where logs are indexed and stored.
2. **Kibana (`elastic/kibana`)**: The web UI used to visualize and search the logs stored in Elasticsearch.
3. **Fluent Bit**: A lightweight log shipper deployed as a `DaemonSet` (one pod on every node in the cluster). It reads the standard out (stdout) of every container, formats it, and ships it to Elasticsearch.

### Migration from Bitnami
Originally, we used Bitnami charts for ELK. However, Bitnami (owned by Broadcom) recently pulled many images from Docker Hub, breaking the deployment. 

We migrated to the **official upstream Elastic charts** (`helm.elastic.co`). This required completely rewriting our custom `values.yaml` files, as the upstream charts use different schemas (e.g., `elasticsearchHosts` instead of `elasticsearch.hosts`).

### Accessing Kibana
Kibana is deployed in the `logging` namespace.
```bash
kubectl port-forward --address 0.0.0.0 svc/kibana-kibana -n logging 5601:5601
# Open http://localhost:5601
```

---

## 📈 Cluster Metrics (Prometheus Stack)

To understand the health and performance of the cluster (CPU, memory, network, pod crashes), we deploy the `kube-prometheus-stack`.

### Components
1. **Prometheus**: A time-series database that "scrapes" (pulls) metrics from various endpoints across the cluster at regular intervals.
2. **Grafana**: A visualization UI that connects to Prometheus to display beautiful, real-time dashboards.
3. **Alertmanager**: Evaluates rules against Prometheus data and routes alerts (e.g., to Slack or Email) if something goes wrong (e.g., node CPU > 90%).
4. **Node Exporter**: Runs on every node to expose hardware and OS metrics.
5. **Kube-State-Metrics**: Exposes Kubernetes-specific metrics (e.g., how many pods are pending, how many deployments have failed).

### Accessing Grafana
Grafana is deployed in the `monitoring` namespace. It comes pre-loaded with excellent default dashboards for Kubernetes cluster monitoring.
```bash
kubectl port-forward --address 0.0.0.0 svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Open http://localhost:3000
# Default login usually admin / prom-operator
```

### Accessing Prometheus
You can query raw metrics directly via the Prometheus UI:
```bash
kubectl port-forward --address 0.0.0.0 svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Open http://localhost:9090
```

## Future Improvements (Out of Scope for V1)
To make this truly enterprise-grade, the next step would be to create a `ServiceMonitor` for the Flask backend API. This would allow Prometheus to scrape custom application metrics (like HTTP 500 error rates, or request latency) directly from our Python code.
