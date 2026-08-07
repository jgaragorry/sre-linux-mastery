#!/usr/bin/env bash
# ==============================================================================
# Script: 03_backend_destroy.sh
# Propósito: Purgado total de objetos/versiones y eliminación del bucket S3
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="sre-tf-state-${ACCOUNT_ID}-${AWS_REGION}"

if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "[OK] El bucket ${BUCKET_NAME} no existe. Nada que eliminar."
    exit 0
fi

echo "[INFO] Vaciando versiones de objetos en ${BUCKET_NAME}..."
while true; do
    VERSIONS=$(aws s3api list-object-versions --bucket "${BUCKET_NAME}" \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)
    if [ "$(echo "${VERSIONS}" | jq '.Objects | length')" -eq 0 ]; then break; fi
    aws s3api delete-objects --bucket "${BUCKET_NAME}" --delete "${VERSIONS}" >/dev/null
done

echo "[INFO] Vaciando marcadores de borrado (Delete Markers)..."
while true; do
    MARKERS=$(aws s3api list-object-versions --bucket "${BUCKET_NAME}" \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)
    if [ "$(echo "${MARKERS}" | jq '.Objects | length')" -eq 0 ]; then break; fi
    aws s3api delete-objects --bucket "${BUCKET_NAME}" --delete "${MARKERS}" >/dev/null
done

echo "[INFO] Eliminando el bucket S3 ${BUCKET_NAME}..."
aws s3api delete-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
echo "[OK] Bucket S3 eliminado correctamente."
