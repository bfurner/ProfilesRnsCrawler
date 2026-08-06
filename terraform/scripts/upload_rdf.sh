#!/usr/bin/env bash
set -euo pipefail

# Upload local rdf/ tree to the staging S3 bucket.
# Usage:
#   ./terraform/scripts/upload_rdf.sh                 # uses terraform output
#   RDF_BUCKET=my-bucket ./terraform/scripts/upload_rdf.sh
#   ./terraform/scripts/upload_rdf.sh <aws-profile>

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
AWS_REGION="${AWS_REGION:-us-east-2}"
LOCAL_RDF="${LOCAL_RDF:-${ROOT_DIR}/rdf}"
S3_PREFIX="${S3_PREFIX:-rdf/}"

if [[ -n "${1:-}" ]]; then
  AWS_PROFILE_ARGS=(--profile "$1")
else
  AWS_PROFILE_ARGS=()
fi

if [[ -n "${RDF_BUCKET:-}" ]]; then
  bucket="${RDF_BUCKET}"
else
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read terraform outputs (or set RDF_BUCKET)" >&2
    exit 1
  fi
  bucket="$(cd "${TF_DIR}" && terraform output -json | jq -r '.rdf_bucket_name.value')"
fi

if [[ -z "${bucket}" || "${bucket}" == "null" ]]; then
  echo "Could not resolve RDF S3 bucket" >&2
  exit 1
fi

if [[ ! -d "${LOCAL_RDF}" ]]; then
  echo "Local RDF directory not found: ${LOCAL_RDF}" >&2
  exit 1
fi

echo "Syncing ${LOCAL_RDF}/ -> s3://${bucket}/${S3_PREFIX}"
aws s3 sync "${LOCAL_RDF}/" "s3://${bucket}/${S3_PREFIX}" \
  --region "${AWS_REGION}" \
  "${AWS_PROFILE_ARGS[@]}"

echo "Done."
