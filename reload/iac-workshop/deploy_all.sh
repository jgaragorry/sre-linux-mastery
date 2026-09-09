#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TG_TF_PATH="$(which terraform)"

echo "=========================================="
echo " [1/4] Desplegando Entorno DEV (Grafana)  "
echo "=========================================="
cd "${BASE_DIR}/terragrunt/dev"
terragrunt init
terragrunt apply -auto-approve

echo "=========================================="
echo " [2/4] Desplegando Infraestructura PROD   "
echo "=========================================="
cd "${BASE_DIR}/terragrunt/prod"
terragrunt init
terragrunt apply -auto-approve

echo "=========================================="
echo " [3/4] Aprovisionando NFS con Ansible     "
echo "=========================================="
cd "${BASE_DIR}/ansible"
ansible-playbook -i inventory.ini configure_nfs.yml

echo "=========================================="
echo " [4/4] Ejecutando Pruebas de Humo (Smoke) "
echo "=========================================="
echo "Validando lectura en cliente..."
docker exec prod-nfs-client cat /mnt/shared_users/seed_user.json

echo "Validando escritura cliente -> lectura servidor..."
docker exec prod-nfs-client sh -c 'echo "Despliegue automatizado exitoso: $(date)" > /mnt/shared_users/deploy_check.log'
docker exec prod-nfs-server cat /srv/nfs/user_profiles/deploy_check.log

echo ""
echo "=========================================="
echo " Despliegue completado con éxito.         "
echo " Grafana: http://localhost:3000           "
echo "=========================================="
