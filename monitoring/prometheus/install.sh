#!/bin/bash
# Installation de Prometheus avec Helm

set -e

echo "📊 Installation de Prometheus Stack..."

# Ajouter le repo Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Créer namespace monitoring
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Installer Prometheus Stack (inclut Prometheus, Grafana, Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123 \
  --wait

echo "✅ Prometheus installé!"
echo ""
echo "🔐 Credentials Grafana:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📍 Pour accéder à Grafana:"
echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "   Puis ouvrir: http://localhost:3000"
echo ""
echo "📍 Pour accéder à Prometheus:"
echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "   Puis ouvrir: http://localhost:9090"
