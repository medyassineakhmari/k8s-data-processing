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
git clone <votre-repo>
cd k8s-data-processing
```

### 2. Configurer les secrets

**IMPORTANT**: Avant le déploiement, modifie les mots de passe dans `secrets/mongodb-secret.yaml`

```bash
# Générer un mot de passe base64
echo -n "ton_nouveau_password" | base64
```

Remplace les valeurs dans le fichier secret.

### 3. Adapter la configuration

Modifie ces fichiers selon ton environnement:

- `storage/*.yaml`: Ajuste le `storageClassName` selon ton cluster
- `api/swagger-ingress.yaml`: Change le domaine `api.your-domain.com`
- `spark/spark-deployment.yaml`: Remplace `your-registry/spark-processor:latest`
- `api/swagger-deployment.yaml`: Remplace `your-registry/swagger-api:latest`

### 4. Déployer l'infrastructure

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Le script va:
1. ✅ Créer le namespace `data-processing`
2. ✅ Déployer RabbitMQ (StatefulSet)
3. ✅ Déployer MongoDB (ReplicaSet 3 nodes)
4. ✅ Déployer Spark (avec autoscaling)
5. ✅ Déployer l'API Swagger
6. ✅ Installer KEDA pour l'autoscaling
7. ✅ Configurer le monitoring

---

## 🔄 Workflow de Mise à Jour

### Quand tes collègues modifient le code Spark

```bash
# 1. Tes collègues commitent leur code
cd spark_app/
git add .
git commit -m "feat: amélioration du traitement"
git push

# 2. Builder la nouvelle image Docker
cd docker/spark/
docker build -t your-registry/spark-processor:v1.2.0 .
docker push your-registry/spark-processor:v1.2.0

# 3. Déployer la nouvelle version
cd ../../
./scripts/update.sh spark v1.2.0
```

### Quand tes collègues modifient l'API

```bash
# 1. Commit des changements
cd api_app/
git commit -m "fix: correction endpoint"
git push

# 2. Builder l'image
cd docker/api/
docker build -t your-registry/swagger-api:v1.3.0 .
docker push your-registry/swagger-api:v1.3.0

# 3. Déployer
./scripts/update.sh api v1.3.0
```

### Mise à jour automatique avec CI/CD

Si tu configures GitHub Actions (fichier fourni):

1. Tes collègues push sur `main`
2. GitHub Actions build automatiquement les images
3. Les deployments Kubernetes sont mis à jour automatiquement
4. Rollback automatique en cas d'échec

---

## 🔙 Rollback en cas de problème

```bash
# Voir l'historique des déploiements
kubectl rollout history deployment/spark-processor -n data-processing

# Revenir à la version précédente
./scripts/rollback.sh spark

# Ou revenir à une version spécifique
./scripts/rollback.sh spark 3
```

---

## 📊 Monitoring et Observabilité

### Accéder à Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Ouvrir: http://localhost:3000
- Username: `admin`
- Password: `admin123`

### Accéder à Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Ouvrir: http://localhost:9090

### Voir les logs

```bash
# Logs Spark
kubectl logs -f -n data-processing -l app=spark-processor

# Logs API
kubectl logs -f -n data-processing -l app=swagger-api

# Logs RabbitMQ
kubectl logs -f -n data-processing -l app=rabbitmq
```

### Métriques importantes à surveiller

- **RabbitMQ**: `rabbitmq_queue_messages_ready` (messages en attente)
- **Spark**: Nombre de pods actifs, temps de traitement
- **MongoDB**: Connexions actives, utilisation disque
- **KEDA**: Événements de scaling

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

### Tester l'autoscaling

```bash
# Injecter beaucoup de messages dans RabbitMQ
# Tu devrais voir les pods Spark se multiplier

kubectl get pods -n data-processing -w
kubectl get scaledobject -n data-processing
```

---

## 🐛 Troubleshooting

### Problème: Pods en CrashLoopBackOff

```bash
# Voir les logs détaillés
kubectl describe pod <pod-name> -n data-processing
kubectl logs <pod-name> -n data-processing --previous

# Vérifier les events
kubectl get events -n data-processing --sort-by='.lastTimestamp'
```

### Problème: RabbitMQ ne démarre pas

```bash
# Vérifier le PVC
kubectl get pvc -n data-processing

# Vérifier les logs
kubectl logs rabbitmq-0 -n data-processing

# Forcer la suppression et recréation
kubectl delete statefulset rabbitmq -n data-processing
kubectl apply -f rabbitmq/rabbitmq-statefulset.yaml
```

### Problème: MongoDB ReplicaSet ne se forme pas

```bash
# Vérifier les pods
kubectl get pods -l app=mongodb -n data-processing

# Se connecter à un pod et vérifier le RS
kubectl exec -it mongodb-0 -n data-processing -- mongosh
rs.status()
```

### Problème: Images ne se téléchargent pas

```bash
# Vérifier les secrets de registry (si registry privé)
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n data-processing

# Ajouter imagePullSecrets dans les deployments
```

---

## 📝 Structure du Projet

```
k8s-data-processing/
├── README.md                          # Ce fichier
├── namespace.yaml                     # Namespace principal
├── configmaps/
│   ├── rabbitmq-config.yaml          # Config RabbitMQ
│   └── spark-config.yaml             # Config Spark
├── secrets/
│   └── mongodb-secret.yaml           # Secrets (passwords)
├── storage/
│   ├── rabbitmq-pvc.yaml             # Storage RabbitMQ
│   └── mongodb-pvc.yaml              # Storage MongoDB
├── rabbitmq/
│   ├── rabbitmq-statefulset.yaml     # Déploiement RabbitMQ
│   └── rabbitmq-service.yaml         # Service RabbitMQ
├── spark/
│   ├── spark-serviceaccount.yaml     # RBAC Spark
│   ├── spark-deployment.yaml         # Déploiement Spark
│   └── spark-service.yaml            # Service Spark
├── mongodb/
│   ├── mongodb-statefulset.yaml      # Déploiement MongoDB
│   └── mongodb-service.yaml          # Service MongoDB
├── api/
│   ├── swagger-deployment.yaml       # Déploiement API
│   ├── swagger-service.yaml          # Service API
│   └── swagger-ingress.yaml          # Ingress API
├── keda/
│   ├── keda-install.sh               # Installation KEDA
│   └── spark-scaledobject.yaml       # Config autoscaling
├── monitoring/
│   ├── prometheus/
│   │   └── install.sh                # Installation Prometheus
│   └── servicemonitors.yaml          # Monitors pour metrics
├── docker/
│   ├── spark/
│   │   └── Dockerfile                # Image Spark
│   └── api/
│       └── Dockerfile                # Image API
├── scripts/
│   ├── deploy.sh                     # Déploiement complet
│   ├── update.sh                     # Mise à jour composants
│   └── rollback.sh                   # Rollback versions
└── .github/
    └── workflows/
        └── deploy.yml                # CI/CD GitHub Actions
```

---

## 🔐 Sécurité

### Secrets à ne JAMAIS commiter

- `secrets/mongodb-secret.yaml` (contient les passwords)
- Fichiers `.kubeconfig`
- Clés privées

Utilise `.gitignore`:

```gitignore
secrets/*.yaml
*.kubeconfig
*.key
*.pem
```

### Bonnes pratiques

1. ✅ Utilise des secrets Kubernetes, pas des variables en dur
2. ✅ Active RBAC sur ton cluster
3. ✅ Limite les ressources CPU/Memory pour éviter le resource exhaustion
4. ✅ Utilise NetworkPolicies pour isoler les pods
5. ✅ Active TLS sur l'Ingress (certificats Let's Encrypt)

---

## 🎓 Pour tes collègues développeurs

### Structure du code Spark attendue

```python
# spark_app/main.py
from pyspark.sql import SparkSession
import pika
from pymongo import MongoClient

# Créer SparkSession
spark = SparkSession.builder \
    .appName("DataProcessor") \
    .getOrCreate()

# Connecter à RabbitMQ
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host=os.getenv('RABBITMQ_HOST'),
        credentials=pika.PlainCredentials(
            os.getenv('RABBITMQ_USERNAME'),
            os.getenv('RABBITMQ_PASSWORD')
        )
    )
)

# Traiter les données...
# Sauvegarder dans MongoDB...
```

### Structure de l'API attendue

```python
# api_app/main.py
from fastapi import FastAPI
from pymongo import MongoClient

app = FastAPI()

# Connecter à MongoDB
client = MongoClient(
    host=os.getenv('MONGODB_HOST'),
    username=os.getenv('MONGODB_USERNAME'),
    password=os.getenv('MONGODB_PASSWORD')
)

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/data")
def get_data():
    # Récupérer les données depuis MongoDB
    pass
```

---

## 📞 Support

### En cas de problème

1. Vérifier les logs: `kubectl logs -f <pod> -n data-processing`
2. Vérifier les events: `kubectl get events -n data-processing`
3. Vérifier le status: `kubectl get pods -n data-processing`
4. Consulter ce README

### Ressources utiles

- [Documentation Kubernetes](https://kubernetes.io/docs/)
- [Documentation KEDA](https://keda.sh/docs/)
- [Documentation Spark](https://spark.apache.org/docs/latest/)
- [Documentation RabbitMQ](https://www.rabbitmq.com/documentation.html)

---

## ✅ Checklist avant production

- [ ] Changer tous les passwords par défaut
- [ ] Configurer les backups MongoDB
- [ ] Activer TLS sur tous les services
- [ ] Configurer les NetworkPolicies
- [ ] Mettre en place les alertes Prometheus
- [ ] Tester le rollback
- [ ] Documenter les procédures d'urgence
- [ ] Configurer les resource quotas
- [ ] Tester l'autoscaling sous charge
- [ ] Valider la stratégie de backup

---

**Créé pour le projet de système distribué - Équipe DevOps** 🚀
