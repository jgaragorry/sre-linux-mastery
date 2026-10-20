<div align="center">

# Runbook: Laboratorio 2, Argo CD con Repositorio Propio

![Fases](https://img.shields.io/badge/Fases-11-EF7B4D?style=for-the-badge)
![Riesgo](https://img.shields.io/badge/Riesgo-Bajo%20(local)-2EA44F?style=for-the-badge)
![Diagramas](https://img.shields.io/badge/Diagramas-Mermaid-8250DF?style=for-the-badge)

</div>

---

## Convenciones

* `${USUARIO}`: tu usuario de GitHub. Se define una sola vez al inicio (Fase 1) como variable de entorno.
* Los bloques **Comando** se ejecutan en WSL2.
* Los bloques **Validación** indican qué debes ver antes de avanzar a la siguiente fase.
* Los bloques **Anatomía del diagrama** explican, componente por componente, qué representa cada elemento del diagrama de la fase.
* Si cierras la terminal y la reabres, vuelve a ejecutar `export USUARIO=...` antes de continuar.

---

## Guía de lectura de los diagramas

Todos los diagramas de este runbook usan la misma paleta de colores y las mismas formas, para que una vez que aprendas a leer uno, puedas leer todos.

### Paleta de colores

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef secret fill:#BF8700,stroke:#7D5A00,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px
    classDef danger fill:#CF222E,stroke:#82071E,color:#fff,stroke-width:2px

    L1["Comando o acción tuya"]:::cmd ~~~ L2["Recurso de Kubernetes"]:::k8s ~~~ L3["Componente de Argo CD"]:::argo ~~~ L4["Git / GitHub"]:::git
    L5["Credencial o Secret"]:::secret ~~~ L6(["Resultado correcto"]):::ok ~~~ L7["Se elimina o es riesgo"]:::danger
```

| Color | Significa | Ejemplos en este lab |
| :--- | :--- | :--- |
| Gris | Comando o acción que ejecutas tú | `kubectl apply`, `git push` |
| Azul | Recurso o componente nativo de Kubernetes | Deployment, Service, API server |
| Naranja | Componente propio de Argo CD | repo-server, application-controller |
| Morado | Git y GitHub | Repositorio, commits |
| Amarillo | Credenciales y secretos | Llave SSH, Secret |
| Verde | Resultado esperado o validación exitosa | Nodo `Ready`, app `Synced` |
| Rojo | Algo que se elimina o que implica riesgo | Service borrado por `prune` |

### Formas y flechas

| Elemento | Notación Mermaid | Significado |
| :--- | :--- | :--- |
| Rectángulo | `A["texto"]` | Componente, comando o recurso |
| Cilindro | `A[("texto")]` | Almacenamiento: repositorio, Secret, caché |
| Píldora (stadium) | `A(["texto"])` | Resultado o punto de validación |
| Flecha sólida `-->` | | Flujo normal de ejecución |
| Flecha gruesa `==>` | | Flujo principal del ciclo GitOps |
| Flecha punteada `-.->` | | Lectura, consulta o relación indirecta (no modifica nada) |
| Caja con título (subgraph) | `subgraph ... end` | Frontera: un namespace, un clúster, un servicio externo |

---

## Vista general de la arquitectura

Antes de entrar a las fases, este es el mapa completo de lo que vas a construir. Vuelve a este diagrama cuando te pierdas en alguna fase.

```mermaid
flowchart TB
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef secret fill:#BF8700,stroke:#7D5A00,color:#fff,stroke-width:2px

    DEV["Tú en WSL2<br/>git + kubectl"]:::cmd

    subgraph GH["GitHub (nube)"]
        REPO[("Repo mi-app-argocd<br/>deployment.yaml<br/>service.yaml<br/>configmap.yaml")]:::git
        DK["Deploy key<br/>llave pública, solo lectura"]:::secret
    end

    subgraph KIND["Docker: clúster kind argocd-lab2"]
        API["kube-apiserver<br/>puerta de entrada"]:::k8s

        subgraph NSA["namespace argocd"]
            SRV["argocd-server<br/>UI y API"]:::argo
            RS["argocd-repo-server<br/>clona y renderiza"]:::argo
            CTRL["application-controller<br/>compara y sincroniza"]:::argo
            REDIS[("redis<br/>caché")]:::argo
            SEC[("Secret mi-app-repo-ssh<br/>llave privada")]:::secret
            APP["Application mi-app<br/>qué desplegar y dónde"]:::argo
        end

        subgraph NSM["namespace mi-app"]
            DEP["Deployment<br/>2 réplicas nginx"]:::k8s
            SVC["Service"]:::k8s
            CM["ConfigMap"]:::k8s
        end
    end

    DEV == "git push" ==> REPO
    DEV -- "kubectl / navegador" --> API
    API --- SRV
    SEC -.->|"credencial"| RS
    DK -.->|"par de llaves"| SEC
    RS -.->|"git clone por SSH"| REPO
    RS --> CTRL
    APP -.->|"le dice qué vigilar"| CTRL
    CTRL ==>|"aplica diferencias"| API
    API --> NSM
    SRV --- REDIS
    CTRL --- REDIS
```

**Anatomía del diagrama**

| Componente | Qué es | Qué hace en este laboratorio |
| :--- | :--- | :--- |
| **Tú en WSL2** | Tu terminal con `git` y `kubectl` | Haces `git push` hacia GitHub y comandos `kubectl` hacia el clúster. Nunca despliegas la app directamente. |
| **Repo mi-app-argocd** | Repositorio Git remoto | Es la **fuente de verdad**: describe el estado deseado del clúster. |
| **Deploy key** | Llave SSH pública registrada en GitHub | Autoriza a Argo CD a **leer** (no escribir) el repo. |
| **kind argocd-lab2** | Kubernetes dentro de un contenedor Docker | Clúster desechable, ideal para aprender sin riesgo. |
| **kube-apiserver** | API central de Kubernetes | Todo pasa por aquí: `kubectl`, Argo CD y la UI. |
| **argocd-server** | Servidor de Argo CD | Sirve la UI web y la API que usas con el navegador. |
| **argocd-repo-server** | Servicio que accede a Git | Clona el repo, lee los YAML y genera los manifiestos finales. |
| **application-controller** | El "cerebro" de Argo CD | Compara el estado deseado (Git) contra el real (clúster) y corrige las diferencias. |
| **redis** | Base de datos en memoria | Caché para acelerar consultas. No guarda datos críticos. |
| **Secret mi-app-repo-ssh** | Secret de Kubernetes | Guarda la llave privada que Argo CD usa para entrar a GitHub. |
| **Application mi-app** | Recurso personalizado (CRD) de Argo CD | Une un repositorio (origen) con un namespace del clúster (destino). |
| **namespace mi-app** | Espacio de nombres destino | Aquí viven los recursos que Argo CD despliega a partir de Git. |

---

## Fase 1. Crear el clúster kind

**Objetivo:** Disponer de un Kubernetes local desechable con el nombre exacto que usará el resto del laboratorio.

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    D["docker ps<br/>¿Docker activo?"]:::cmd --> C["kind create cluster<br/>--name argocd-lab2"]:::cmd

    subgraph DOCKER["Docker Engine"]
        N["Contenedor<br/>argocd-lab2-control-plane"]:::k8s
        subgraph INSIDE["Dentro del contenedor"]
            CP["Control plane<br/>apiserver, etcd, scheduler"]:::k8s
            KL["kubelet + containerd"]:::k8s
        end
    end

    C ==> N
    N --- CP
    N --- KL
    C --> CTX["kubeconfig<br/>contexto kind-argocd-lab2"]:::cmd
    CTX --> V(["kubectl get nodes<br/>Nodo Ready"]):::ok
```

**Anatomía del diagrama**

| Componente | Qué es | Por qué importa |
| :--- | :--- | :--- |
| **docker ps** | Comprobación de que el motor Docker responde | kind necesita Docker; si falla, nada más funcionará. |
| **kind create cluster** | Herramienta que crea un clúster Kubernetes | "kind" significa *Kubernetes IN Docker*. |
| **Contenedor control-plane** | Un único contenedor que actúa como nodo | Es el "servidor" completo de tu clúster. |
| **Control plane** | Componentes que gobiernan el clúster | El apiserver recibe órdenes, etcd guarda el estado, el scheduler decide dónde corre cada pod. |
| **kubelet + containerd** | Agente del nodo y runtime de contenedores | Ejecutan realmente los pods dentro del nodo. |
| **kubeconfig / contexto** | Archivo que le dice a `kubectl` a qué clúster hablar | `kubectl config use-context` evita aplicar comandos al clúster equivocado. |
| **Nodo Ready** | Estado de salud del nodo | Es tu señal de "puedes continuar". |

**Comando:**

```bash
# 0. Definir tu usuario de GitHub (cámbialo por el tuyo)
export USUARIO=jgaragorry

# 1. Verificar que Docker esté corriendo (si falla, inicia Docker Desktop)
docker ps

# 2. Crear la estructura de directorios base
mkdir -p ~/argocd-lab-2/{manifests,repo-git}
cd ~/argocd-lab-2

# 3. Crear el clúster
kind create cluster --name argocd-lab2
kubectl config use-context kind-argocd-lab2
```

**Validación:** `kubectl get nodes` muestra un nodo llamado `argocd-lab2-control-plane` en estado `Ready`.

---

## Fase 2. Instalar Argo CD

**Objetivo:** Desplegar los componentes de Argo CD en el namespace `argocd`.

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    M["install.yaml<br/>manifiesto oficial en GitHub"]:::cmd
    K["kubectl apply<br/>--server-side"]:::cmd
    API["kube-apiserver"]:::k8s

    M --> K ==> API

    API --> CRD["3 CRDs<br/>Application, AppProject, ApplicationSet"]:::k8s

    subgraph NS["namespace argocd"]
        S["argocd-server"]:::argo
        R["argocd-repo-server"]:::argo
        AC["application-controller<br/>StatefulSet"]:::argo
        AS["applicationset-controller"]:::argo
        DX["dex-server"]:::argo
        NT["notifications-controller"]:::argo
        RD[("redis")]:::argo
    end

    API --> NS
    NS --> W["kubectl wait<br/>Deployments Available<br/>rollout status del StatefulSet"]:::cmd
    W --> V(["Pods en Running"]):::ok
```

**Anatomía del diagrama**

| Componente | Qué es | Por qué importa |
| :--- | :--- | :--- |
| **install.yaml** | Manifiesto oficial que define todo Argo CD | Una sola URL instala todos los componentes. |
| **`--server-side`** | Modo de aplicación donde el servidor calcula los cambios | Los CRDs de Argo CD son tan grandes que el modo normal falla por exceder el límite de anotaciones. |
| **3 CRDs** | Extensiones que "enseñan" nuevos tipos de recurso a Kubernetes | Sin ellas, Kubernetes no entendería qué es una `Application`. |
| **argocd-server** | Deployment con la UI y la API | Lo que abres en el navegador. |
| **argocd-repo-server** | Deployment que clona repositorios | Es el único componente que habla con Git. |
| **application-controller** | StatefulSet (por eso se espera con `rollout status`) | Ejecuta el bucle de reconciliación. |
| **applicationset-controller** | Genera múltiples Applications desde plantillas | No lo usamos en este lab, pero se instala por defecto. |
| **dex-server** | Proveedor de identidad (SSO) | Opcional; no se usa en este lab. |
| **notifications-controller** | Envía alertas (Slack, email) | No se usa en este lab. |
| **redis** | Caché en memoria | Acelera la UI y la comparación de estados. |
| **kubectl wait** | Espera activa hasta que los Deployments estén `Available` | Evita que sigas antes de tiempo. No se usa `pods --all` porque pods auxiliares pueden terminar en `Completed` y nunca ser `Ready`. |

**Comando:**

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> **Nota:** el flag `--server-side` es obligatorio porque los CRDs de Argo CD son muy grandes.

Esperar a que los componentes estén listos:

```bash
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
```

> Se espera por `Deployment` y `StatefulSet` en lugar de `pods --all`, porque algunos pods auxiliares pueden terminar en `Completed` y nunca llegan a `Ready`, lo que haría fallar el `wait` por timeout.

**Validación:** `kubectl get pods -n argocd` muestra los pods principales (server, repo-server, application-controller, applicationset-controller, redis, dex, notifications) en estado `Running`.

---

## Fase 3. Acceder a la UI

**Objetivo:** Obtener la contraseña de administrador y exponer la interfaz web.

```mermaid
sequenceDiagram
    autonumber
    actor U as Tú
    participant T as Terminal 1<br/>kubectl port-forward
    participant B as Navegador<br/>localhost:8080
    participant A as kube-apiserver
    participant SV as Service<br/>argocd-server
    participant P as Pod<br/>argocd-server

    rect rgba(191,135,0,0.18)
        Note over U,A: Parte 1: obtener la contraseña
        U->>A: kubectl get secret argocd-initial-admin-secret
        A-->>U: password en base64
        U->>U: base64 -d (texto plano)
    end

    rect rgba(50,108,229,0.15)
        Note over U,P: Parte 2: abrir el túnel
        U->>T: kubectl port-forward 8080:443
        T->>A: abre un túnel hacia el Service
        A->>SV: reenvía al puerto 443
        SV->>P: entrega al pod
    end

    rect rgba(46,164,79,0.15)
        Note over B,P: Parte 3: usar la UI
        B->>T: https://localhost:8080
        T->>P: tráfico por el túnel
        P-->>B: pantalla de login
        B->>P: usuario admin + contraseña
        P-->>B: UI de Argo CD
    end
```

**Anatomía del diagrama**

| Elemento | Qué representa | Detalle importante |
| :--- | :--- | :--- |
| **Participante "Tú"** (actor) | La persona que opera | Inicia todos los pasos. |
| **Terminal 1** | Proceso `kubectl port-forward` | Debe quedar **abierto**; si lo cierras (Ctrl+C), pierdes el acceso a la UI. |
| **Navegador** | Tu cliente web | Habla con `localhost`, no directamente con el clúster. |
| **kube-apiserver** | Intermediario del túnel | El port-forward viaja a través de la API de Kubernetes. |
| **Service argocd-server** | Dirección interna estable | Los pods cambian de IP; el Service no. |
| **Pod argocd-server** | El proceso que sirve la UI | Destino final del tráfico. |
| **Bloque amarillo** | Obtención de la contraseña | El Secret guarda la clave en base64 (codificación, no cifrado). |
| **Bloque azul** | Creación del túnel | Une `localhost:8080` con el puerto 443 del Service. |
| **Bloque verde** | Uso normal de la UI | Aquí aceptas la advertencia del certificado autofirmado. |
| **Números (autonumber)** | Orden cronológico | Léelos de 1 hacia abajo. |

**Comando (Terminal 1, mantener abierta):**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

> **Nota:** si `port-forward` falla con `Unable to listen on port 8080`, otro servicio en WSL (como cAdvisor o Grafana) está usando ese puerto. Cambia el puerto local:
> `kubectl port-forward svc/argocd-server -n argocd 9090:443`
> y accede a `https://localhost:9090`.

**Validación:** Abrir `https://localhost:8080` (aceptar la advertencia de certificado) e ingresar con usuario `admin` y la contraseña obtenida.

> Desde aquí, usa una **segunda terminal** (Terminal 2) para el resto de las fases. Recuerda ejecutar `export USUARIO=...` en ella.

---

## Fase 4. Crear repositorio propio y publicar en GitHub

**Objetivo:** Construir el estado deseado (manifiestos) y subirlo a tu repositorio remoto.

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    subgraph LOCAL["Tu máquina: ~/argocd-lab-2/repo-git"]
        direction LR
        F1["deployment.yaml"]:::k8s
        F2["service.yaml"]:::k8s
        F3["configmap.yaml"]:::k8s
        F4[".gitignore"]:::cmd
        WD["Working directory<br/>archivos sueltos"]:::cmd
        ST["Staging area<br/>lo que irá al commit"]:::git
        LR1[("Repo local<br/>rama main")]:::git
        F1 & F2 & F3 & F4 --> WD
        WD -->|"git add ."| ST
        ST -->|"git commit"| LR1
    end

    subgraph REMOTE["GitHub"]
        RR[("origin<br/>mi-app-argocd")]:::git
    end

    LR1 ==>|"git push -u origin main"| RR
    RR --> V(["Archivos visibles en GitHub"]):::ok
```

**Anatomía del diagrama**

| Componente | Qué es | Rol en GitOps |
| :--- | :--- | :--- |
| **deployment.yaml** | Describe los pods de la app | Define imagen (`nginx:1.25-alpine`) y réplicas (2). |
| **service.yaml** | Describe cómo se accede a los pods | Es el recurso que eliminaremos y restauraremos en las fases 9 y 10. |
| **configmap.yaml** | Datos de configuración clave-valor | Muestra que Argo CD también gestiona configuración. |
| **.gitignore** | Lista de archivos que Git debe ignorar | Evita subir temporales (`*.swp`, `.env`). |
| **Working directory** | Carpeta de trabajo con archivos editables | Git aún no los sigue. |
| **Staging area** | Zona intermedia de `git add` | Te deja elegir qué entra en el próximo commit. |
| **Repo local (main)** | Historial de commits en tu disco | Aún no existe en GitHub. |
| **origin** | Nombre del repositorio remoto | Alias para `git@github.com:USUARIO/mi-app-argocd.git`. |
| **git push -u** | Sube commits y enlaza `main` local con `origin/main` | El `-u` evita repetir el destino en futuros `git push`. |

**Comando:**

```bash
cd ~/argocd-lab-2/repo-git

# 1. Crear los manifiestos
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mi-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mi-app
  template:
    metadata:
      labels:
        app: mi-app
    spec:
      containers:
        - name: mi-app
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
EOF

cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mi-app
spec:
  selector:
    app: mi-app
  ports:
    - port: 80
      targetPort: 80
EOF

cat > configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mi-app-config
data:
  ambiente: "laboratorio"
  version: "v1"
EOF

# 2. Crear archivo .gitignore para evitar subir archivos temporales
cat > .gitignore <<'EOF'
*.swp
.DS_Store
.env
EOF

# 3. Inicializar Git y hacer commit
git init
git add .
git commit -m "feat: manifiestos iniciales"
git branch -M main
```

**Publicar en GitHub:**

> **Requisito previo:** antes de ejecutar estos comandos, ve a GitHub y crea un repositorio vacío llamado `mi-app-argocd` (sin README, sin `.gitignore`, sin licencia).

```bash
git remote add origin git@github.com:${USUARIO}/mi-app-argocd.git
git push -u origin main
```

**Validación:** Los 3 archivos YAML y el `.gitignore` son visibles en `https://github.com/${USUARIO}/mi-app-argocd`.

---

## Fase 5. Registrar credencial SSH en Argo CD

**Objetivo:** Dar acceso de **solo lectura** a Argo CD para que pueda clonar tu repositorio. Argo CD no usa tu llave SSH local; necesita la suya propia, guardada en un Secret.

```mermaid
flowchart TB
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef secret fill:#BF8700,stroke:#7D5A00,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    KG["ssh-keygen -t ed25519<br/>-N vacío"]:::cmd
    PRIV["argocd_lab2<br/>llave PRIVADA"]:::secret
    PUB["argocd_lab2.pub<br/>llave PÚBLICA"]:::secret

    KG --> PRIV
    KG --> PUB

    subgraph GH["GitHub"]
        DK["Deploy key<br/>solo lectura"]:::git
        RP[("mi-app-argocd")]:::git
        DK -.->|"autoriza lectura"| RP
    end

    subgraph CL["Clúster: namespace argocd"]
        SEC[("Secret mi-app-repo-ssh<br/>label: secret-type=repository")]:::secret
        RS["argocd-repo-server"]:::argo
        SEC -.->|"Argo CD detecta el label"| RS
    end

    PUB -->|"pegar en Settings, Deploy keys"| DK
    PRIV -->|"kubectl create secret<br/>--from-file"| SEC
    RS ==>|"git clone por SSH<br/>presenta la llave privada"| RP
    RP --> V(["Settings, Repositories<br/>estado Successful"]):::ok
```

**Anatomía del diagrama**

| Componente | Qué es | Detalle importante |
| :--- | :--- | :--- |
| **ssh-keygen -N ""** | Genera un par de llaves sin passphrase | Argo CD no puede escribir una contraseña, por eso la llave debe ir sin ella. |
| **Llave privada** | Tu "contraseña" secreta | **Nunca** se sube a GitHub ni a Git. Solo vive en el Secret. |
| **Llave pública** | Candado que acompaña a la privada | Se registra en GitHub; no es secreta. |
| **Deploy key** | Llave pública atada a **un solo repositorio** | Más segura que tu llave personal: solo lectura y un solo repo. |
| **Secret mi-app-repo-ssh** | Contenedor Kubernetes de la credencial | Incluye `type=git`, `url` y `sshPrivateKey`. |
| **Label `argocd.argoproj.io/secret-type=repository`** | Etiqueta que activa el Secret | Sin ella, Argo CD **ignora** el Secret. |
| **argocd-repo-server** | Quien usa la credencial | Presenta la llave privada a GitHub; GitHub la valida contra la pública. |
| **Flechas punteadas** | Relaciones de autorización | No transportan datos; indican "quién autoriza a quién". |
| **Successful** | Estado de conexión en la UI | Confirma que la autenticación SSH funciona. |

**Paso 1. Crear una llave dedicada, sin passphrase** (Argo CD no puede pedir una contraseña):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/argocd_lab2 -N "" -C "argocd-lab2"
cat ~/.ssh/argocd_lab2.pub
```

**Paso 2. Registrar la llave pública como Deploy key en GitHub:**

1. Abre `https://github.com/${USUARIO}/mi-app-argocd/settings/keys`.
2. Pulsa **Add deploy key**.
3. Pega la salida del `cat` anterior. Título: `argocd-lab2`.
4. **No marques** "Allow write access" (debe quedar de solo lectura).

**Paso 3. Crear el Secret en el clúster:**

```bash
kubectl create secret generic mi-app-repo-ssh \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:${USUARIO}/mi-app-argocd.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd_lab2

kubectl label secret mi-app-repo-ssh -n argocd argocd.argoproj.io/secret-type=repository
```

**Validación:** En la UI de Argo CD, ve a **Settings > Repositories**. Debes ver tu repo con estado `Successful`.

---

## Fase 6. Crear la Application

**Objetivo:** Unir el repositorio (Fase 4) con el clúster (Fase 1).

```mermaid
flowchart LR
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    subgraph APPCR["Application mi-app (archivo mi-app.yaml)"]
        direction TB
        SRC["spec.source<br/>repoURL, targetRevision: main, path: ."]:::argo
        DST["spec.destination<br/>server: kubernetes.default.svc<br/>namespace: mi-app"]:::argo
        POL["spec.syncPolicy.automated<br/>prune: true, selfHeal: true"]:::argo
        OPT["syncOptions<br/>CreateNamespace=true"]:::argo
        FIN["finalizer<br/>resources-finalizer"]:::argo
    end

    GIT[("ORIGEN<br/>GitHub: mi-app-argocd<br/>rama main, carpeta raíz")]:::git
    CLU["DESTINO<br/>Clúster actual<br/>namespace mi-app"]:::k8s

    SRC -.->|"lee desde"| GIT
    DST -.->|"despliega en"| CLU
    POL -->|"sincroniza solo, borra lo huérfano, repara deriva"| CLU
    OPT -->|"crea el namespace si no existe"| CLU
    FIN -->|"al borrar la Application, borra sus recursos"| CLU
    CLU --> V(["Synced y Healthy"]):::ok
```

**Anatomía del diagrama**

| Campo de la Application | Qué hace | Qué pasa si lo cambias |
| :--- | :--- | :--- |
| **`spec.source.repoURL`** | URL SSH del repo | Si no coincide con la del Secret (Fase 5), falla la autenticación. |
| **`targetRevision: main`** | Rama o tag a vigilar | Podrías apuntar a otra rama para probar cambios sin afectar `main`. |
| **`path: .`** | Carpeta del repo con los YAML | Si tus manifiestos estuvieran en `k8s/`, aquí iría `k8s`. |
| **`destination.server`** | API del clúster destino | `https://kubernetes.default.svc` significa "este mismo clúster". |
| **`destination.namespace`** | Namespace donde se crean los recursos | Aquí `mi-app`. |
| **`automated`** | Sincroniza sin intervención humana | Sin él, tendrías que pulsar "Sync" a mano. |
| **`prune: true`** | Borra del clúster lo que ya no está en Git | Es lo que prueba la Fase 9, prueba A. |
| **`selfHeal: true`** | Revierte cambios manuales en el clúster | Es lo que prueba la Fase 9, prueba B. |
| **`CreateNamespace=true`** | Crea el namespace destino si no existe | Evita crearlo a mano. |
| **`finalizers`** | Ejecuta limpieza al borrar la Application | Borra también los recursos desplegados (útil en el lab; en producción hay que usarlo con cuidado). |

**Estados que verás en la UI** (son dos ejes independientes: *sincronización* y *salud*):

```mermaid
stateDiagram-v2
    direction LR
    [*] --> OutOfSync: Application recién creada
    OutOfSync --> Syncing: automated detecta la diferencia
    Syncing --> Synced: recursos aplicados
    Synced --> OutOfSync: cambio nuevo en Git
    Synced --> OutOfSync: cambio manual en el clúster
    OutOfSync --> Synced: selfHeal o prune corrige
    Synced --> [*]: Application eliminada
```

| Estado | Significa |
| :--- | :--- |
| **OutOfSync** | El clúster no coincide con Git. |
| **Syncing** | Argo CD está aplicando los cambios. |
| **Synced** | El clúster coincide con Git. |
| **Healthy** (eje aparte) | Los recursos funcionan: pods `Running`, Deployment disponible. Una app puede estar `Synced` pero `Degraded` si el pod falla. |

**Comando** (el `EOF` va **sin comillas** para que `${USUARIO}` se expanda):

```bash
cat > ~/argocd-lab-2/manifests/mi-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mi-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:${USUARIO}/mi-app-argocd.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: mi-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

kubectl apply -f ~/argocd-lab-2/manifests/mi-app.yaml
```

**Validación:** `kubectl get application mi-app -n argocd` muestra `Synced` y `Healthy`.

---

## Fase 7. Verificar despliegue

**Objetivo:** Confirmar que lo que está en Git ya existe en el clúster.

```mermaid
flowchart TB
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    subgraph G["Git: estado deseado"]
        Y1["deployment.yaml<br/>replicas: 2"]:::git
        Y2["service.yaml"]:::git
        Y3["configmap.yaml"]:::git
    end

    ARGO["Argo CD<br/>repo-server + controller"]:::argo

    subgraph NS["namespace mi-app: estado real"]
        D["Deployment mi-app"]:::k8s
        RS["ReplicaSet<br/>mantiene 2 pods vivos"]:::k8s
        P1["Pod 1<br/>nginx"]:::k8s
        P2["Pod 2<br/>nginx"]:::k8s
        S["Service mi-app<br/>IP estable"]:::k8s
        C["ConfigMap<br/>mi-app-config"]:::k8s
        D --> RS
        RS --> P1
        RS --> P2
        S -.->|"selector app: mi-app"| P1
        S -.->|"selector app: mi-app"| P2
    end

    Y1 ==> ARGO
    Y2 ==> ARGO
    Y3 ==> ARGO
    ARGO ==> D
    ARGO ==> S
    ARGO ==> C
    P1 --> V(["2 pods Running"]):::ok
    P2 --> V
```

**Anatomía del diagrama**

| Componente | Qué es | Relación con los demás |
| :--- | :--- | :--- |
| **Estado deseado (Git)** | Los 3 YAML del repositorio | Lo que **debería** existir. |
| **Estado real (namespace)** | Recursos vivos en el clúster | Lo que **existe** de verdad. |
| **Deployment** | Declara "quiero 2 réplicas de nginx" | Crea y gestiona al ReplicaSet. |
| **ReplicaSet** | Vigila que haya exactamente N pods | Si un pod muere, crea otro. |
| **Pods** | Contenedores nginx en ejecución | Quienes realmente sirven la aplicación. |
| **Service** | Dirección estable hacia los pods | Los encuentra por la etiqueta `app: mi-app`, no por IP. |
| **ConfigMap** | Datos de configuración | Existe en el clúster, aunque la app de ejemplo no lo consuma. |
| **Flechas gruesas** | Despliegue gestionado por Argo CD | Tú no ejecutaste `kubectl apply` de estos recursos. |

**Comando:**

```bash
kubectl get pods -n mi-app
```

**Validación:** Deben verse 2 pods de nginx en estado `Running`.

---

## Fase 8. Cambio en Git y medición de latencia

**Objetivo:** Demostrar que el clúster reacciona a un cambio hecho puramente en Git.

```mermaid
sequenceDiagram
    autonumber
    actor U as Tú
    participant G as GitHub
    participant RS as repo-server
    participant C as application-controller
    participant A as kube-apiserver
    participant D as Deployment mi-app

    rect rgba(130,80,223,0.15)
        Note over U,G: Cambio de estado deseado
        U->>U: sed: replicas 2 a 5
        U->>G: git commit y git push
    end

    alt Sin intervención: sondeo automático
        Note over RS,C: Argo CD revisa Git cada ~3 minutos
        C->>RS: ¿hay cambios?
    else Con refresh=hard: reacción inmediata
        U->>C: kubectl annotate application refresh=hard
        Note over U,C: Fuerza revisión y descarta la caché
        C->>RS: ¿hay cambios? (sin caché)
    end

    rect rgba(239,123,77,0.15)
        Note over RS,C: Detección de la diferencia
        RS->>G: git fetch por SSH
        G-->>RS: commit nuevo
        RS-->>C: manifiestos: replicas 5
        C->>C: compara Git (5) contra clúster (2)
        Note over C: Estado: OutOfSync
    end

    rect rgba(46,164,79,0.15)
        Note over C,D: Sincronización automática
        C->>A: aplica Deployment con replicas 5
        A->>D: escala de 2 a 5 pods
        D-->>C: 5 pods Running
        Note over C: Estado: Synced y Healthy
    end

    U->>D: kubectl get pods (5 pods)
```

**Anatomía del diagrama**

| Elemento | Qué representa | Aprendizaje clave |
| :--- | :--- | :--- |
| **Bloque morado** | Tu cambio en Git | Es la **única** acción humana. No tocas el clúster. |
| **Bloque `alt` / `else`** | Dos caminos posibles | Muestra que hay un camino lento (sondeo) y uno rápido (`refresh=hard`). |
| **Sondeo cada ~3 min** | Comportamiento por defecto | Por eso sin forzar tendrías que esperar. |
| **`refresh=hard`** | Anotación que fuerza la revisión inmediata | Solo acelera la **detección**; la sincronización la hace la política `automated`. |
| **Bloque naranja** | Detección del desvío | El repo-server renderiza; el controller compara. |
| **Bloque verde** | Corrección | El controller aplica el estado deseado al clúster. |
| **Flechas `->>` y `-->>`** | Petición (sólida) y respuesta (punteada) | Léelas como "pregunta" y "respuesta". |
| **Nota "OutOfSync"** | Estado transitorio | Dura unos segundos entre detectar y aplicar. |

**Comando** (para forzar la reacción rápida):

```bash
cd ~/argocd-lab-2/repo-git
sed -i 's/replicas: 2/replicas: 5/' deployment.yaml
git commit -am "feat: escalar a 5 replicas" && git push

# Forzar a Argo CD a revisar AHORA (si no, esperar ~3 min)
kubectl annotate application mi-app -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Esperar y verificar
sleep 15
kubectl get pods -n mi-app
```

**Validación:** Deben aparecer 5 pods.

---

## Fase 9. Pruebas Prune y selfHeal

**Objetivo:** Comprobar que Argo CD limpia recursos huérfanos y revierte cambios manuales.

### Prueba A: prune (Git manda sobre lo que sobra)

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef danger fill:#CF222E,stroke:#82071E,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    A["git rm service.yaml<br/>git commit, git push"]:::cmd ==> B[("Git ya NO contiene<br/>service.yaml")]:::git
    B --> C["Controller compara:<br/>el clúster tiene un Service<br/>que Git no declara"]:::argo
    C --> Q{"prune: true"}:::argo
    Q -->|"sí"| D["Elimina el Service<br/>huérfano"]:::danger
    Q -.->|"si fuera false"| E["Lo dejaría y marcaría<br/>OutOfSync"]:::k8s
    D --> V(["kubectl get svc<br/>sin resultados"]):::ok
```

| Componente | Qué es | Aprendizaje |
| :--- | :--- | :--- |
| **git rm** | Borra el archivo y lo prepara para commit | La eliminación ocurre en **Git**, no en el clúster. |
| **Recurso huérfano** | Existe en el clúster pero ya no en Git | Sin `prune`, se acumularía "basura" para siempre. |
| **Rombo `prune: true`** | Punto de decisión de la política | Es la configuración que habilita la limpieza automática. |
| **Rama punteada** | Lo que pasaría con `prune: false` | Argo CD solo avisaría con `OutOfSync`. |
| **Caja roja** | Acción destructiva | Recuerda: `prune` borra de verdad. |

```bash
cd ~/argocd-lab-2/repo-git
git rm service.yaml && git commit -m "chore: eliminar service" && git push
kubectl annotate application mi-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
sleep 15
kubectl get svc -n mi-app
```

**Validación A:** El Service desaparece del clúster.

### Prueba B: selfHeal (Git manda sobre cambios manuales)

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef danger fill:#CF222E,stroke:#82071E,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    G[("Git declara<br/>replicas: 5")]:::git
    M["kubectl scale<br/>replicas=10<br/>cambio manual"]:::danger
    K["Clúster: 10 réplicas<br/>deriva de configuración"]:::k8s
    C["Controller detecta<br/>Git (5) distinto de clúster (10)"]:::argo
    Q{"selfHeal: true"}:::argo
    R["Reaplica el estado de Git"]:::argo
    V(["Deployment vuelve a 5"]):::ok

    M --> K
    G -.->|"fuente de verdad"| C
    K -.->|"estado real"| C
    C --> Q
    Q -->|"sí"| R
    R ==> V
```

| Componente | Qué es | Aprendizaje |
| :--- | :--- | :--- |
| **Cambio manual (rojo)** | Alguien modifica el clúster a mano | Es lo que en la práctica causa "deriva" y errores difíciles de rastrear. |
| **Deriva (drift)** | Diferencia entre lo declarado y lo real | `selfHeal` existe para eliminarla. |
| **Flechas punteadas hacia el controller** | Las dos entradas que compara | Estado deseado (Git) y estado real (clúster). |
| **Rombo `selfHeal: true`** | Decisión de la política | Sin él, el cambio manual **persistiría**. |
| **Resultado** | El valor de Git gana siempre | Para cambiar réplicas de verdad, cambias Git. |

```bash
kubectl scale deploy mi-app -n mi-app --replicas=10
sleep 15
kubectl get deploy mi-app -n mi-app
```

**Validación B:** Argo CD revierte las réplicas al valor de Git (5).

---

## Fase 10. Rollback con git revert

**Objetivo:** Restaurar el Service eliminado en la Fase 9 sin tocar el clúster.

```mermaid
gitGraph
    commit id: "c1" tag: "manifiestos iniciales"
    commit id: "c2" tag: "escalar a 5 replicas"
    commit id: "c3" tag: "eliminar service"
    commit id: "c4" type: REVERSE tag: "revert service"
    commit id: "c5" tag: "Argo CD sincroniza"
```

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef argo fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    A["git revert HEAD<br/>--no-edit"]:::cmd --> B[("Nuevo commit<br/>que deshace el anterior<br/>service.yaml vuelve")]:::git
    B ==>|"git push"| C["GitHub actualizado"]:::git
    C --> D["refresh=hard<br/>o espera ~3 min"]:::cmd
    D --> E["Argo CD detecta<br/>Service ausente"]:::argo
    E ==> F["Recrea el Service"]:::k8s
    F --> V(["Synced y Healthy<br/>sin tocar el clúster"]):::ok
```

**Anatomía de los diagramas**

| Elemento | Qué representa | Aprendizaje |
| :--- | :--- | :--- |
| **gitGraph: línea de commits** | Historial lineal de la rama `main` | Cada círculo es un commit. |
| **Commit `REVERSE` (tachado)** | El commit generado por `git revert` | No borra el historial: **añade** un commit que deshace otro. |
| **Commit `HIGHLIGHT`** | Momento en que Argo CD sincroniza | No es un commit real; marca cuándo el clúster alcanza el nuevo estado. |
| **`git revert` vs `git reset`** | Dos formas de "volver atrás" | `revert` es seguro en ramas compartidas porque conserva el historial y la auditoría. |
| **Sin tocar el clúster** | Principio GitOps | El rollback es un cambio en Git; Argo CD hace el resto. |

> **Importante:** `git revert HEAD` revierte el último commit. Funciona aquí porque el último commit es el de "eliminar service". Si hiciste otros commits después, usa `git log --oneline` y revierte el hash correcto.

**Comando:**

```bash
cd ~/argocd-lab-2/repo-git
git revert HEAD --no-edit && git push
kubectl annotate application mi-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
sleep 15
kubectl get svc -n mi-app
```

**Validación:** El Service vuelve a existir. La aplicación está `Synced` y `Healthy`.

---

## Fase 11. Limpieza

**Objetivo:** Dejar el entorno sin rastros, desde lo local hasta lo remoto.

```mermaid
flowchart TB
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px
    classDef danger fill:#CF222E,stroke:#82071E,color:#fff,stroke-width:2px
    classDef git fill:#8250DF,stroke:#5A32A3,color:#fff,stroke-width:2px
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px

    S1["1. Ctrl+C en Terminal 1<br/>detiene el port-forward"]:::cmd
    S2["2. kind delete cluster<br/>borra clúster, Argo CD y mi-app"]:::danger
    S3["3. rm -rf ~/argocd-lab-2<br/>borra archivos locales"]:::danger
    S4["4. rm llaves ~/.ssh/argocd_lab2*<br/>borra la llave privada y pública"]:::danger

    subgraph GH["Pasos manuales en GitHub"]
        S5["5. Eliminar la Deploy key<br/>argocd-lab2"]:::git
        S6["6. Opcional: eliminar el repo<br/>mi-app-argocd"]:::git
    end

    S1 --> S2 --> S3 --> S4 --> S5 --> S6
    S6 --> V(["Entorno limpio"]):::ok
```

**Anatomía del diagrama**

| Paso | Qué elimina | Por qué en este orden |
| :--- | :--- | :--- |
| **1. Port-forward** | El túnel hacia la UI | Evita errores al destruir el clúster con el túnel abierto. |
| **2. Clúster kind** | Todo Kubernetes: Argo CD, mi-app, Secrets | Un solo comando borra todo lo que vive dentro. |
| **3. Carpeta local** | Manifiestos y copia local del repo | Tu repo sigue existiendo en GitHub hasta el paso 6. |
| **4. Llaves SSH** | El par de llaves del lab | No dejes llaves huérfanas en tu máquina. |
| **5. Deploy key** | Acceso de lectura al repo | Una llave pública olvidada en GitHub sigue siendo una autorización activa. |
| **6. Repo (opcional)** | El repositorio remoto | Solo si ya no lo necesitas. |

**Comando:**

```bash
# 1. Detener el port-forward (Ctrl+C en la Terminal 1)

# 2. Eliminar el clúster
kind delete cluster --name argocd-lab2

# 3. Eliminar archivos locales del laboratorio
rm -rf ~/argocd-lab-2
rm -f ~/.ssh/argocd_lab2 ~/.ssh/argocd_lab2.pub
```

**Pasos manuales en GitHub:**

1. Elimina la Deploy key `argocd-lab2` en `Settings > Deploy keys` del repositorio.
2. Opcional: elimina el repositorio `mi-app-argocd` si ya no lo necesitas.

---

## Resolución de problemas

```mermaid
flowchart TD
    classDef q fill:#EF7B4D,stroke:#B5532B,color:#fff,stroke-width:2px
    classDef fix fill:#2EA44F,stroke:#1A6B31,color:#fff,stroke-width:2px
    classDef start fill:#57606A,stroke:#24292F,color:#fff,stroke-width:2px

    S(["Algo no funciona"]):::start --> Q1{"¿La Application muestra<br/>ComparisonError o repo Failed?"}:::q
    Q1 -->|"sí"| F1["Revisa la Deploy key en GitHub<br/>y el Secret de la Fase 5"]:::fix
    Q1 -->|"no"| Q2{"¿OutOfSync persistente?"}:::q
    Q2 -->|"sí"| F2["Revisa syncPolicy y<br/>spec.source.path de la Fase 6"]:::fix
    Q2 -->|"no"| Q3{"¿Pods en ImagePullBackOff?"}:::q
    Q3 -->|"sí"| F3["kubectl describe pod -n mi-app<br/>revisa red e imagen"]:::fix
    Q3 -->|"no"| Q4{"¿Puerto 8080 ocupado?"}:::q
    Q4 -->|"sí"| F4["Usa otro puerto local<br/>9090:443"]:::fix
    Q4 -->|"no"| F5["Revisa la tabla de abajo"]:::fix
```

| Síntoma | Causa probable | Acción |
| :--- | :--- | :--- |
| `ComparisonError` o repo en estado `Failed` | Error de autenticación SSH. | Verifica que la Deploy key esté registrada en GitHub (Fase 5, paso 2) y que el Secret tenga la clave privada correcta. |
| `OutOfSync` persistente | Cambio manual en el clúster con `selfHeal` desactivado, o `path` incorrecto en la Application. | Revisa `syncPolicy` y `spec.source.path` en el YAML de la Application (Fase 6). |
| `ImagePullBackOff` | Problema de red o nombre de imagen incorrecto. | `kubectl describe pod -n mi-app` para ver el error. |
| Puerto 8080 ocupado | Otro servicio en WSL. | Usa otro puerto: `kubectl port-forward svc/argocd-server -n argocd 9090:443`. |
| `repoURL` con `<USUARIO>` o vacío | La variable `USUARIO` no estaba definida en esa terminal. | Ejecuta `export USUARIO=tu_usuario` y repite el comando. |
| `kubectl wait` agota el timeout | Se esperó por pods que no llegan a `Ready`. | Usa los comandos de la Fase 2 (`Deployment` y `StatefulSet`). |

