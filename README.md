# Infrastructure Kubernetes - Système de Traitement de Données en Temps Réel

## 📋 Vue d'ensemble

Ce projet déploie une infrastructure complète de traitement de données en temps réel sur Kubernetes avec autoscaling automatique basé sur la charge.

### Architecture

```
Data Stream → RabbitMQ → Spark (auto-scaled) → MongoDB
                              ↓
                        Swagger API
```

### Composants

- **RabbitMQ**: File de messages pour l'ingestion en temps réel
- **Spark**: Traitement des données (avec autoscaling KEDA)
- **MongoDB**: Base de données (ReplicaSet 3 nodes)
- **Swagger API**: Exposition des résultats
- **KEDA**: Autoscaling basé sur la queue RabbitMQ
- **Prometheus + Grafana**: Monitoring

---

## 🚀 Installation Initiale

### Prérequis

- Cluster Kubernetes (v1.24+)
- kubectl configuré
- Helm 3
- Docker (pour builder les images)

### 1. Cloner le repository

```bash
git clone (https://github.com/medyassineakhmari/k8s-data-processing.git)
cd k8s-data-processing
```

### 2. Configurer les secrets

**IMPORTANT**: Avant le déploiement, modifie les mots de passe dans `secrets/mongodb-secret.yaml`

```bash
# Générer un mot de passe base64
echo -n "ton_nouveau_password" | base64
```

Remplace les valeurs dans le fichier secret.

### 4. Déployer l'infrastructure

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```
---


## 🎯 Autoscaling KEDA

### Configuration actuelle

Le ScaledObject KEDA scale Spark selon:
- **Queue Length**: > 10 messages par replica → scale up
- **CPU**: > 70% → scale up
- **Memory**: > 80% → scale up

### Limites

- **Min replicas**: 1
- **Max replicas**: 10
- **Scale up**: Rapide (15s)
- **Scale down**: Progressif (60s cooldown)

### Modifier les règles de scaling

Édite `keda/spark-scaledobject.yaml` puis:

```bash
kubectl apply -f keda/spark-scaledobject.yaml
```
---
## 📌 Utilisation du Makefile

Ce projet inclut un **Makefile** qui facilite la gestion de l'infrastructure Kubernetes et des différents composants du système de traitement de données.  
Au lieu de taper des commandes `kubectl`, `docker` ou d’exécuter des scripts séparément, le Makefile centralise tout et **réduit la complexité**.

### Commandes principales

Déployer l’infrastructure complète :

```bash
make deploy
```

Voir les logs des composants :

```bash
make logs-spark   # Affiche les logs des pods Spark
make logs-api     # Affiche les logs de l’API Swagger
```

Vérifier le status des pods et services :

```bash
make status
```

Voir toutes les commandes disponibles dans le Makefile :

```bash
make help
```
---
