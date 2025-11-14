# Observability Stack (PLG + Prometheus)

This directory contains Argo CD Applications that manage the observability stack
for the homelab Kubernetes cluster (k3d).

Components:

- kube-prometheus-stack (Prometheus + Alertmanager + Grafana)
- Loki (log storage)
- Promtail (log collector)
- Postgres Exporter (PostgreSQL metrics)

All components are installed via official Helm charts and managed via Argo CD.
