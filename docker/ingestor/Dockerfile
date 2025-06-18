FROM python:3.12-slim

WORKDIR /opt/ingestor
COPY ingest.py ./
RUN pip install --no-cache-dir asyncpg paho-mqtt
CMD ["python", "ingest.py"]
