#!/usr/bin/env bash
set -euo pipefail

: "${RDF_S3_BUCKET:?RDF_S3_BUCKET is required}"
: "${GRAPHDB_BASE_URL:?GRAPHDB_BASE_URL is required}"
: "${GRAPHDB_REPO:?GRAPHDB_REPO is required}"

RDF_S3_PREFIX="${RDF_S3_PREFIX:-rdf/}"
AWS_REGION="${AWS_REGION:-us-east-2}"
GRAPHDB_USERNAME="${GRAPHDB_USERNAME:-}"
GRAPHDB_PASSWORD="${GRAPHDB_PASSWORD:-}"
GRAPHDB_PASSWORD_SSM_PARAM="${GRAPHDB_PASSWORD_SSM_PARAM:-}"

if [[ -n "${GRAPHDB_PASSWORD_SSM_PARAM}" ]]; then
  echo "Fetching GraphDB password from SSM ${GRAPHDB_PASSWORD_SSM_PARAM}"
  GRAPHDB_PASSWORD="$(aws ssm get-parameter \
    --name "${GRAPHDB_PASSWORD_SSM_PARAM}" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)"
fi

cmd=(
  python3 /app/LoadToGraphDB.py
  --s3-bucket "${RDF_S3_BUCKET}"
  --s3-prefix "${RDF_S3_PREFIX}"
  --aws-region "${AWS_REGION}"
  --base-url "${GRAPHDB_BASE_URL}"
  --repo "${GRAPHDB_REPO}"
)

if [[ -n "${GRAPHDB_USERNAME}" ]]; then
  cmd+=(--username "${GRAPHDB_USERNAME}")
fi
if [[ -n "${GRAPHDB_PASSWORD}" ]]; then
  cmd+=(--password "${GRAPHDB_PASSWORD}")
fi

echo "Streaming RDF from s3://${RDF_S3_BUCKET}/${RDF_S3_PREFIX} to GraphDB ${GRAPHDB_BASE_URL} repo=${GRAPHDB_REPO}"
exec "${cmd[@]}"
