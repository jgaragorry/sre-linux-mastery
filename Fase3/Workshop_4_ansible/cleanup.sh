#!/usr/bin/env bash
set -e

echo "[SRE CLEANUP] Iniciando restablecimiento del entorno..."

# 1. Detener y remover contenedor de prueba si existe
if [ $(docker ps -a -q -f name=sre_web_service) ]; then
    echo "[DOCKER] Removiendo contenedor sre_web_service..."
    docker rm -f sre_web_service
else
    echo "[DOCKER] No existe el contenedor sre_web_service."
fi

# 2. Limpieza de cache y archivos temporales de Ansible
echo "[ANSIBLE] Eliminando archivos temporales y caches..."
rm -rf .ansible .ansible_retry *.retry __pycache__

echo "[SRE CLEANUP] Entorno restablecido a estado inicial. Listo para reejecutar el taller."
