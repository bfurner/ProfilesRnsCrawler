#!/usr/bin/env bash
set -euo pipefail

: "${RDF_S3_BUCKET:?RDF_S3_BUCKET is required}"
: "${GRAPHDB_BASE_URL:?GRAPHDB_BASE_URL is required}"
: "${GRAPHDB_REPO:?GRAPHDB_REPO is required}"

RDF_S3_PREFIX="${RDF_S3_PREFIX:-rdf/}"
LOAD_PATHS="${LOAD_PATHS:-/data/rdf}"
AWS_REGION="${AWS_REGION:-us-east-2}"
LOCAL_RDF_DIR="/data/rdf"
GRAPHDB_USERNAME="${GRAPHDB_USERNAME:-}"
GRAPHDB_PASSWORD="${GRAPHDB_PASSWORD:-}"
GRAPHDB_PASSWORD_SSM_PARAM="${GRAPHDB_PASSWORD_SSM_PARAM:-}"

mkdir -p "${LOCAL_RDF_DIR}"

echo "Syncing s3://${RDF_S3_BUCKET}/${RDF_S3_PREFIX} -> ${LOCAL_RDF_DIR}"
aws s3 sync "s3://${RDF_S3_BUCKET}/${RDF_S3_PREFIX}" "${LOCAL_RDF_DIR}" --region "${AWS_REGION}"

if [[ -n "${GRAPHDB_PASSWORD_SSM_PARAM}" ]]; then
  echo "Fetching GraphDB password from SSM ${GRAPHDB_PASSWORD_SSM_PARAM}"
  GRAPHDB_PASSWORD="$(aws ssm get-parameter \
    --name "${GRAPHDB_PASSWORD_SSM_PARAM}" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)"
fi

# shellcheck disable=SC2206
paths=( ${LOAD_PATHS} )

cmd=(
  python3 /app/LoadToGraphDB.py
  "${paths[@]}"
  --base-url "${GRAPHDB_BASE_URL}"
  --repo "${GRAPHDB_REPO}"
)

if [[ -n "${GRAPHDB_USERNAME}" ]]; then
  cmd+=(--username "${GRAPHDB_USERNAME}")
fi
if [[ -n "${GRAPHDB_PASSWORD}" ]]; then
  cmd+=(--password "${GRAPHDB_PASSWORD}")
fi

echo "Running LoadToGraphDB.py against GraphDB ${GRAPHDB_BASE_URL} repo=${GRAPHDB_REPO}"
exec "${cmd[@]}"
