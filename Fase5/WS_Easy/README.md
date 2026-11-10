# Laboratorio GitOps: Gitea + KinD + Argo CD

![Argo CD](https://img.shields.io/badge/Argo%20CD-v2.10.4-EF7B4D?logo=argo&logoColor=white)
![Gitea](https://img.shields.io/badge/Gitea-1.22.0-609926?logo=gitea&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-1.25--alpine-009639?logo=nginx&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-KinD-326CE5?logo=kubernetes&logoColor=white)
![Entorno](https://img.shields.io/badge/WSL2-Ubuntu%2024.04-E95420?logo=ubuntu&logoColor=white)

Este laboratorio monta, en una sola máquina, un flujo GitOps completo: un servidor Git propio (Gitea), un clúster Kubernetes local (KinD) y Argo CD vigilando el repositorio. No usa cuentas en la nube ni tokens de GitHub. Una vez descargadas las imágenes, tampoco necesita internet.

Lo armé para enseñar una sola idea: **el clúster se parece a lo que dice Git, y si alguien lo toca a mano, Argo CD lo corrige**. Todo lo demás es andamiaje para poder verlo con los propios ojos.

---

## Qué se aprende

- Levantar un servidor Git privado con Docker Compose.
- Crear un clúster Kubernetes con KinD y conectarlo a la red de Gitea.
- Instalar Argo CD, exponerlo y entrar por el navegador.
- Declarar una `Application` que enlaza un repositorio con el clúster.
- Ver el ciclo completo: estado inicial, cambio de réplicas desde Git, deriva manual y autorreparación.
- Destruir todo y volver a empezar sin residuos.

---

## Prerequisites

![Docker](https://img.shields.io/badge/Docker-Engine%20activo-2496ED?logo=docker&logoColor=white)
![kind](https://img.shields.io/badge/kind-instalado-326CE5?logo=kubernetes&logoColor=white)
![kubectl](https://img.shields.io/badge/kubectl-instalado-326CE5?logo=kubernetes&logoColor=white)
![git](https://img.shields.io/badge/git-instalado-F05032?logo=git&logoColor=white)

| Requisito | Para qué lo uso |
| :--- | :--- |
| Windows 11 con WSL2 y Ubuntu 24.04 | Kernel Linux real con redes y cgroups completos |
| Docker Engine y plugin Compose | Corre Gitea y los nodos de KinD |
| `kind` | Crea el clúster dentro de un contenedor |
| `kubectl` | Habla con el clúster |
| `git` y `curl` | Subir el código y comprobar respuestas HTTP |
| Puertos libres: 3000, 222, 8443, 8080 | Gitea (web y SSH), Argo CD y la aplicación |
| Primera ejecución con internet | Descargar imágenes y los manifiestos de Argo CD |

---

## Estructura de directorios

Ruta base: `/home/gmt/sre-linux-mastery/Fase5/WS_Easy`

```text
WS_Easy/
├── README.md
├── runbook.md
├── infra/                    # Todo lo que es plataforma
│   ├── docker-compose.yml    # Gitea y su red Docker
│   ├── kind-config.yaml      # Clúster KinD y mapeo de puertos al host
│   └── argocd-app.yaml       # Application de Argo CD
└── repo-app/                 # El código de la aplicación; este es el repo que se sube a Gitea
    └── deployment.yaml       # Deployment y Service de Nginx
```

Separo `infra/` de `repo-app/` a propósito: `repo-app/` es lo único que vive en Git y lo único que Argo CD lee. `infra/` es lo que yo uso para montar el escenario.

---

## Vista general del flujo

Quien cambia cosas siempre hace `git push`. Argo CD hace el resto.

```mermaid
flowchart LR
    Op([Instructor]) -- git push --> G[(Gitea<br/>fuente de verdad)]
    A[Argo CD] -- lee el repo --> G
    A -- aplica manifiestos --> K[Clúster KinD]
    K -- estado real --> A

    subgraph R[Red Docker: gitops-net]
        G
        K
    end

    classDef git fill:#609926,stroke:#3d6118,color:#fff
    classDef argo fill:#EF7B4D,stroke:#b5532a,color:#fff
    classDef kube fill:#326CE5,stroke:#1f4aa8,color:#fff
    classDef human fill:#6c5ce7,stroke:#4a3fb0,color:#fff
    class G git
    class A argo
    class K kube
    class Op human
```

Orden de las fases del laboratorio:

```mermaid
flowchart LR
    F0[0. Preparación] --> F1[1. Gitea]
    F1 --> F2[2. KinD y red]
    F2 --> F3[3. Argo CD]
    F3 --> F4[4. Subir repo]
    F4 --> F5[5. Application]
    F5 --> F6[6. Estado inicial]
    F6 --> F7[7. Réplicas y drift]
    F7 --> F8[8. Destruir]

    classDef prep fill:#6c5ce7,stroke:#4a3fb0,color:#fff
    classDef run fill:#326CE5,stroke:#1f4aa8,color:#fff
    classDef demo fill:#EF7B4D,stroke:#b5532a,color:#fff
    classDef end1 fill:#d63031,stroke:#962021,color:#fff
    class F0,F1 prep
    class F2,F3,F4,F5 run
    class F6,F7 demo
    class F8 end1
```

---

## Cómo se usa el runbook

`runbook.md` es el guion de la clase. Cada fase trae, en este orden:

1. Qué vamos a lograr y por qué.
2. El comando o el archivo exacto, con su directorio.
3. La explicación de cada opción, archivo y carpeta.
4. Una comprobación que tiene que pasar antes de seguir.

Lo sigo de arriba abajo y no salto fases. Si una comprobación falla, no avanzo hasta resolverla, porque cada fase depende de la anterior.

Las fases 6 y 7 son la demostración. Las anteriores son preparación, así que conviene tenerlas listas antes de que lleguen los alumnos.

---

## Destruir y reproducir

Para borrar todo, sigo la Fase 8 del runbook. En corto:

```bash
cd /home/gmt/sre-linux-mastery/Fase5
kind delete cluster --name enterprise-gitops
docker compose -f WS_Easy/infra/docker-compose.yml down -v
rm -rf WS_Easy
```

El orden importa. Primero borro el clúster porque su nodo está conectado a la red de Gitea; si intento quitar la red antes, Docker se queja. `down -v` también borra el volumen con los datos de Gitea, así que el siguiente arranque es un Gitea limpio.

Para volver a reproducir, repito el runbook desde la Fase 0. No queda nada de la corrida anterior: ni repositorio, ni usuario, ni clúster, ni red.

