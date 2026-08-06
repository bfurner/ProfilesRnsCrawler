FROM python:3.11-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl awscli ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Build from repo root:
#   docker build -f terraform/load_to_graphdb/Dockerfile -t profiles-rns-graphdb-loader .
COPY LoadToGraphDB.py /app/LoadToGraphDB.py
COPY terraform/load_to_graphdb/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
