# Makefile pour simplifier les commandes courantes
.PHONY: help deploy update-spark update-api rollback-spark rollback-api logs clean

# Variables
NAMESPACE := data-processing
SPARK_IMAGE := akhmyassine/spark-processor
API_IMAGE := akhmyassine/swagger-api
VERSION ?= latest

help: ## Afficher l'aide
	@echo "Commandes disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Déployer l'infrastructure complète
	@echo "🚀 Déploiement de l'infrastructure..."
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh

install-monitoring: ## Installer Prometheus et Grafana
	@echo "📊 Installation du monitoring..."
	@chmod +x monitoring/prometheus/install.sh
	@./monitoring/prometheus/install.sh

install-keda: ## Installer KEDA
	@echo "🎯 Installation de KEDA..."
	@chmod +x keda/keda-install.sh
	@./keda/keda-install.sh

# Build et push des images
build-spark: ## Builder l'image Spark
	@echo "🔨 Build de l'image Spark..."
	@cd docker/spark && docker build -t $(SPARK_IMAGE):$(VERSION) .

push-spark: build-spark ## Push l'image Spark
	@echo "📤 Push de l'image Spark..."
	@docker push $(SPARK_IMAGE):$(VERSION)

build-api: ## Builder l'image API
	@echo "🔨 Build de l'image API..."
	@cd docker/api && docker build -t $(API_IMAGE):$(VERSION) .

push-api: build-api ## Push l'image API
	@echo "📤 Push de l'image API..."
	@docker push $(API_IMAGE):$(VERSION)

build-all: build-spark build-api ## Builder toutes les images

push-all: push-spark push-api ## Push toutes les images

# Mises à jour
update-spark: ## Mettre à jour Spark (usage: make update-spark VERSION=v1.2.0)
	@echo "⚡ Mise à jour de Spark vers $(VERSION)..."
	@./scripts/update.sh spark $(VERSION)

update-api: ## Mettre à jour l'API (usage: make update-api VERSION=v1.2.0)
	@echo "📡 Mise à jour de l'API vers $(VERSION)..."
	@./scripts/update.sh api $(VERSION)

update-all: ## Mettre à jour tous les composants
	@echo "🔄 Mise à jour complète..."
	@./scripts/update.sh all $(VERSION)

# Rollback
rollback-spark: ## Rollback Spark à la version précédente
	@echo "🔙 Rollback de Spark..."
	@./scripts/rollback.sh spark

rollback-api: ## Rollback API à la version précédente
	@echo "🔙 Rollback de l'API..."
	@./scripts/rollback.sh api

# Logs
logs-spark: ## Voir les logs Spark
	@kubectl logs -f -n $(NAMESPACE) -l app=spark-processor --tail=100

logs-api: ## Voir les logs API
	@kubectl logs -f -n $(NAMESPACE) -l app=swagger-api --tail=100

logs-rabbitmq: ## Voir les logs RabbitMQ
	@kubectl logs -f -n $(NAMESPACE) -l app=rabbitmq --tail=100

logs-mongodb: ## Voir les logs MongoDB
	@kubectl logs -f -n $(NAMESPACE) -l app=mongodb --tail=100

# Status
status: ## Afficher le statut des pods
	@echo "📊 Status des pods:"
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "📊 Status des deployments:"
	@kubectl get deployments -n $(NAMESPACE)
	@echo ""
	@echo "📊 Status des services:"
	@kubectl get svc -n $(NAMESPACE)

events: ## Voir les events récents
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

describe-spark: ## Décrire le deployment Spark
	@kubectl describe deployment spark-processor -n $(NAMESPACE)

describe-api: ## Décrire le deployment API
	@kubectl describe deployment swagger-api -n $(NAMESPACE)

# Port forwarding
forward-api: ## Port-forward l'API (localhost:8080)
	@echo "🌐 API accessible sur http://localhost:8080"
	@kubectl port-forward -n $(NAMESPACE) svc/swagger-api 8080:8080

