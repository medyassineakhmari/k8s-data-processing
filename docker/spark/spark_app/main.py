import os
import sys
import time
from pyspark.sql import SparkSession
import pika
from pymongo import MongoClient
import json

def main():
    print("Initializing Spark Session...")
    sys.stdout.flush()
    
    # Configuration depuis les variables d'environnement
    rabbitmq_host = os.getenv('RABBITMQ_HOST', 'rabbitmq')
    rabbitmq_port = int(os.getenv('RABBITMQ_PORT', '5672'))
    rabbitmq_user = os.getenv('RABBITMQ_USERNAME', 'admin')
    rabbitmq_pass = os.getenv('RABBITMQ_PASSWORD', 'rabbitpass123')
    rabbitmq_queue = os.getenv('RABBITMQ_QUEUE', 'data-stream')
    
    mongodb_host = os.getenv('MONGODB_HOST', 'mongodb')
    mongodb_port = int(os.getenv('MONGODB_PORT', '27017'))
    mongodb_user = os.getenv('MONGODB_USERNAME', 'sparkuser')
    mongodb_pass = os.getenv('MONGODB_PASSWORD', 'sparkpass123')
    mongodb_db = os.getenv('MONGODB_DATABASE', 'sparkdata')
    
    # Créer Spark Session
    spark = SparkSession.builder \
        .appName("DataProcessor") \
        .config("spark.driver.memory", os.getenv('SPARK_DRIVER_MEMORY', '2g')) \
        .config("spark.executor.memory", os.getenv('SPARK_EXECUTOR_MEMORY', '2g')) \
        .getOrCreate()
    
    print(f"Spark Session created: {spark.version}")
    sys.stdout.flush()
    
    # Connexion MongoDB
    try:
        mongo_uri = f"mongodb://{mongodb_user}:{mongodb_pass}@{mongodb_host}:{mongodb_port}/{mongodb_db}"
        mongo_client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        mongo_db = mongo_client[mongodb_db]
        mongo_collection = mongo_db['processed_data']
        print(f"Connected to MongoDB: {mongodb_host}")
        sys.stdout.flush()
    except Exception as e:
        print(f"MongoDB connection error: {e}")
        sys.stdout.flush()
        mongo_collection = None
    
    # Connexion RabbitMQ
    try:
        credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_pass)
        parameters = pika.ConnectionParameters(
            host=rabbitmq_host,
            port=rabbitmq_port,
            credentials=credentials,
            heartbeat=600,
            blocked_connection_timeout=300
        )
        connection = pika.BlockingConnection(parameters)
        channel = connection.channel()
        channel.queue_declare(queue=rabbitmq_queue, durable=True)
        print(f"Connected to RabbitMQ: {rabbitmq_host}:{rabbitmq_port}")
        sys.stdout.flush()
    except Exception as e:
        print(f"RabbitMQ connection error: {e}")
        sys.stdout.flush()
        print("Running in standalone mode without RabbitMQ...")
        sys.stdout.flush()
        time.sleep(3600)
        return
    
    # Callback pour traiter les messages
    def callback(ch, method, properties, body):
        try:
            print(f"Received message: {body.decode()}")
            sys.stdout.flush()
            
            # Traitement des données avec Spark
            data = json.loads(body.decode())
            
            # Exemple de traitement simple
            processed_data = {
                'original': data,
                'processed_at': time.time(),
                'status': 'processed'
            }
            
            # Sauvegarder dans MongoDB
            if mongo_collection:
                result = mongo_collection.insert_one(processed_data)
                print(f"Data saved to MongoDB with ID: {result.inserted_id}")
                sys.stdout.flush()
            
            # Acknowledger le message
            ch.basic_ack(delivery_tag=method.delivery_tag)
            
        except Exception as e:
            print(f"Error processing message: {e}")
            sys.stdout.flush()
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
    
    # Consommer les messages
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue=rabbitmq_queue, on_message_callback=callback)
    
    print(f"Waiting for messages from queue: {rabbitmq_queue}")
    print("Press CTRL+C to exit")
    sys.stdout.flush()
    
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print("Stopping consumer...")
        sys.stdout.flush()
        channel.stop_consuming()
    finally:
        connection.close()
        spark.stop()

if __name__ == '__main__':
    main()
