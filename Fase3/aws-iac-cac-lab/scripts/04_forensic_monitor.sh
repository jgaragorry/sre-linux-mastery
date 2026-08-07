#!/usr/bin/env bash
# ==============================================================================
# Script: 04_forensic_monitor.sh
# Propósito: Auditoría FinOps/SRE - Detección de recursos huérfanos/zombies
# ==============================================================================
set -euo pipefail

ENV_TAG="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="sre-tf-state-${ACCOUNT_ID}-${AWS_REGION}"

echo "===================================================================="
echo " EXAMEN FORENSE SRE - AWS (ENV: ${ENV_TAG} | REGION: ${AWS_REGION})"
echo "===================================================================="

EC2_COUNT=$(aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=${ENV_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId" --output text | wc -w)

SG_COUNT=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=${ENV_TAG}" \
    --query "SecurityGroups[].GroupId" --output text | wc -w)

EBS_COUNT=$(aws ec2 describe-volumes \
    --filters "Name=tag:Environment,Values=${ENV_TAG}" "Name=status,Values=creating,available,in-use" \
    --query "Volumes[].VolumeId" --output text | wc -w)

S3_EXISTS=0
S3_OBJECTS_COUNT=0
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    S3_EXISTS=1
    S3_OBJECTS_COUNT=$(aws s3api list-object-versions --bucket "${BUCKET_NAME}" \
        --query "length(Versions[]) || \`0\`" --output text 2>/dev/null || echo 0)
fi

echo " Instancias EC2 Activas/Detenidas : ${EC2_COUNT}"
echo " Grupos de Seguridad (SG)         : ${SG_COUNT}"
echo " Volúmenes EBS                    : ${EBS_COUNT}"
echo " Bucket Backend S3 (${BUCKET_NAME}) : $( [ $S3_EXISTS -eq 1 ] && echo 'PRESENTE' || echo 'ELIMINADO' )"
echo " Objetos/Versiones en S3          : ${S3_OBJECTS_COUNT}"
echo "--------------------------------------------------------------------"

if [ "${EC2_COUNT}" -eq 0 ] && [ "${SG_COUNT}" -eq 0 ] && [ "${EBS_COUNT}" -eq 0 ] && [ "${S3_EXISTS}" -eq 0 ]; then
    echo "[AUDIT SUCCESS] LIMPIEZA ABSOLUTA: No se detectan recursos ni zombies en AWS."
else
    echo "[AUDIT WARN] RECURSOS DETECTADOS EN LA CUENTA."
fi
