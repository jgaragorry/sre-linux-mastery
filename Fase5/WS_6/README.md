# Workshop 6 (WS_6): GitOps Multi-Entorno con ArgoCD, Kustomize y Webhooks

![Kubernetes](https://img.shields.io/badge/Kubernetes-KinD-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.10.4-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kustomize](https://img.shields.io/badge/Kustomize-Overlays-0F9D58?style=for-the-badge)
![Gitea](https://img.shields.io/badge/Gitea-Self--Hosted-609926?style=for-the-badge&logo=gitea&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Nivel](https://img.shields.io/badge/Nivel-Enterprise_SRE-8A2BE2?style=for-the-badge)

Este taller construye una plataforma GitOps completa en una sola maquina: dos entornos (**dev** y **prod**) que comparten una misma base de manifiestos, un punto de entrada unico (patron **App of Apps**) y sincronizacion casi inmediata gracias a un **webhook** que Gitea dispara en cada `git push`.

El objetivo practico es sencillo de enunciar y dificil de lograr sin disciplina: que cualquier cambio en un entorno nazca de un commit, sea revisable y se aplique solo.

---

## Tabla de contenidos

1. [Que se construye](#1-que-se-construye)
2. [Stack y justificacion](#2-stack-y-justificacion)
3. [Arquitectura general](#3-arquitectura-general)
4. [Bucle de reconciliacion de ArgoCD](#4-bucle-de-reconciliacion-de-argocd)
5. [Patron App of Apps](#5-patron-app-of-apps)
6. [Composicion con Kustomize](#6-composicion-con-kustomize)
7. [Flujo del webhook](#7-flujo-del-webhook)
8. [Estructura de directorios](#8-estructura-de-directorios)
9. [Archivos de configuracion](#9-archivos-de-configuracion)
10. [Guia de la interfaz web](#10-guia-de-la-interfaz-web)
11. [Resultado esperado](#11-resultado-esperado)
12. [Documentacion relacionada](#12-documentacion-relacionada)

---

## 1. Que se construye

| Entorno | Namespace | Replicas | Prefijo de recursos | Etiqueta `environment` |
| :--- | :--- | :---: | :--- | :--- |
| Development | `dev` | 1 | `dev-` | `development` |
| Production | `prod` | 2 (escalable via Git) | `prod-` | `production` |

Tres aplicaciones de ArgoCD gobiernan todo: `root-application`, `dev-web-app` y `prod-web-app`.

## 2. Stack y justificacion

| Componente | Rol | Por que se eligio |
| :--- | :--- | :--- |
| WSL2 con Ubuntu 24.04 LTS | Entorno base | Kernel Linux real, cgroups v2 y Docker nativo sobre Windows 11. |
| KinD | Cluster Kubernetes | Nodos certificados por la CNCF dentro de contenedores; permite exponer NodePorts al host con `extraPortMappings`. |
| Gitea | Fuente de verdad | Servidor Git liviano con API REST, sin depender de servicios externos. |
| Kustomize | Composicion declarativa | Integrado en `kubectl`; base comun mas parches por ambiente, sin plantillas. |
| ArgoCD | Reconciliador GitOps | Compara Git contra el estado vivo y corrige el drift de forma continua. |
| Webhook Gitea a ArgoCD | Disparador de eventos | Evita esperar el sondeo periodico (aprox. 3 minutos) y sincroniza en segundos. |

## 3. Arquitectura general

```mermaid
flowchart LR
    DEV([Ingeniero]):::actor -->|git push| GITEA

    subgraph NET1["Red Docker: gitops-net"]
        GITEA[("Gitea<br/>local-gitea:3000")]:::git
    end

    subgraph NET2["Red Docker: kind + gitops-net"]
        subgraph KIND["Cluster KinD: enterprise-gitops"]
            subgraph ARGO["Namespace argocd"]
                SRV[argocd-server]:::argo
                REPO[argocd-repo-server]:::argo
                CTRL[argocd-application-controller]:::argo
            end
            subgraph DEVNS["Namespace dev"]
                DEVPOD[1 Pod nginx]:::dev
            end
            subgraph PRODNS["Namespace prod"]
                PRODPOD[2 Pods nginx]:::prod
            end
        end
    end

    GITEA -.->|Webhook HTTPS<br/>/api/webhook| SRV
    SRV --> CTRL
    CTRL -->|solicita manifiestos| REPO
    REPO -->|clona y ejecuta kustomize build| GITEA
    CTRL ==>|aplica| DEVPOD
    CTRL ==>|aplica| PRODPOD

    classDef actor fill:#6C5CE7,stroke:#4B3FB5,color:#fff
    classDef git fill:#609926,stroke:#3F6B17,color:#fff
    classDef argo fill:#EF7B4D,stroke:#B85A33,color:#fff
    classDef dev fill:#00B894,stroke:#007F68,color:#fff
    classDef prod fill:#D63031,stroke:#992223,color:#fff
```

**Como leerlo.** El ingeniero solo interactua con Git. Gitea notifica a `argocd-server` por HTTPS; el controlador pide a `argocd-repo-server` que compile los manifiestos y luego aplica el resultado en los namespaces destino. La conexion del nodo KinD a `gitops-net` es lo que permite que el cluster resuelva el nombre `local-gitea` y que Gitea alcance a ArgoCD.

## 4. Bucle de reconciliacion de ArgoCD

```mermaid
flowchart TD
    A[Repositorio Git<br/>estado deseado]:::git --> B[argocd-repo-server<br/>clona y ejecuta kustomize build]:::argo
    C[Kubernetes API<br/>estado vivo]:::k8s --> D
    B --> D{argocd-application-controller<br/>compara deseado vs vivo}:::argo
    D -->|Sin diferencias| E[Synced / Healthy]:::ok
    D -->|Con diferencias| F[OutOfSync]:::warn
    F --> G[Automated Sync<br/>aplica lo que dicta Git]:::argo
    F --> H[Self-Heal<br/>revierte cambios manuales con kubectl]:::argo
    G --> E
    H --> E

    classDef git fill:#609926,stroke:#3F6B17,color:#fff
    classDef argo fill:#EF7B4D,stroke:#B85A33,color:#fff
    classDef k8s fill:#326CE5,stroke:#1F4BA8,color:#fff
    classDef ok fill:#00B894,stroke:#007F68,color:#fff
    classDef warn fill:#FDCB6E,stroke:#C79A2E,color:#333
```

Los tres servicios cumplen funciones distintas:

- **argocd-repo-server:** clona el repositorio y genera el YAML final ejecutando `kustomize build workloads/overlays/<entorno>`.
- **argocd-application-controller:** compara ese YAML con los objetos vivos en el cluster y decide si hace falta actuar.
- **argocd-server:** expone la interfaz web (puerto 8443 en el host) y recibe el webhook en `/api/webhook`.

Las politicas `prune` y `selfHeal` activadas en cada aplicacion hacen que ArgoCD elimine lo que ya no esta en Git y deshaga cualquier cambio manual.

## 5. Patron App of Apps

```mermaid
flowchart TD
    ROOT["root-application<br/>vigila la carpeta apps/"]:::root
    ROOT --> DAPP["dev-web-app<br/>apps/dev-app.yaml"]:::dev
    ROOT --> PAPP["prod-web-app<br/>apps/prod-app.yaml"]:::prod
    DAPP --> DOV["workloads/overlays/dev"]:::dev
    PAPP --> POV["workloads/overlays/prod"]:::prod
    DOV --> DNS["Namespace dev<br/>1 Pod, prefijo dev-"]:::dev
    POV --> PNS["Namespace prod<br/>2 Pods, prefijo prod-"]:::prod

    classDef root fill:#6C5CE7,stroke:#4B3FB5,color:#fff
    classDef dev fill:#00B894,stroke:#007F68,color:#fff
    classDef prod fill:#D63031,stroke:#992223,color:#fff
```

Solo la `root-application` se aplica a mano, una unica vez. Todo lo demas se descubre desde Git: agregar un entorno nuevo es agregar un archivo en `apps/`.

## 6. Composicion con Kustomize

```mermaid
flowchart LR
    BASE["base/<br/>deployment.yaml<br/>service.yaml<br/>kustomization.yaml"]:::base
    BASE --> OD["overlays/dev<br/>namespace dev<br/>namePrefix dev-<br/>label development"]:::dev
    BASE --> OP["overlays/prod<br/>namespace prod<br/>namePrefix prod-<br/>label production<br/>patch: replicas 2"]:::prod
    OD --> RD["Manifiestos finales dev"]:::dev
    OP --> RP["Manifiestos finales prod"]:::prod

    classDef base fill:#0984E3,stroke:#0652A0,color:#fff
    classDef dev fill:#00B894,stroke:#007F68,color:#fff
    classDef prod fill:#D63031,stroke:#992223,color:#fff
```

La base se escribe una sola vez (principio DRY). Cada overlay agrega solo lo que cambia: el namespace, el prefijo de nombres, las etiquetas y, en produccion, un parche que fija las replicas.

## 7. Flujo del webhook

```mermaid
sequenceDiagram
    autonumber
    actor Ing as Ingeniero
    participant G as Gitea
    participant S as argocd-server
    participant R as argocd-repo-server
    participant C as application-controller
    participant K as Kubernetes API

    Ing->>G: git push origin main
    G->>S: POST /api/webhook (HTTPS, firmado con secreto)
    S->>S: Valida el secreto compartido
    S->>C: Refresca las aplicaciones afectadas
    C->>R: Solicita manifiestos del commit nuevo
    R->>G: Clona y ejecuta kustomize build
    R-->>C: YAML renderizado
    C->>K: Aplica el delta (por ejemplo, replicas 2 a 4)
    K-->>C: Estado vivo actualizado
    C-->>S: Synced / Healthy
```

## 8. Estructura de directorios

```text
/home/gmt/sre-linux-mastery/Fase5/WS_6/
├── README.md                        Arquitectura y guia conceptual
├── RUNBOOK.md                       Procedimiento operativo paso a paso
├── infra/
│   └── root-app.yaml                Aplicacion raiz (bootstrap del App of Apps)
└── repo-gitops/                     Repositorio Git local publicado en Gitea
    ├── apps/                        Definiciones de Application (CRD de ArgoCD)
    │   ├── dev-app.yaml
    │   └── prod-app.yaml
    └── workloads/
        ├── base/                    Manifiestos comunes, sin conocimiento de entorno
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── kustomization.yaml
        └── overlays/                Personalizacion por entorno
            ├── dev/
            │   └── kustomization.yaml
            └── prod/
                ├── kustomization.yaml
                └── replicas-patch.yaml
```

## 9. Archivos de configuracion

| Archivo | Tipo de recurso | Funcion |
| :--- | :--- | :--- |
| `infra/root-app.yaml` | `Application` | Apunta a `apps/` y crea las aplicaciones hijas. Es lo unico que se aplica con `kubectl`. |
| `apps/dev-app.yaml` | `Application` | Despliega `workloads/overlays/dev` en el namespace `dev`. |
| `apps/prod-app.yaml` | `Application` | Despliega `workloads/overlays/prod` en el namespace `prod`. |
| `workloads/base/deployment.yaml` | `Deployment` | Define `web-app` con `nginx:1.25-alpine`, 1 replica, puerto 80. |
| `workloads/base/service.yaml` | `Service` | `web-service` tipo ClusterIP hacia el puerto 80. |
| `workloads/base/kustomization.yaml` | `Kustomization` | Lista los recursos que forman la base. |
| `overlays/dev/kustomization.yaml` | `Kustomization` | Namespace `dev`, prefijo `dev-`, etiqueta `development`. |
| `overlays/prod/kustomization.yaml` | `Kustomization` | Namespace `prod`, prefijo `prod-`, etiqueta `production`, referencia al parche. |
| `overlays/prod/replicas-patch.yaml` | Parche estrategico | Sobrescribe unicamente `spec.replicas`. |

Directivas clave de las `Application`:

| Directiva | Efecto |
| :--- | :--- |
| `syncPolicy.automated.prune` | Elimina del cluster lo que desaparece de Git. |
| `syncPolicy.automated.selfHeal` | Revierte modificaciones manuales sobre recursos gestionados. |
| `syncOptions: CreateNamespace=true` | Crea el namespace destino si no existe. |
| `finalizers: resources-finalizer.argocd.argoproj.io` | Borrado en cascada: al eliminar la aplicacion se eliminan sus recursos. |

## 10. Guia de la interfaz web

Acceso: `https://localhost:8443` (el certificado es autofirmado, hay que aceptar la advertencia). Usuario `admin`; la contrasena inicial esta en el Secret `argocd-initial-admin-secret`.

| Vista | Que muestra | Cuando consultarla |
| :--- | :--- | :--- |
| Dashboard de aplicaciones | Estado de sincronizacion (Synced, OutOfSync) y de salud (Healthy, Progressing, Degraded) por aplicacion. | Primera revision tras cada cambio. |
| Resource Tree | Jerarquia Application, Deployment, ReplicaSet, Pod. Cada Pod ofrece resumen, logs y eventos. | Diagnosticar por que un Pod no arranca. |
| App Diff | Diferencia entre lo que declara Git y lo que existe en el cluster. | Confirmar que un cambio manual fue detectado. |
| Sync Status / History | Commit desplegado y historial de revisiones. | Auditoria y rollback. |

## 11. Resultado esperado

```mermaid
flowchart LR
    P1[Edicion de replicas-patch.yaml<br/>2 a 4]:::a --> P2[git commit y git push]:::b --> P3[Webhook]:::c --> P4[Sincronizacion]:::d --> P5[prod: 4/4 Pods listos]:::e

    classDef a fill:#0984E3,color:#fff,stroke:#0652A0
    classDef b fill:#609926,color:#fff,stroke:#3F6B17
    classDef c fill:#EF7B4D,color:#fff,stroke:#B85A33
    classDef d fill:#6C5CE7,color:#fff,stroke:#4B3FB5
    classDef e fill:#00B894,color:#fff,stroke:#007F68
```

Al terminar el taller, un cambio de replicas en Git se refleja en el cluster en pocos segundos y sin ejecutar ningun comando contra Kubernetes.

## 12. Documentacion relacionada

- [`RUNBOOK.md`](./RUNBOOK.md): procedimiento operativo completo, con la explicacion de cada comando, verificaciones y resolucion de problemas.

