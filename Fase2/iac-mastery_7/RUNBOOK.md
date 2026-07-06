# RUNBOOK - OPERACIÓN DE INFRAESTRUCTURA LAB 7 (MULTIRREGIÓN S3 NATIVO)

## 1. Fase de Inicialización e Idempotencia
Asegurar el entorno limpio y el bucket S3 centralizado con cifrado automático:
$ ./scripts/preconfiguracion.sh

## 2. Auditoría FinOps Pre-Despliegue
Evaluar el impacto financiero proyectado en Virginia antes de aplicar cambios:
$ infracost breakdown --path environments/us-east-1/web-cluster

## 3. Despliegue Secuencial Aislado (Sin automatizaciones grupales 'all')
$ cd environments/us-east-1/web-cluster && terragrunt apply -auto-approve
$ cd ../../us-west-2/web-cluster && terragrunt apply -auto-approve

## 4. Auditoría de Estado
Validar los archivos guardados de forma remota:
$ ./scripts/listar_backend.sh
