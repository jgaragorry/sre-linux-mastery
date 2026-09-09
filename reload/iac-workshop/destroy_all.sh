#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TG_TF_PATH="$(which terraform)"

echo "=========================================="
echo " [1/3] Destruyendo Entorno PROD           "
echo "=========================================="
cd "${BASE_DIR}/terragrunt/prod"
terragrunt destroy -auto-approve

echo "=========================================="
echo " [2/3] Destruyendo Entorno DEV            "
echo "=========================================="
cd "${BASE_DIR}/terragrunt/dev"
terragrunt destroy -auto-approve

echo "=========================================="
echo " [3/3] Limpieza de Redes y Cache          "
echo "=========================================="
docker network prune -f
find "${BASE_DIR}" -type d -name ".terragrunt-cache" -prune -exec rm -rf {} +
find "${BASE_DIR}" -type d -name ".terraform" -prune -exec rm -rf {} +

echo "Todos los recursos han sido desmontados limpiamente."
