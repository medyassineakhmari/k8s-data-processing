#!/bin/bash
# Script pour mettre à jour les composants quand tes collègues modifient le code

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: ./update.sh [COMPONENT] [IMAGE_TAG]"
    echo ""
    echo "Components disponibles:"
    echo "  spark      - Mettre à jour l'application Spark"
    echo "  api        - Mettre à jour l'API Swagger"
    echo "  all        - Mettre à jour tous les composants"
    echo ""
    echo "Exemples:"
    echo "  ./update.sh spark v1.2.0"
    echo "  ./update.sh api latest"
    echo "  ./update.sh all v2.0.0"
}

# Vérifier les arguments
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

COMPONENT=$1
IMAGE_TAG=${2:-latest}

echo -e "${BLUE}🔄 Mise à jour de l'infrastructure${NC}"
echo ""

# Fonction pour mettre à jour Spark
update_spark() {
    local tag=$1
    echo -e "${YELLOW}⚡ Mise à jour de Spark vers ${tag}...${NC}"
    
    # Mettre à jour l'image dans le deployment
    kubectl set image deployment/spark-processor \
        spark-app=your-registry/spark-processor:${tag} \
        -n data-processing
    
    # Attendre le rollout
    echo -e "${YELLOW}⏳ Attente du rollout...${NC}"
    kubectl rollout status deployment/spark-processor -n data-processing --timeout=300s
    
    echo -e "${GREEN}✅ Spark mis à jour avec succès!${NC}"
}

# Fonction pour mettre à jour l'API
update_api() {
    local tag=$1
    echo -e "${YELLOW}📡 Mise à jour de l'API Swagger vers ${tag}...${NC}"
    
    # Mettre à jour l'image dans le deployment
    kubectl set image deployment/swagger-api \
        api=your-registry/swagger-api:${tag} \
        -n data-processing
    
    # Attendre le rollout
    echo -e "${YELLOW}⏳ Attente du rollout...${NC}"
    kubectl rollout status deployment/swagger-api -n data-processing --timeout=300s
    
    echo -e "${GREEN}✅ API mise à jour avec succès!${NC}"
}

# Fonction pour vérifier la santé
check_health() {
    echo ""
    echo -e "${YELLOW}🏥 Vérification de la santé des pods...${NC}"
    kubectl get pods -n data-processing
    
    echo ""
    echo -e "${YELLOW}📊 État des deployments:${NC}"
    kubectl get deployments -n data-processing
}

# Exécuter la mise à jour selon le composant
case $COMPONENT in
    spark)
        update_spark $IMAGE_TAG
        check_health
        ;;
    api)
        update_api $IMAGE_TAG
        check_health
        ;;
    all)
        update_spark $IMAGE_TAG
        update_api $IMAGE_TAG
        check_health
        ;;
    *)
        echo -e "${RED}❌ Composant inconnu: $COMPONENT${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Mise à jour terminée!${NC}"

# Afficher les logs récents si nécessaire
echo ""
echo -e "${BLUE}💡 Pour voir les logs:${NC}"
if [ "$COMPONENT" == "spark" ] || [ "$COMPONENT" == "all" ]; then
    echo "  kubectl logs -f -n data-processing -l app=spark-processor"
fi
if [ "$COMPONENT" == "api" ] || [ "$COMPONENT" == "all" ]; then
    echo "  kubectl logs -f -n data-processing -l app=swagger-api"
fi
