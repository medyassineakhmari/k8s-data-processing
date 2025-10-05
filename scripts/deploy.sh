#!/bin/bash
# Script de déploiement complet de l'infrastructure

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Déploiement de l'infrastructure Kubernetes${NC}"
echo ""

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl n'est pas installé!${NC}"
    exit 1
fi

# Activer metrics-server
echo -e "${YELLOW}📊 Activation du metrics-server...${NC}"
minikube addons enable metrics-server || true


# Vérifier la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Impossible de se connecter au cluster Kubernetes!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connexion au cluster OK${NC}"
echo ""

# 1. Créer le namespace
echo -e "${YELLOW}📦 Création du namespace...${NC}"
kubectl apply -f namespace.yaml

# 2. Appliquer les secrets
echo -e "${YELLOW}🔐 Application des secrets...${NC}"
kubectl apply -f secrets/mongodb-secret.yaml

# 3. Créer les PVCs pour le storage
echo -e "${YELLOW}💾 Création des PersistentVolumeClaims...${NC}"
kubectl apply -f storage/

# 4. Appliquer les ConfigMaps
echo -e "${YELLOW}⚙️  Application des ConfigMaps...${NC}"
kubectl apply -f configmaps/

# 5. Déployer RabbitMQ
echo -e "${YELLOW}🐰 Déploiement de RabbitMQ...${NC}"
kubectl apply -f rabbitmq/rabbitmq-statefulset.yaml
kubectl apply -f rabbitmq/rabbitmq-service.yaml

# Attendre que RabbitMQ soit prêt
echo -e "${YELLOW}⏳ Attente du démarrage de RabbitMQ...${NC}"
kubectl wait --for=condition=ready pod -l app=rabbitmq -n data-processing --timeout=500s

# 6. Déployer MongoDB
echo -e "${YELLOW}🍃 Déploiement de MongoDB...${NC}"
kubectl apply -f mongodb/mongodb-statefulset.yaml
kubectl apply -f mongodb/mongodb-service.yaml

# Attendre que MongoDB soit prêt
echo -e "${YELLOW}⏳ Attente du démarrage de MongoDB...${NC}"
kubectl wait --for=condition=ready pod -l app=mongodb -n data-processing --timeout=300s

# 7. Déployer Spark
echo -e "${YELLOW}⚡ Déploiement de Spark...${NC}"
kubectl apply -f spark/spark-serviceaccount.yaml
kubectl apply -f spark/spark-deployment.yaml
kubectl apply -f spark/spark-service.yaml

# 8. Déployer l'API Swagger
echo -e "${YELLOW}📡 Déploiement de l'API Swagger...${NC}"
kubectl apply -f api/swagger-deployment.yaml
kubectl apply -f api/swagger-service.yaml
kubectl apply -f api/swagger-ingress.yaml

# 9. Installer KEDA si pas déjà installé
if ! kubectl get namespace keda &> /dev/null; then
    echo -e "${YELLOW}🎯 Installation de KEDA...${NC}"
    bash keda/keda-install.sh
fi

# 10. Appliquer le ScaledObject KEDA
echo -e "${YELLOW}📈 Configuration de l'autoscaling KEDA...${NC}"
kubectl apply -f keda/spark-scaledobject.yaml

# 11. Déployer le monitoring
echo -e "${YELLOW}📊 Déploiement du monitoring...${NC}"
kubectl apply -f monitoring/servicemonitors.yaml

echo ""
echo -e "${GREEN}🎉 Déploiement terminé avec succès!${NC}"
echo ""
echo -e "${YELLOW}📋 Vérification des pods:${NC}"
kubectl get pods -n data-processing

echo ""
echo -e "${YELLOW}📋 Services déployés:${NC}"
kubectl get svc -n data-processing

echo ""
echo -e "${GREEN}✅ Infrastructure prête!${NC}"
echo ""
echo -e "${YELLOW}Pour accéder à l'API Swagger:${NC}"
echo "kubectl port-forward -n data-processing svc/swagger-api 8080:8080"
echo "Puis ouvrir: http://localhost:8080"
echo ""
echo -e "${YELLOW}Pour accéder à RabbitMQ Management:${NC}"
echo "kubectl port-forward -n data-processing svc/rabbitmq 15672:15672"
echo "Puis ouvrir: http://localhost:15672 (admin/rabbitpass123)"
