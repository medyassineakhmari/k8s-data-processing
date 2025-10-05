# Infrastructure Kubernetes - Système de Traitement de Données en Temps Réel

Ce projet déploie une infrastructure complète de traitement de données en temps réel sur Kubernetes avec autoscaling automatique basé sur la charge.

Data Stream → RabbitMQ → Spark (auto-scaled) → MongoDB
                              ↓
                        Swagger API

Composants :

- RabbitMQ : File de messages pour l'ingestion en temps réel  
- Spark : Traitement des données (avec autoscaling KEDA)  
- MongoDB : Base de données (ReplicaSet 3 nodes)  
- Swagger API : Exposition des résultats  
- KEDA : Autoscaling basé sur la queue RabbitMQ  

Prérequis :

- Cluster Kubernetes (v1.24+)  
- kubectl configuré  
- Helm 3  
- Docker (pour builder les images)  

Installation initiale :

1. Cloner le repository :
```bash
git clone https://github.com/medyassineakhmari/k8s-data-processing.git
cd k8s-data-processing
