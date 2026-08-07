#!/usr/bin/env bash
# ==============================================================================
# Script: 01_backend_create.sh
# Propósito: SRE/FinOps - Provisionar Bucket S3 para Estado Remoto (Idempotente)
# ==============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="sre-tf-state-${ACCOUNT_ID}-${AWS_REGION}"

echo "[INFO] Verificando presencia del bucket S3: ${BUCKET_NAME}..."

if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "[OK] El bucket ${BUCKET_NAME} ya existe."
else
    echo "[INFO] Creando bucket S3 para almacenamiento de estado remoto..."
    if [ "${AWS_REGION}" == "us-east-1" ]; then
        aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" >/dev/null
    else
        aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}" >/dev/null
    fi
fi

echo "[INFO] Aplicando/verificando versionado del estado..."
aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

echo "[INFO] Aplicando/verificando cifrado SSE-S3 por defecto..."
aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }'

echo "[INFO] Aplicando/verificando bloqueo de acceso público..."
aws s3api put-public-access-block --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'

echo "[OK] Bucket S3 configurado exitosamente con todas las políticas de seguridad."
