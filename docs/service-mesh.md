# Service Mesh (Istio) & Tracing

This document outlines the usage of Istio as a Service Mesh within the Halan Internship Project, and how we visualize network traffic using Kiali and Jaeger.

## 🕸️ What is a Service Mesh?

In a standard Kubernetes cluster, microservices talk to each other directly over the internal network. This is fine for small projects, but as a system grows, you lose visibility into the network. You can't easily answer questions like:
- "How long does a request take to travel from the frontend to the backend?"
- "Is traffic failing between the backend and the database?"
- "How can we secure communication (mTLS) between pods?"

A **Service Mesh** solves this by injecting a "sidecar" proxy (Envoy) into every single pod in your application.

## 🚀 Istio Integration

We use **Istio** as our service mesh. 

Instead of the Nginx frontend talking directly to the Flask backend, the Nginx pod's Envoy proxy intercepts the request and forwards it to the Flask pod's Envoy proxy. These proxies measure the exact latency, success rate, and volume of the traffic, and can encrypt it automatically.

### Sidecar Injection
To tell Istio to inject these proxies into our application, we label the `halan` namespace. When Kubernetes sees this label, it automatically mutates our deployments to include the Envoy sidecar.

```bash
kubectl label namespace halan istio-injection=enabled
```

## 👁️ Network Topology Visualization (Kiali)

Because Istio's proxies measure all traffic, we can visualize the entire network topology in real-time. 

**Kiali** is a dashboard that connects to Istio. It draws a live, interactive graph showing:
- Which services are talking to which.
- The requests per second (RPS) between them.
- Any HTTP 4xx or 5xx errors occurring on the network.

### Accessing Kiali
```bash
kubectl port-forward --address 0.0.0.0 svc/kiali -n istio-system 20001:20001
# Open http://localhost:20001
```
*Note: Kiali requires a `PodMonitor` deployed in the cluster to instruct Prometheus to scrape Envoy sidecars. Without this `PodMonitor`, the Kiali graph will be completely empty. Kiali is also configured to pull distributed traces directly from the Jaeger query service.*

## 🕵️ Distributed Tracing (Jaeger)

While Kiali shows you the aggregate flow of traffic, **Jaeger** allows you to trace a *single specific request* as it travels through the entire architecture.

If a user complains that a request to the frontend took 5 seconds, Jaeger can show you a waterfall diagram proving that the frontend took 0.1 seconds, the backend took 0.1 seconds, but the database query took 4.8 seconds.

### Accessing Jaeger
```bash
kubectl port-forward --address 0.0.0.0 svc/tracing -n istio-system 16686:80
# Open http://localhost:16686
```
