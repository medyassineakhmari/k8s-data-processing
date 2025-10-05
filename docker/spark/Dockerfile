FROM apache/spark:3.5.0-python3

USER root

# Installer dépendances Python
RUN pip3 install --no-cache-dir \
    pyspark==3.5.0 \
    pymongo==4.6.0 \
    pika==1.3.2 \
    requests==2.31.0 \
    prometheus-client==0.19.0

WORKDIR /app

# Copier les fichiers
COPY requirements.txt /app/
COPY spark_app/ /app/spark_app/
COPY healthcheck.py /app/
COPY entrypoint.sh /app/

# Rendre le script exécutable
RUN chmod +x /app/entrypoint.sh

EXPOSE 8080 4040

USER 185

ENTRYPOINT ["/app/entrypoint.sh"]
