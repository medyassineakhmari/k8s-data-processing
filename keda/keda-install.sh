#!/bin/bash
# Script pour installer KEDA dans ton cluster Kubernetes

set -e

echo "🚀 Installation de KEDA..."

# Méthode 1: Avec Helm (recommandé)
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace

# Méthode 2: Avec kubectl (alternative)
# kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml

echo "✅ KEDA installé avec succès!"
echo "Vérification..."
kubectl get pods -n keda

# Attendre que KEDA soit prêt
kubectl wait --for=condition=ready pod -l app=keda-operator -n keda --timeout=300s
kubectl wait --for=condition=ready pod -l app=keda-metrics-apiserver -n keda --timeout=300s

echo "🎉 KEDA est opérationnel!"
