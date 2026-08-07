#!/usr/bin/env bash
# ==============================================================================
# Script: 02_backend_list.sh
# Propósito: Inspeccionar el estado interno del Backend S3
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="sre-tf-state-${ACCOUNT_ID}-${AWS_REGION}"

echo "===================================================================="
echo " INVENTARIO DEL BACKEND S3: ${BUCKET_NAME}"
echo "===================================================================="

if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "[WARN] El bucket ${BUCKET_NAME} NO existe."
    exit 0
fi

echo "---> Objetos y Estados Guardados:"
aws s3api list-objects-v2 --bucket "${BUCKET_NAME}" \
    --query "Contents[].{Key:Key, Size:Size, LastModified:LastModified}" --output table
