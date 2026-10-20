<div align="center">

# Laboratorio 2: Argo CD con Repositorio Propio

**GitOps de extremo a extremo sobre Kubernetes local**

![Argo CD](https://img.shields.io/badge/Argo%20CD-stable-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-kind-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Runtime-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Repo%20Propio-181717?style=for-the-badge&logo=github&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Ubuntu%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Nivel](https://img.shields.io/badge/Nivel-Intermedio-2EA44F?style=for-the-badge)
![Duracion](https://img.shields.io/badge/Duracion-45%20min-8250DF?style=for-the-badge)

</div>

---

## 1. Resumen ejecutivo

Este laboratorio demuestra el modelo **GitOps** tal como opera en producción: Git es la única fuente de verdad y Argo CD reconcilia continuamente el clúster contra ese estado deseado. A diferencia del Laboratorio 1, aquí el repositorio es propio, la conexión es por SSH y todo cambio nace en un commit.

El laboratorio está diseñado para ser autónomo y reproducible. Se documenta una estructura de directorios estricta y un orden de ejecución secuencial para evitar derivas de configuración o condiciones de carrera.

| Aspecto | Detalle |
|---|---|
| Objetivo | Desplegar y operar una aplicación mediante Git y Argo CD |
| Modelo | Pull-based GitOps con sincronización automática |
| Entorno | Clúster local `kind` (nombre: `argocd-lab2`) sobre Docker en WSL2 |
| Repositorio Git | `git@github.com:jgaragorry/mi-app-argocd.git` |
| Entregable | Aplicación `mi-app` en estado `Synced` y `Healthy` |

## 2. Estructura del laboratorio

El laboratorio se ejecuta y organiza en dos ubicaciones separadas para mantener el principio de GitOps (separación entre el manifiesto de Argo CD y el repositorio de la aplicación):

**A. Directorio de trabajo local (`~/argocd-lab-2/`):**

```text
argocd-lab-2/
├── manifests/
│   └── mi-app.yaml        # El objeto Application de Argo CD
├── repo-git/              # El repositorio local que se sube a GitHub
│   ├── deployment.yaml    # Manifiesto del Deployment
│   ├── service.yaml       # Manifiesto del Service
│   └── configmap.yaml     # Manifiesto del ConfigMap
└── RUNBOOK.md
```

**B. Repositorio remoto en GitHub (`mi-app-argocd`):**
Contiene únicamente los archivos de la carpeta `repo-git/` (deployment, service, configmap). Argo CD leerá desde aquí.

## 3. Tecnologías

- Docker (runtime de contenedores)
- kind (Kubernetes en Docker)
- kubectl (cliente de Kubernetes)
- Argo CD (motor GitOps)
- Git y GitHub (control de versiones)

## 4. Requisitos previos

- [ ] WSL2 con Ubuntu 24.04
- [ ] Docker en ejecución (`docker ps` responde sin errores)
- [ ] `kind`, `kubectl`, `git` y `ssh` instalados
- [ ] Cuenta de GitHub (`jgaragorry`) con clave SSH configurada localmente

## 5. Flujo general del laboratorio

```mermaid
flowchart LR
    F1[1. Clúster kind] --> F2[2. Instalar Argo CD]
    F2 --> F3[3. Acceso a la UI]
    F3 --> F4[4. Repo propio en GitHub]
    F4 --> F5[5. Credencial SSH]
    F5 --> F6[6. Crear Application]
    F6 --> F7[7. Verificar despliegue]
    F7 --> F8[8. Cambio en Git]
    F8 --> F9[9. Prune y selfHeal]
    F9 --> F10[10. Rollback]
    F10 --> F11[11. Limpieza]
```

**Leyenda del diagrama:** Muestra el orden secuencial estricto. No se puede crear la Application (Fase 6) sin haber registrado la credencial SSH (Fase 5), y no se puede probar selfHeal (Fase 9) sin tener la aplicación sincronizada (Fase 7).

## 6. Glosario mínimo

| Término | Definición |
|---|---|
| Synced | El clúster coincide exactamente con lo declarado en Git |
| OutOfSync | Existe una diferencia entre Git y el clúster (drift) |
| Healthy | Los recursos funcionan y están disponibles |
| Prune | Argo CD elimina del clúster recursos que ya no están en Git |
| Self-heal | Argo CD revierte automáticamente cambios manuales hechos con `kubectl` |

## 7. Documentación operativa

Procedimiento paso a paso, comandos y resolución de problemas en [RUNBOOK.md](RUNBOOK.md).

