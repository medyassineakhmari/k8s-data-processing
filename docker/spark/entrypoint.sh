#!/bin/bash
set -e

echo "🚀 Starting Spark Application..."

# Démarrer le health check en arrière-plan avec python3
python3 /app/healthcheck.py &

# Attendre que le health check démarre
sleep 2

echo "✅ Health check server running on port 8080"

# Si le code Spark existe, le lancer
if [ -f "/app/spark_app/main.py" ]; then
    echo "📊 Starting Spark data processing..."
    python3 /app/spark_app/main.py
else
    echo "⚠️  No Spark application found, keeping container alive..."
    tail -f /dev/null
fi
