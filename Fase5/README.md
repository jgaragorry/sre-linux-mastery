# Laboratorio: Kubernetes Local con Kind sobre WSL2

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Kind](https://img.shields.io/badge/Kind-0.24.0-4285F4?style=for-the-badge&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Engine-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Ubuntu%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Nivel](https://img.shields.io/badge/Nivel-Introductorio-2ea44f?style=for-the-badge)
![Licencia](https://img.shields.io/badge/Licencia-MIT-lightgrey?style=for-the-badge)

Laboratorio práctico para aprender el ciclo de vida completo de un clúster de Kubernetes local, usando **kind** (Kubernetes in Docker) sobre **Ubuntu 24.04 en WSL2**. Cubre instalación de herramientas, creación del clúster, despliegue de una aplicación, exposición de red, escalado horizontal, autorreparación y desmantelamiento controlado del entorno.

## Qué vas a encontrar aquí

Este repositorio contiene un único documento de referencia: [`runbook.md`](./runbook.md), un runbook técnico que documenta, comando por comando, cada fase del laboratorio: qué hace cada instrucción, qué significa cada opción utilizada, qué se espera ver en pantalla al ejecutarla y cómo revertirla. Incluye diagramas del flujo de cada fase y una tabla resumen del ciclo de vida completo.

El laboratorio está diseñado para ejecutarse de principio a fin en menos de quince minutos, y para dejar el sistema anfitrión en el mismo estado en que se encontraba antes de empezar.

## Qué vas a practicar

- Instalación de `kubectl` y `kind` desde cero.
- Creación de un clúster de Kubernetes de un solo nodo dentro de Docker.
- Despliegue de una aplicación mediante un `Deployment`.
- Verificación del mecanismo de autorreparación (self-healing) ante la eliminación de un Pod.
- Exposición de una aplicación mediante un `Service` de tipo `ClusterIP` y un túnel de `port-forward`.
- Escalado horizontal en caliente, sin interrupción del servicio.
- Desmontaje completo y ordenado de toda la infraestructura creada.

## Requisitos

- Ubuntu 24.04 LTS corriendo sobre WSL2.
- Docker Engine instalado y en ejecución (verificable con `docker ps`).
- Conexión a internet para descargar binarios e imágenes de contenedor.
- Aproximadamente 4 GB de espacio libre en disco.

## Cómo ejecutar el laboratorio

1. Cloná este repositorio en tu entorno WSL2:

   ```bash
   git clone <URL_DE_ESTE_REPOSITORIO>
   cd <NOMBRE_DEL_REPOSITORIO>
   ```

2. Abrí [`runbook.md`](./runbook.md) y seguí las fases en orden, empezando por la instalación de `kubectl` y `kind`.

3. Cada fase incluye el comando exacto a ejecutar, la explicación de cada opción utilizada y el resultado que deberías observar antes de avanzar a la fase siguiente.

4. Al terminar, seguí la Fase 6 del runbook para desmontar por completo el clúster y dejar tu entorno WSL2 limpio.

No se requiere ningún archivo de configuración adicional: todos los comandos del laboratorio se ejecutan directamente desde la terminal, tal como aparecen documentados en el runbook.

## Estructura del repositorio

```
.
├── README.md      # Este documento
└── runbook.md     # Runbook técnico completo del laboratorio
```

## Alcance y limitaciones

Este laboratorio utiliza un clúster de un solo nodo, pensado exclusivamente para práctica y aprendizaje local. No está destinado a representar una configuración de alta disponibilidad ni a usarse como base para un entorno de producción.

## Licencia

Este material se distribuye bajo licencia MIT. Podés usarlo, modificarlo y compartirlo libremente citando la fuente original.

