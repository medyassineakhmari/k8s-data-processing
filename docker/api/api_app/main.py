from fastapi import FastAPI, HTTPException
from pymongo import MongoClient
from typing import List, Optional
import os
from datetime import datetime

app = FastAPI(
    title="Data Processing API",
    description="API for accessing processed data from Spark",
    version="1.0.0"
)

# Configuration MongoDB
MONGODB_HOST = os.getenv('MONGODB_HOST', 'mongodb')
MONGODB_PORT = int(os.getenv('MONGODB_PORT', '27017'))
MONGODB_USER = os.getenv('MONGODB_USERNAME', 'sparkuser')
MONGODB_PASS = os.getenv('MONGODB_PASSWORD', 'sparkpass123')
MONGODB_DB = os.getenv('MONGODB_DATABASE', 'sparkdata')

# Connexion MongoDB (lazy)
mongo_client = None
mongo_db = None

def get_mongo_collection():
    global mongo_client, mongo_db
    if mongo_client is None:
        try:
            mongo_uri = f"mongodb://{MONGODB_USER}:{MONGODB_PASS}@{MONGODB_HOST}:{MONGODB_PORT}/{MONGODB_DB}"
            mongo_client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
            mongo_db = mongo_client[MONGODB_DB]
            # Test connection
            mongo_client.admin.command('ping')
            print(f"Connected to MongoDB: {MONGODB_HOST}")
        except Exception as e:
            print(f"MongoDB connection error: {e}")
            return None
    return mongo_db['processed_data'] if mongo_db else None

@app.get("/")
def root():
    return {
        "service": "Data Processing API",
        "status": "running",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "ready": "/ready",
            "data": "/data",
            "stats": "/stats"
        }
    }

@app.get("/health")
def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/ready")
def ready():
    # Vérifier la connexion MongoDB
    collection = get_mongo_collection()
    if collection is None:
        return {"status": "not ready", "reason": "MongoDB not connected"}
    return {"status": "ready", "timestamp": datetime.utcnow().isoformat()}

@app.get("/data")
def get_data(limit: int = 10, skip: int = 0):
    collection = get_mongo_collection()
    if collection is None:
        raise HTTPException(status_code=503, detail="Database not available")
    
    try:
        data = list(collection.find().skip(skip).limit(limit))
        # Convertir ObjectId en string
        for item in data:
            item['_id'] = str(item['_id'])
        return {
            "count": len(data),
            "data": data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stats")
def get_stats():
    collection = get_mongo_collection()
    if collection is None:
        raise HTTPException(status_code=503, detail="Database not available")
    
    try:
        total_count = collection.count_documents({})
        return {
            "total_records": total_count,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/data/{record_id}")
def get_record(record_id: str):
    collection = get_mongo_collection()
    if collection is None:
        raise HTTPException(status_code=503, detail="Database not available")
    
    try:
        from bson import ObjectId
        record = collection.find_one({"_id": ObjectId(record_id)})
        if record is None:
            raise HTTPException(status_code=404, detail="Record not found")
        record['_id'] = str(record['_id'])
        return record
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
