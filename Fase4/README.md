<div align="center">

# SRE Linux Mastery — Especialización Profesional

## Fase 4: Contenedorización, Arquitectura de Microservicios & Docker Engine

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-Engine_CE-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![NGINX](https://img.shields.io/badge/NGINX-Server-009639?style=for-the-badge&logo=nginx&logoColor=white)](https://www.nginx.com)
[![License](https://img.shields.io/badge/License-Educational-orange?style=for-the-badge)](#)

</div>

---

## Descripción del módulo

En esta fase se transita desde la administración avanzada del kernel y el sistema operativo base hacia la contenedorización de aplicaciones, el aislamiento de procesos a nivel de producción y el diseño de arquitecturas orientadas a microservicios.

El enfoque no es Docker como simple herramienta de desarrollo, sino como pieza central de la disciplina SRE/SysOps: resiliencia, aislamiento de recursos, persistencia inmutable y redes privadas inter-contenedor.

## Mapa del módulo

```
Fundamentos OCI  ──>  Networking & DNS  ──>  Persistencia & Volúmenes
      │                     │                        │
      ▼                     ▼                        ▼
Kernel Namespaces     Bridge Networks          Named Volumes
& Control Groups      DNS Resolution           Storage Drivers

Observabilidad  ──>  Resiliencia SRE  ──>  Microservicios Multi-Tier
      │                     │                        │
      ▼                     ▼                        ▼
Metrics, Logs &       Restart Policies        Docker Compose &
cgroups Inspection    cgroup Limits           Decoupled Services
```

## Objetivos de aprendizaje

### Arquitectura del engine y del kernel
- Namespaces (PID, NET, MNT, IPC, UTS) y cgroups en el kernel de Linux.
- Virtualización tradicional (hypervisors/VMs) frente a contenedorización (OS-level virtualization).
- Ciclo de vida de imágenes OCI, capas inmutables (Overlay2 FS) y capa de escritura efímera.

### Operaciones avanzadas en CLI
- Despliegues efímeros, interactivos y en segundo plano (detached mode).
- Inyección de comandos, diagnóstico en vivo y transferencia de artefactos (`exec`, `cp`, `logs`, `diff`).
- Limpieza masiva y purga segura de almacenamiento (`prune`, `system df`).

### Redes privadas y resolución de nombres
- Redes bridge personalizadas y aisladas.
- Comunicación inter-contenedor vía el servidor DNS interno de Docker, sin exponer puertos al exterior.

### Persistencia de datos
- Volúmenes administrados (named volumes) frente a bind mounts.
- Arquitecturas stateful (bases de datos) con pruebas de falla e inmutabilidad de datos.

### Monitoreo, performance y resiliencia SRE
- Límites estrictos de CPU y memoria por contenedor.
- Diagnóstico de fallas: OOMKilled, códigos de salida, inspección de eventos.
- Recuperación automática mediante restart policies (`unless-stopped`, `on-failure`).

## Stack tecnológico

| Herramienta / Componente | Función en la especialización |
|---|---|
| Ubuntu Server 24.04 LTS | Sistema operativo host base de producción |
| Docker Engine (CE) | Engine principal de gestión de contenedores |
| containerd & runc | Runtimes de contenedor OCI de bajo nivel |
| PostgreSQL 16 & NGINX | Servicios de prueba para arquitecturas multi-capa |
| Docker Compose | Declaración y orquestación local de microservicios |

## Estructura del repositorio

```
├── 01-setup-and-installation/    Scripts de instalación de Docker Engine en Ubuntu 24.04 LTS
├── 02-docker-cli-mastery/        Comandos esenciales, trucos SRE y gestión de ciclo de vida
├── 03-networking-and-dns/        Laboratorios de redes aisladas y comunicación inter-contenedor
├── 04-volumes-and-persistence/   Ejercicios prácticos de bases de datos y persistencia de datos
├── 05-monitoring-and-limits/     Limitación de cgroups, inspección de métricas y troubleshooting
└── 06-microservices-lab/         Laboratorio integrado multi-tier (Frontend + API + Database)
```

## Prerrequisitos

- Terminal Linux (Ubuntu Server 24.04 LTS en servidor físico, VM o WSL2).
- Acceso con privilegios de `sudo` para el setup inicial.
- Conocimientos previos de navegación en CLI de Linux, permisos de archivos e inspección de procesos (`ps`, `top`).

---

<div align="center">

**SRE Linux Mastery** — Especialización Profesional

</div>

