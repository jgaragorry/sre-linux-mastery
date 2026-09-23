![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?logo=kubernetes&logoColor=white)
![Kind](https://img.shields.io/badge/Kind-v0.24.0-2496ED?logo=kubernetes&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Ubuntu%2024.04-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Engine-2496ED?logo=docker&logoColor=white)
![Nivel](https://img.shields.io/badge/Nivel-Introductorio-informational)
![Estado](https://img.shields.io/badge/Estado-Activo-success)
![Licencia](https://img.shields.io/badge/Uso-Educativo-lightgrey)

# Workshop: Fundamentos Operativos de Kubernetes con Kind en WSL2

## Descripción

Este workshop es una introducción práctica y de consola a Kubernetes, pensada para quienes quieren entender **cómo funciona realmente** un clúster antes de operar uno en producción. En lugar de explicaciones teóricas aisladas, cada comando se ejecuta, se observa y se explica en el momento: vas a construir un clúster desde cero, desplegar una aplicación, romperla intencionalmente para ver cómo se repara sola, exponerla a la red y escalarla en caliente, para finalmente desmontar todo sin dejar rastros.

Todo el laboratorio corre en un entorno local, sin necesidad de una cuenta en la nube ni de infraestructura externa: basta con Docker y WSL2.

## A quién está dirigido

- Personas que están empezando en Kubernetes y quieren una primera experiencia guiada.
- Desarrolladores o administradores que conocen Docker pero nunca han operado un clúster.
- Cualquiera que prefiera aprender ejecutando comandos reales antes de leer documentación extensa.

No se requiere experiencia previa con Kubernetes. Sí se espera comodidad básica con la terminal de Linux.

## Qué vas a construir

Un clúster de Kubernetes local, funcional, con:

- Un `Deployment` de Nginx corriendo con réplicas gestionadas automáticamente.
- Un `Service` interno que balancea tráfico entre esas réplicas.
- Un túnel de acceso desde tu navegador hacia el clúster.
- Una demostración en vivo de autorreparación (self-healing) y escalado horizontal sin caídas de servicio.

## Qué vas a aprender

- El rol de cada componente del plano de control: `etcd`, `kube-apiserver`, `kube-scheduler` y `kube-controller-manager`.
- La diferencia entre gestionar un contenedor suelto y gestionar un `Deployment`.
- Cómo y por qué Kubernetes reemplaza automáticamente los Pods caídos.
- Por qué los Services existen y cómo resuelven el problema de las IPs efímeras de los Pods.
- Cómo escalar una aplicación en caliente sin interrumpir a los clientes conectados.
- El orden correcto para desmontar infraestructura sin dejar procesos huérfanos.

## Requisitos previos

| Requisito | Detalle |
|---|---|
| Sistema operativo | Ubuntu 24.04 LTS sobre WSL2 |
| Docker | Docker Engine instalado y en ejecución |
| Permisos | Usuario incluido en el grupo `docker` |
| Herramientas | Se instalan durante el propio workshop: `kubectl` y `kind` |

## Estructura del workshop

El taller está dividido en seis fases secuenciales, documentadas en detalle en [`RUNBOOK.md`](./RUNBOOK.md):

1. **Instalación de herramientas** — `kubectl` y `kind`.
2. **Aprovisionamiento del clúster** — creación de `primer-cluster`.
3. **Despliegue y autorreparación** — Nginx con dos réplicas y prueba de resiliencia.
4. **Exposición del servicio** — `Service` de tipo `ClusterIP` y acceso vía `port-forward`.
5. **Escalado horizontal** — de 2 a 5 réplicas sin downtime.
6. **Desmantelamiento controlado** — limpieza ordenada de todos los recursos.

## Cómo usar este repositorio

1. Verifica que tu entorno cumple los requisitos previos.
2. Abre [`RUNBOOK.md`](./RUNBOOK.md) y sigue las fases en orden, sin saltarte los pasos de verificación.
3. Ejecuta cada bloque de comandos en tu terminal antes de avanzar a la siguiente fase.
4. Usa la sección de solución de problemas del runbook si algún paso no da el resultado esperado.
5. Al terminar, confirma que el checklist final quede completo antes de cerrar la sesión.

## Duración estimada

Entre 45 y 60 minutos, dependiendo de la familiaridad previa con la terminal de Linux.

## Nota sobre el entorno

Este workshop está diseñado exclusivamente para un entorno local de práctica. `kind` no es una herramienta pensada para producción: su propósito es crear y destruir clústeres desechables para aprendizaje, pruebas de CI o desarrollo local.

