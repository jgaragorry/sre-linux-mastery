<div align="center">

# SRE Linux Mastery — Workshop: Fundamentos de Podman & Rootless Containers

### Contenedorización Daemonless, Mapeo de User Namespaces, Pods OCI y Manifiestos Nativos de Kubernetes

[![Plataforma](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Podman](https://img.shields.io/badge/Podman-Engine_v4.9+-892CA0?style=for-the-badge&logo=podman&logoColor=white)](https://podman.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Native_YAML-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Security](https://img.shields.io/badge/Security-Rootless_Default-00A389?style=for-the-badge)](#)

</div>

---

## 🎯 Descripción del Workshop

Este repositorio contiene la guía práctica y el procedimiento operativo para dominar **Podman (Pod Manager)** bajo estándares de **Site Reliability Engineering (SRE)** y **DevSecOps**.

El workshop demuestra de manera práctica las ventajas arquitectónicas de Podman frente a los motores de contenedores tradicionales:

- **Arquitectura Daemonless:** Eliminación del demonio central y mitigación de puntos únicos de falla.
- **Seguridad Rootless:** Ejecución de procesos con aislamiento mediante *User Namespaces*, impidiendo que un escape del contenedor obtenga privilegios de `root` en el host.
- **Agrupación de Servicios en Pods:** Creación de topologías multicontenedor compartiendo red y puertos (*localhost*).
- **Puente hacia Kubernetes:** Exportación y despliegue declarativo de manifiestos estándar de Kubernetes (`podman generate kube` y `podman play kube`).

El procedimiento operativo paso a paso se encuentra documentado en [`runbook.md`](./runbook.md).

---

## 🗺️ Mapa de la Arquitectura Daemonless & Pods

```
[ Usuario Host (UID 1000) ]
        │
        ▼ (Fork / Exec sin demonio)
+─────────────────────────────────────────────────────────────+
|  POD OCI: pod-webstack (Network Namespace Compartido)       |
|  Puerto Host: 0.0.0.0:8080                                  |
|                                                               |
|  +------------------------+     +------------------------+  |
|  | Contenedor Infra       |     | Contenedor NGINX       |  |
|  | (Pause / Network Hold) | <─> | (web-proxy: Puerto 80) |  |
|  +------------------------+     +------------------------+  |
+─────────────────────────────────────────────────────────────+
        │
        ▼ (Exportación Declarativa)
[ Manifiesto Kubernetes: webstack-k8s.yaml (Kind: Pod) ]
```

---

## 🚀 Objetivos de Aprendizaje

1. **Aislamiento en Espacio de Usuario (Rootless Mode):**
   - Configuración de `/etc/subuid` y `/etc/subgid` para delegar rangos de identificadores secundarios.
   - Comprobación del mapeo `root` interno vs. `UID 1000` en el host mediante `podman top`.

2. **Gestión de Cargas Relacionales y Persistencia:**
   - Creación de redes privadas de usuario y volúmenes administrados en `~/.local/share/containers/storage/`.
   - Despliegue de PostgreSQL 16 con inmutabilidad de datos.

3. **Orquestación de Pods Locales:**
   - Creación de Pods OCI con mapeo de puertos centralizado y comunicación inter-servicio en `127.0.0.1`.

4. **Automatización Declarativa con Kubernetes:**
   - Generación automática de manifiestos YAML (`generate kube`).
   - Aprovisionamiento y destrucción de infraestructura declarativa mediante `podman play kube`.

---

## 📊 Matriz Comparativa: Docker vs. Podman

| Criterio | Docker Engine | Podman |
|---|---|---|
| **Daemon Central** | Requiere `dockerd` activo como `root` | **No requiere demonio (Daemonless)** |
| **Privilegios en el Host** | Superusuario (`root` / `sudo`) | **Usuario no privilegiado (Rootless)** |
| **Mapeo de Procesos** | Gestionado por demonio intermediario | **Hijo directo del proceso del usuario** |
| **Concepto de Pod** | No disponible nativamente | **Nativo (Idéntico a Kubernetes)** |
| **Compatibilidad K8s** | Requiere traducción externa | **Exportación y reproducción nativa en YAML** |

---

## 📁 Estructura del Repositorio

```text
.
├── webstack-k8s.yaml    # Manifiesto de Kubernetes generado automáticamente
├── runbook.md           # Guía operativa paso a paso y validación de comandos
└── README.md            # Este archivo
```

---

## 🛠️ Prerrequisitos

| Requisito | Detalle |
|---|---|
| Sistema Operativo | Ubuntu Server 24.04 LTS (Nativo o sobre WSL2) |
| Paquetes Requeridos | `podman`, `uidmap`, `slirp4netns` |
| Permisos | Usuario estándar con rangos asignados en `/etc/subuid` |

---

## ⚡ Reproducción Rápida del Workshop

```bash
# 1. Configurar registros de consulta
mkdir -p ~/.config/containers
echo 'unqualified-search-registries = ["docker.io", "quay.io"]' > ~/.config/containers/registries.conf

# 2. Crear un Pod y agregar un servicio NGINX
podman pod create --name pod-webstack -p 8080:80
podman run -d --name web-proxy --pod pod-webstack docker.io/library/nginx:alpine

# 3. Probar respuesta HTTP del Pod
curl -I http://localhost:8080

# 4. Exportar a Kubernetes YAML y probar reproducción declarativa
podman generate kube pod-webstack > webstack-k8s.yaml
podman pod rm -f pod-webstack
podman play kube webstack-k8s.yaml

# 5. Limpieza total
podman play kube --down webstack-k8s.yaml
podman rmi -a -f
rm -f webstack-k8s.yaml
```

---

## 📜 Licencia

Material técnico desarrollado con fines educativos para la especialización profesional en Arquitectura Cloud, DevSecOps y Site Reliability Engineering.

**SRE Linux Mastery** — Especialización Profesional en Arquitectura Cloud & Site Reliability Engineering

