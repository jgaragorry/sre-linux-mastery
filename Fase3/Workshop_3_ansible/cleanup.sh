#!/bin/bash
echo "Iniciando limpieza del workshop..."

docker rm -f sre-app-node01 sre-app-node02 2>/dev/null
docker rmi lab2-node:24.04 2>/dev/null

ssh-keygen -f ~/.ssh/known_hosts -R '[127.0.0.1]:2225' 2>/dev/null
ssh-keygen -f ~/.ssh/known_hosts -R '[127.0.0.1]:2226' 2>/dev/null

echo "Entorno limpio y libre de recursos."