forward-rabbitmq: ## Port-forward RabbitMQ Management (localhost:15672)
	@echo "🐰 RabbitMQ Management sur http://localhost:15672"
	@echo "   Credentials: admin / rabbitpass123"
	@kubectl port-forward -n $(NAMESPACE) svc/rabbitmq 15672:15672

forward-grafana: ## Port-forward Grafana (localhost:3000)
	@echo "📊 Grafana sur http://localhost:3000"
	@echo "   Credentials: admin / admin123"
	@kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

forward-prometheus: ## Port-forward Prometheus (localhost:9090)
	@echo "📈 Prometheus sur http://localhost:9090"
	@kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Scaling manuel
scale-spark: ## Scaler manuellement Spark (usage: make scale-spark REPLICAS=5)
	@kubectl scale deployment spark-processor -n $(NAMESPACE) --replicas=$(REPLICAS)
	@echo "✅ Spark scalé à $(REPLICAS) replicas"

# Test et debug
shell-spark: ## Ouvrir un shell dans un pod Spark
	@kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=spark-processor -o jsonpath='{.items[0].metadata.name}') -- /bin/bash

shell-mongodb: ## Ouvrir un shell MongoDB
	@kubectl exec -it -n $(NAMESPACE) mongodb-0 -- mongosh

shell-rabbitmq: ## Ouvrir un shell RabbitMQ
	@kubectl exec -it -n $(NAMESPACE) rabbitmq-0 -- /bin/bash

test-rabbitmq: ## Tester la connexion RabbitMQ
	@echo "🧪 Test de RabbitMQ..."
	@kubectl run rabbitmq-test --rm -it --restart=Never --image=rabbitmq:3.12-management \
		-n $(NAMESPACE) -- rabbitmqadmin -H rabbitmq -u admin -p rabbitpass123 list queues

# Nettoyage
clean-failed: ## Supprimer les pods en erreur
	@echo "🧹 Nettoyage des pods en erreur..."
	@kubectl delete pods -n $(NAMESPACE) --field-selector status.phase=Failed

clean-all: ## Supprimer toute l'infrastructure (ATTENTION!)
	@echo "⚠️  Suppression de l'infrastructure..."
	@echo -n "Êtes-vous sûr? [y/N] "; read REPLY; \
	if echo "$$REPLY" | grep -iq "^y$$"; then \
		kubectl delete namespace $(NAMESPACE); \
		kubectl delete namespace monitoring; \
		kubectl delete namespace keda; \
	fi


restart-spark: ## Redémarrer tous les pods Spark
	@echo "🔄 Redémarrage de Spark..."
	@kubectl rollout restart deployment/spark-processor -n $(NAMESPACE)

restart-api: ## Redémarrer tous les pods API
	@echo "🔄 Redémarrage de l'API..."
	@kubectl rollout restart deployment/swagger-api -n $(NAMESPACE)

# Backup
backup-mongodb: ## Backup MongoDB
	@echo "💾 Backup de MongoDB..."
	@kubectl exec -n $(NAMESPACE) mongodb-0 -- mongodump --archive=/tmp/backup-$$(date +%Y%m%d-%H%M%S).gz --gzip

# Métriques
metrics-spark: ## Afficher les métriques CPU/Memory de Spark
	@kubectl top pods -n $(NAMESPACE) -l app=spark-processor

metrics-all: ## Afficher toutes les métriques
	@kubectl top pods -n $(NAMESPACE)

# Info
info: ## Afficher les infos du cluster
	@echo "ℹ️  Informations du cluster:"
	@kubectl cluster-info
	@echo ""
	@echo "📦 Namespaces:"
	@kubectl get namespaces
	@echo ""
	@echo "🖥️  Nodes:"
	@kubectl get nodes

version: ## Afficher les versions déployées
	@echo "📌 Versions actuelles:"
	@echo -n "Spark: "
	@kubectl get deployment spark-processor -n $(NAMESPACE) -o jsonpath='{.spec.template.spec.containers[0].image}'
	@echo ""
	@echo -n "API: "
	@kubectl get deployment swagger-api -n $(NAMESPACE) -o jsonpath='{.spec.template.spec.containers[0].image}'
	@echo ""
