#!/usr/bin/env bash
set -euo pipefail

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --set alertmanager.enabled=false \
  --set kube-state-metrics.enabled=false \
  --set prometheus-pushgateway.enabled=false

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --create-namespace \
  --set adminPassword=admin

echo "Prometheus et Grafana installés dans le namespace monitoring."
