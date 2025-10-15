import pika
import json
import time
import random

# Configuration RabbitMQ
rabbitmq_host = 'localhost'
rabbitmq_port = 5672
rabbitmq_user = 'admin'
rabbitmq_pass = 'rabbitpass123'  # Vérifie dans secrets/rabbitmq-secret.yaml
queue_name = 'data-stream'

# Connexion
print(f"🔌 Connecting to RabbitMQ at {rabbitmq_host}:{rabbitmq_port}")
credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_pass)
connection = pika.BlockingConnection(
    pika.ConnectionParameters(host=rabbitmq_host, port=rabbitmq_port, credentials=credentials)
)
channel = connection.channel()
channel.queue_declare(queue=queue_name, durable=True)

print(f"📤 Sending data to queue: {queue_name}")
print("=" * 50)

# Simuler des données de capteurs IoT
locations = ["Paris", "London", "Berlin", "Madrid", "Rome"]

try:
    for i in range(1000):
        data = {
            "id": i,
            "sensor_id": f"SENSOR_{i % 10}",
            "temperature": round(random.uniform(15, 30), 2),
            "humidity": round(random.uniform(40, 80), 2),
            "pressure": round(random.uniform(990, 1020), 2),
            "location": random.choice(locations),
            "timestamp": int(time.time())
        }
        
        channel.basic_publish(
            exchange='',
            routing_key=queue_name,
            body=json.dumps(data),
            properties=pika.BasicProperties(delivery_mode=2)
        )
        
        if i % 50 == 0:
            print(f"✓ Sent {i}/1000 messages | Queue: {queue_name}")
        
        time.sleep(0.05)  # 20 msg/sec

except KeyboardInterrupt:
    print("\n⚠️  Interrupted by user")

finally:
    connection.close()
    print(f"\n✅ Successfully sent messages to '{queue_name}'")