#!/usr/bin/env bash
set -euo pipefail

# Build LoadToGraphDB container and push to the ECR repo created by Terraform.
# Usage:
#   ./terraform/scripts/load_to_ecr.sh              # uses terraform output + default AWS creds
#   ./terraform/scripts/load_to_ecr.sh <aws-profile>

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
AWS_REGION="${AWS_REGION:-us-east-2}"

if [[ -n "${1:-}" ]]; then
  AWS_PROFILE_ARGS=(--profile "$1")
else
  AWS_PROFILE_ARGS=()
fi

if [[ -n "${REPO_URL:-}" ]]; then
  repo_url="${REPO_URL}"
else
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read terraform outputs (or set REPO_URL)" >&2
    exit 1
  fi
  repo_url="$(cd "${TF_DIR}" && terraform output -json | jq -r '.repo_url.value')"
fi

if [[ -z "${repo_url}" || "${repo_url}" == "null" ]]; then
  echo "Could not resolve ECR repo URL" >&2
  exit 1
fi

image_name="${repo_url##*/}"
ecr_url="${repo_url%/"${image_name}"}"
tag="$(date +%Y%m%d)"

echo "Building ${image_name}:${tag}"
docker build --platform=linux/amd64 \
  -f "${ROOT_DIR}/terraform/load_to_graphdb/Dockerfile" \
  -t "${image_name}:${tag}" \
  "${ROOT_DIR}"

echo "Logging into ECR ${ecr_url}"
aws ecr get-login-password --region "${AWS_REGION}" "${AWS_PROFILE_ARGS[@]}" \
  | docker login --username AWS --password-stdin "${ecr_url}"

docker tag "${image_name}:${tag}" "${repo_url}:${tag}"
docker tag "${image_name}:${tag}" "${repo_url}:latest"
docker push "${repo_url}:${tag}"
docker push "${repo_url}:latest"

echo "Pushed ${repo_url}:${tag} and ${repo_url}:latest"
