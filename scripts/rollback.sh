#!/bin/bash
# Script pour revenir à une version précédente en cas de problème

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction d'aide
show_help() {
    echo "Usage: ./rollback.sh [COMPONENT] [REVISION]"
    echo ""
    echo "Components:"
    echo "  spark      - Rollback l'application Spark"
    echo "  api        - Rollback l'API Swagger"
    echo ""
    echo "REVISION (optionnel):"
    echo "  Si non spécifié, revient à la version précédente"
    echo "  Sinon, spécifier le numéro de révision"
    echo ""
    echo "Exemples:"
    echo "  ./rollback.sh spark        # Revenir à la version précédente"
    echo "  ./rollback.sh api 3        # Revenir à la révision 3"
    echo ""
    echo "Pour voir l'historique:"
    echo "  kubectl rollout history deployment/spark-processor -n data-processing"
    echo "  kubectl rollout history deployment/swagger-api -n data-processing"
}

if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

COMPONENT=$1
REVISION=${2:-}

# Fonction pour afficher l'historique
show_history() {
    local deployment=$1
    echo -e "${BLUE}📜 Historique des déploiements pour ${deployment}:${NC}"
    kubectl rollout history deployment/${deployment} -n data-processing
}

# Fonction de rollback
do_rollback() {
    local deployment=$1
    local revision=$2
    
    echo -e "${YELLOW}🔙 Rollback de ${deployment}...${NC}"
    
    if [ -z "$revision" ]; then
        # Rollback à la version précédente
        kubectl rollout undo deployment/${deployment} -n data-processing
    else
        # Rollback à une révision spécifique
        kubectl rollout undo deployment/${deployment} --to-revision=${revision} -n data-processing
    fi
    
    # Attendre le rollout
    echo -e "${YELLOW}⏳ Attente du rollback...${NC}"
    kubectl rollout status deployment/${deployment} -n data-processing --timeout=300s
    
    echo -e "${GREEN}✅ Rollback de ${deployment} effectué avec succès!${NC}"
}

# Exécuter le rollback
case $COMPONENT in
    spark)
        show_history "spark-processor"
        echo ""
        read -p "Confirmer le rollback? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            do_rollback "spark-processor" "$REVISION"
        else
            echo -e "${YELLOW}Rollback annulé${NC}"
            exit 0
        fi
        ;;
    api)
        show_history "swagger-api"
        echo ""
        read -p "Confirmer le rollback? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            do_rollback "swagger-api" "$REVISION"
        else
            echo -e "${YELLOW}Rollback annulé${NC}"
            exit 0
        fi
        ;;
    *)
        echo -e "${RED}❌ Composant inconnu: $COMPONENT${NC}"
        show_help
        exit 1
        ;;
esac

# Vérifier l'état après rollback
echo ""
echo -e "${YELLOW}🏥 État des pods après rollback:${NC}"
kubectl get pods -n data-processing

echo ""
echo -e "${GREEN}🎉 Rollback terminé!${NC}"
