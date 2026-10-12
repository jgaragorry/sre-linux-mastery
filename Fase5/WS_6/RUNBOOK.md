# Runbook Tecnico: WS_6, Multi-Entorno con Kustomize, App of Apps y Webhooks

![Fase](https://img.shields.io/badge/Fase-5-8A2BE2?style=flat-square)
![Nivel](https://img.shields.io/badge/Nivel-Enterprise_SRE-EF7B4D?style=flat-square)
![SO](https://img.shields.io/badge/SO-Ubuntu_24.04_(WSL2)-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.10.4-EF7B4D?style=flat-square&logo=argo&logoColor=white)
![Estado](https://img.shields.io/badge/Procedimiento-Reproducible-00B894?style=flat-square)

- **Ruta base:** `/home/gmt/sre-linux-mastery/Fase5/WS_6`
- **Prerrequisito:** el stack de Gitea de `WS_5` (`WS_5/infra/docker-compose.yml`) y el archivo `WS_5/infra/kind-config.yaml`.
- **Contexto conceptual:** ver [README.md](./README.md).

## Mapa del procedimiento

```mermaid
flowchart LR
    F0[Fase 0<br/>Diagnostico]:::s0 --> F1[Fase 1<br/>Gitea y repo]:::s1 --> F2[Fase 2<br/>KinD y red]:::s2 --> F3[Fase 3<br/>ArgoCD]:::s3 --> F4[Fase 4<br/>Manifiestos]:::s4 --> F5[Fase 5<br/>Publicacion<br/>y App raiz]:::s5 --> F6[Fase 6<br/>Webhook]:::s6 --> F7[Fase 7<br/>Verificacion]:::s7 --> F8[Fase 8<br/>Prueba de escalado]:::s8 --> F9[Fase 9<br/>Limpieza]:::s9

    classDef s0 fill:#636E72,color:#fff,stroke:#2D3436
    classDef s1 fill:#609926,color:#fff,stroke:#3F6B17
    classDef s2 fill:#326CE5,color:#fff,stroke:#1F4BA8
    classDef s3 fill:#EF7B4D,color:#fff,stroke:#B85A33
    classDef s4 fill:#0984E3,color:#fff,stroke:#0652A0
    classDef s5 fill:#6C5CE7,color:#fff,stroke:#4B3FB5
    classDef s6 fill:#D63031,color:#fff,stroke:#992223
    classDef s7 fill:#00B894,color:#fff,stroke:#007F68
    classDef s8 fill:#FDCB6E,color:#333,stroke:#C79A2E
    classDef s9 fill:#B2BEC3,color:#333,stroke:#636E72
```

## Variables usadas en el runbook

Para no repetir rutas y credenciales, se definen una sola vez en la sesion de terminal:

```bash
export WS=/home/gmt/sre-linux-mastery/Fase5/WS_6
export GITEA_USER='devops'
export GITEA_PASS='Password123!'
export WH_SECRET='MiWebhookSecret123!'
```

Las comillas simples impiden que Bash interprete el signo `!` como expansion de historial. Son credenciales de laboratorio; en un entorno real se gestionan con un gestor de secretos.

---

## Fase 0: Diagnostico de dependencias y proteccion de Git

### Paso 0.1: Verificar binarios

```bash
for cmd in docker kind kubectl git curl python3; do
  command -v "$cmd" >/dev/null 2>&1 && echo "[OK]   $cmd" || echo "[FALTA] $cmd"
done
```

| Elemento | Explicacion |
| :--- | :--- |
| `command -v` | Busca el ejecutable en el `PATH`; es la forma portable (POSIX) de `which`. |
| `>/dev/null 2>&1` | Descarta salida estandar y de error; solo interesa el codigo de retorno. |
| `&& ... \|\| ...` | Si el comando existe imprime `[OK]`, si no imprime `[FALTA]`. |

Todos deben aparecer como `[OK]` antes de continuar.

### Paso 0.2: Estructura de carpetas y aislamiento en `.gitignore`

```bash
mkdir -p "$WS"/{infra,repo-gitops}
cd "$WS"
grep -qxF "Fase5/WS_6/repo-gitops/" /home/gmt/sre-linux-mastery/.gitignore 2>/dev/null \
  || echo "Fase5/WS_6/repo-gitops/" >> /home/gmt/sre-linux-mastery/.gitignore
```

| Elemento | Explicacion |
| :--- | :--- |
| `mkdir -p` | Crea la ruta completa y no falla si ya existe. |
| `{infra,repo-gitops}` | Expansion de llaves de Bash: crea ambas carpetas en un solo comando. |
| `grep -qxF` | `-q` silencioso, `-x` linea completa, `-F` texto literal. Evita duplicar la entrada. |
| `>>` | Agrega al final del archivo sin sobrescribirlo. |

Por que se ignora `repo-gitops/`: contendra su propio `.git`. Si el repositorio principal lo rastreara, Git lo trataria como un submodulo huerfano.

---

## Fase 1: Gitea y repositorio remoto

### Paso 1.1: Levantar Gitea

```bash
docker compose -f /home/gmt/sre-linux-mastery/Fase5/WS_5/infra/docker-compose.yml up -d
```

| Elemento | Explicacion |
| :--- | :--- |
| `-f <ruta>` | Indica el archivo Compose a usar, ubicado en otro directorio. |
| `up -d` | Crea e inicia los servicios en segundo plano. |

**Configuracion necesaria para el webhook (Fase 6).** Gitea bloquea por defecto las peticiones salientes hacia hosts privados y valida los certificados TLS. Como ArgoCD usa un certificado autofirmado dentro de la red Docker, el servicio `gitea` del Compose debe incluir estas variables de entorno:

```yaml
    environment:
      - GITEA__webhook__ALLOWED_HOST_LIST=private
      - GITEA__webhook__SKIP_TLS_VERIFY=true
```

| Variable | Efecto |
| :--- | :--- |
| `GITEA__webhook__ALLOWED_HOST_LIST=private` | Permite webhooks hacia direcciones de red privada. |
| `GITEA__webhook__SKIP_TLS_VERIFY=true` | Acepta el certificado autofirmado de ArgoCD. Solo apto para laboratorio. |

Si se agregan despues del primer arranque, se aplican con `docker compose ... up -d` (recrea el contenedor).

### Paso 1.2: Crear usuario y repositorio

```bash
docker exec -u 1000 local-gitea gitea admin user create \
  --username "$GITEA_USER" --password "$GITEA_PASS" \
  --email devops@local.lan --admin 2>/dev/null || true

curl -s -X POST "http://localhost:3000/api/v1/user/repos" \
  -H "Content-Type: application/json" \
  -u "$GITEA_USER:$GITEA_PASS" \
  -d '{"name": "multi-env-gitops", "private": false}'
```

| Elemento | Explicacion |
| :--- | :--- |
| `docker exec -u 1000` | Ejecuta dentro del contenedor como el usuario `git` (UID 1000). Gitea se niega a correr su CLI como root y asi no se rompen los permisos de los archivos de datos. |
| `gitea admin user create --admin` | Crea la cuenta con privilegios de administrador. |
| `\|\| true` | Si el usuario ya existe, el error se ignora y el procedimiento es repetible. |
| `curl -s -X POST` | `-s` sin barra de progreso; `-X POST` crea un recurso. |
| `-u usuario:clave` | Autenticacion HTTP Basic. |
| `-d '{...}'` | Cuerpo JSON: nombre del repositorio y visibilidad publica. |

### Paso 1.3: Validar

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3000/$GITEA_USER/multi-env-gitops"
```

`-o /dev/null` descarta el HTML y `-w "%{http_code}\n"` imprime solo el codigo HTTP. Resultado esperado: `200`.

---

## Fase 2: Cluster KinD e interconexion de red

```mermaid
flowchart LR
    subgraph H["Host WSL2"]
        P1["localhost:8443"]:::host
        P2["localhost:3000"]:::host
    end
    subgraph KN["Red docker: kind"]
        CP["enterprise-gitops-control-plane<br/>NodePort 30443"]:::k8s
    end
    subgraph GN["Red docker: gitops-net"]
        GT["local-gitea:3000"]:::git
    end
    P1 -->|extraPortMappings 8443 a 30443| CP
    P2 --> GT
    CP <-->|docker network connect| GT

    classDef host fill:#636E72,color:#fff,stroke:#2D3436
    classDef k8s fill:#326CE5,color:#fff,stroke:#1F4BA8
    classDef git fill:#609926,color:#fff,stroke:#3F6B17
```

### Paso 2.1: Crear el cluster

```bash
kind create cluster --name enterprise-gitops \
  --config /home/gmt/sre-linux-mastery/Fase5/WS_5/infra/kind-config.yaml
```

| Elemento | Explicacion |
| :--- | :--- |
| `--name` | Nombre del cluster; el contenedor del nodo se llamara `enterprise-gitops-control-plane` y el contexto de kubectl `kind-enterprise-gitops`. |
| `--config` | Archivo con `extraPortMappings`, que publica el puerto 30443 del nodo como 8443 en el host. |

### Paso 2.2: Conectar el nodo a la red de Gitea

```bash
docker network connect gitops-net enterprise-gitops-control-plane
```

KinD crea su propia red (`kind`). Al unir el nodo a `gitops-net`, ambos extremos se resuelven por nombre: el cluster llega a `local-gitea` y Gitea llega al nodo para entregar el webhook.

### Paso 2.3: Validar DNS y conectividad

```bash
docker exec enterprise-gitops-control-plane curl -s -I http://local-gitea:3000
```

`-I` solicita solo las cabeceras. Se espera `HTTP/1.1 200 OK`.

---

## Fase 3: Despliegue y exposicion de ArgoCD

### Paso 3.1: Instalar

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.4/manifests/install.yaml
```

| Elemento | Explicacion |
| :--- | :--- |
| `-n argocd` | Namespace destino de los recursos namespaced. |
| `--server-side` | Aplicacion del lado del servidor; evita el error de anotacion demasiado grande (`last-applied-configuration`) que producen los CRDs de ArgoCD con `apply` cliente. |
| `-f <url>` | Manifiesto oficial fijado a la version v2.10.4 para que el resultado sea reproducible. |

Instala los CRDs (`Application`, `AppProject`, `ApplicationSet`), el RBAC, Redis y los componentes: server, repo-server y application-controller.

### Paso 3.2: Esperar disponibilidad

```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

`--for=condition=available` espera a que las replicas esten listas segun sus probes; `--timeout=300s` limita la espera a 5 minutos.

### Paso 3.3: Exponer la interfaz y obtener la contrasena

```bash
kubectl patch svc argocd-server -n argocd -p \
  '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30443}]}}'

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

| Elemento | Explicacion |
| :--- | :--- |
| `patch svc -p` | Modifica el Service con un parche JSON. |
| `type: NodePort` | Publica el servicio en un puerto del nodo. |
| `nodePort: 30443` | Puerto fijo, el mismo que KinD enlaza con el 8443 del host. |
| `targetPort: 8080` | Puerto del contenedor de `argocd-server`. |
| `jsonpath='{.data.password}'` | Extrae solo el campo `password` del Secret. |
| `base64 -d` | Los Secrets guardan sus valores en Base64; se decodifica a texto. |

Acceso: `https://localhost:8443`, usuario `admin`.

---

## Fase 4: Manifiestos de Kustomize y aplicaciones

Todos los archivos se crean dentro de `$WS/repo-gitops`.

```bash
mkdir -p "$WS"/repo-gitops/{apps,workloads/base,workloads/overlays/dev,workloads/overlays/prod}
```

```mermaid
flowchart TD
    R["repo-gitops/"]:::root
    R --> A["apps/"]:::apps
    R --> W["workloads/"]:::wl
    A --> A1["dev-app.yaml"]:::apps
    A --> A2["prod-app.yaml"]:::apps
    W --> B["base/"]:::base
    W --> O["overlays/"]:::ov
    B --> B1["deployment.yaml"]:::base
    B --> B2["service.yaml"]:::base
    B --> B3["kustomization.yaml"]:::base
    O --> OD["dev/kustomization.yaml"]:::dev
    O --> OP["prod/kustomization.yaml<br/>prod/replicas-patch.yaml"]:::prod

    classDef root fill:#6C5CE7,color:#fff,stroke:#4B3FB5
    classDef apps fill:#EF7B4D,color:#fff,stroke:#B85A33
    classDef wl fill:#0984E3,color:#fff,stroke:#0652A0
    classDef base fill:#0984E3,color:#fff,stroke:#0652A0
    classDef ov fill:#636E72,color:#fff,stroke:#2D3436
    classDef dev fill:#00B894,color:#fff,stroke:#007F68
    classDef prod fill:#D63031,color:#fff,stroke:#992223
```

### 4.1 Base: `workloads/base/`

La base describe la aplicacion sin saber en que entorno vivira.

`deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
```

| Campo | Funcion |
| :--- | :--- |
| `replicas: 1` | Valor por defecto; prod lo sobrescribe con un parche. |
| `selector.matchLabels` | Une el Deployment con sus Pods. Debe coincidir con las etiquetas del template. |
| `image: nginx:1.25-alpine` | Imagen con version fija (sin `latest`) para despliegues predecibles. |
| `containerPort: 80` | Puerto informativo del contenedor. |

`service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

`ClusterIP` expone el servicio solo dentro del cluster. El `selector` apunta a los Pods con etiqueta `app: web-app`.

`kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
```

`resources` lista los archivos que componen la base.

### 4.2 Overlay de desarrollo: `workloads/overlays/dev/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: dev
namePrefix: dev-
resources:
  - ../../base
labels:
  - pairs:
      environment: development
    includeSelectors: true
```

### 4.3 Overlay de produccion: `workloads/overlays/prod/`

`replicas-patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
```

`kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
namePrefix: prod-
resources:
  - ../../base
patches:
  - path: replicas-patch.yaml
labels:
  - pairs:
      environment: production
    includeSelectors: true
```

| Directiva | Explicacion |
| :--- | :--- |
| `namespace` | Asigna el namespace a todos los recursos generados. |
| `namePrefix` | Antepone el prefijo a los nombres (`web-app` pasa a `dev-web-app`), evitando colisiones. |
| `resources: ../../base` | Importa la base completa. |
| `patches` | Aplica un parche estrategico: solo se declara lo que cambia. El parche se resuelve contra el nombre original (`web-app`) y el prefijo se aplica despues. |
| `labels` + `includeSelectors` | Inyecta la etiqueta en metadatos, plantillas de Pods y selectores. Reemplaza a `commonLabels` y a `patchesStrategicMerge`, ambos obsoletos en Kustomize reciente. |

Validacion local antes de publicar (render sin aplicar):

```bash
kubectl kustomize "$WS/repo-gitops/workloads/overlays/prod"
```

Debe mostrar `prod-web-app` con `replicas: 2` y `namespace: prod`.

### 4.4 Aplicaciones: `apps/`

`dev-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-web-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://local-gitea:3000/devops/multi-env-gitops.git
    targetRevision: HEAD
    path: workloads/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

`prod-app.yaml` es identico con tres cambios: `name: prod-web-app`, `path: workloads/overlays/prod` y `destination.namespace: prod`.

| Campo | Explicacion |
| :--- | :--- |
| `metadata.namespace: argocd` | Las `Application` siempre viven en el namespace de ArgoCD. |
| `finalizers` | Borrado en cascada: al eliminar la aplicacion se eliminan los recursos que gestiona. |
| `project: default` | Proyecto de ArgoCD sin restricciones adicionales. |
| `source.repoURL` | URL interna (`local-gitea`), resoluble desde el cluster gracias a la Fase 2. |
| `targetRevision: HEAD` | Sigue la rama por defecto del repositorio. |
| `source.path` | Carpeta con el `kustomization.yaml` a renderizar. |
| `destination.server` | `https://kubernetes.default.svc` es el cluster donde corre ArgoCD. |
| `automated.prune` | Elimina recursos que ya no estan en Git. |
| `automated.selfHeal` | Revierte cambios manuales. |
| `CreateNamespace=true` | Crea `dev` o `prod` si no existen. |

---

## Fase 5: Publicacion en Gitea y aplicacion raiz

### Paso 5.1: Inicializar y subir

```bash
cd "$WS/repo-gitops"
git init -b main
git config user.name "DevOps Engineer"
git config user.email "devops@local.lan"
git add .
git commit -m "feat: kustomize multi-env y app-of-apps"

git remote remove origin 2>/dev/null || true
git remote add origin "http://devops:Password123%21@localhost:3000/devops/multi-env-gitops.git"
git push -u origin main
```

| Elemento | Explicacion |
| :--- | :--- |
| `git init -b main` | Crea el repositorio con la rama `main`. |
| `git config user.*` | Identidad del commit, limitada a este repositorio. |
| `git remote remove origin \|\| true` | Hace el paso repetible. |
| `%21` | Codificacion URL del caracter `!` en la contrasena. |
| `git push -u` | Sube y fija `origin/main` como rama de seguimiento. |

Las credenciales embebidas en la URL quedan guardadas en `.git/config`; es aceptable en laboratorio, no en produccion.

### Paso 5.2: Aplicacion raiz

Archivo `infra/root-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-application
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://local-gitea:3000/devops/multi-env-gitops.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```bash
kubectl apply -f "$WS/infra/root-app.yaml"
```

La diferencia con las aplicaciones hijas esta en `path: apps` y `destination.namespace: argocd`: la raiz no despliega cargas de trabajo, despliega otras `Application`. Al detectar `dev-app.yaml` y `prod-app.yaml`, ArgoCD las crea y estas inician el despliegue de ambos entornos.

```mermaid
sequenceDiagram
    participant U as Operador
    participant K as kubectl
    participant A as ArgoCD
    participant G as Gitea
    U->>K: apply root-app.yaml
    K->>A: Crea root-application
    A->>G: Lee la carpeta apps/
    A->>A: Crea dev-web-app y prod-web-app
    A->>G: Lee workloads/overlays/dev y prod
    A->>K: Despliega Pods en dev y prod
```

---

## Fase 6: Webhook en tiempo real (Gitea hacia ArgoCD)

### Paso 6.1: Secreto compartido en ArgoCD

```bash
kubectl patch secret argocd-secret -n argocd --type merge \
  -p "{\"stringData\":{\"webhook.gogs.secret\":\"$WH_SECRET\"}}"
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

| Elemento | Explicacion |
| :--- | :--- |
| `webhook.gogs.secret` | ArgoCD no tiene una clave especifica para Gitea: reconoce el formato de Gogs, que Gitea emite por compatibilidad. |
| `--type merge` | Agrega la clave sin reemplazar el resto del Secret. |
| `stringData` | Permite escribir texto plano; Kubernetes lo convierte a Base64. |
| `rollout restart` / `status` | Reinicia el servidor para cargar el secreto y espera a que termine. |

### Paso 6.2: Registrar el webhook en Gitea

```bash
curl -s -X POST "http://localhost:3000/api/v1/repos/devops/multi-env-gitops/hooks" \
  -H "Content-Type: application/json" \
  -u "$GITEA_USER:$GITEA_PASS" \
  -d "{
    \"type\": \"gitea\",
    \"active\": true,
    \"events\": [\"push\"],
    \"config\": {
      \"url\": \"https://enterprise-gitops-control-plane:30443/api/webhook\",
      \"content_type\": \"json\",
      \"secret\": \"$WH_SECRET\"
    }
  }"
```

| Campo | Explicacion |
| :--- | :--- |
| `events: ["push"]` | Dispara solo en cada push. |
| `url` | Se usa HTTPS porque `argocd-server` tiene TLS activo; con HTTP la entrega falla. El nombre resuelve gracias a `gitops-net`. |
| `content_type: json` | Formato del payload. |
| `secret` | Debe coincidir exactamente con `webhook.gogs.secret`; Gitea firma el payload con HMAC y ArgoCD lo verifica. |

### Paso 6.3: Probar la entrega

```bash
curl -s -X POST "http://localhost:3000/api/v1/repos/devops/multi-env-gitops/hooks/1/tests" \
  -u "$GITEA_USER:$GITEA_PASS"
curl -s "http://localhost:3000/api/v1/repos/devops/multi-env-gitops/hooks/1/tasks" \
  -u "$GITEA_USER:$GITEA_PASS" | grep -o '"is_succeed":[^,]*' | head -n 1
```

Resultado esperado: `"is_succeed":true`. El primer comando fuerza un envio de prueba; el segundo consulta el historial de entregas y `grep -o` extrae solo el campo de exito.

---

## Fase 7: Verificacion operativa

```bash
kubectl get applications -n argocd
kubectl get pods -n dev  -l environment=development
kubectl get pods -n prod -l environment=production
```

| Verificacion | Resultado esperado |
| :--- | :--- |
| `get applications` | `root-application`, `dev-web-app` y `prod-web-app` en `Synced` y `Healthy`. |
| Pods en `dev` | 1 Pod en `Running`. |
| Pods en `prod` | 2 Pods en `Running`. |

`-l` filtra por etiqueta, lo que confirma de paso que el overlay inyecto `environment` correctamente.

---

## Fase 8: Prueba de ciclo de vida, escalado por webhook

```bash
cd "$WS/repo-gitops"
sed -i 's/replicas: 2/replicas: 4/' workloads/overlays/prod/replicas-patch.yaml
git add workloads/overlays/prod/replicas-patch.yaml
git commit -m "scale(prod): replicas a 4"
git push origin main

kubectl get deployment -n prod
```

`sed -i` edita el archivo en el lugar y `s/origen/destino/` sustituye el texto. En pocos segundos el Deployment `prod-web-app` debe mostrar `4/4` en `READY`, sin haber ejecutado ningun `kubectl scale`.

Prueba complementaria de `selfHeal`: escalar manualmente con `kubectl scale deployment prod-web-app -n prod --replicas=1` y observar como ArgoCD lo devuelve a 4.

---

## Fase 9: Desmantelamiento y limpieza

# 1. Eliminar la aplicación raíz (los finalizers eliminarán apps hijas y pods en cascada)

```bash
kubectl delete -f /home/gmt/sre-linux-mastery/Fase5/WS_6/infra/root-app.yaml
```

# 2. Purgar namespaces de trabajo
```bash
kubectl delete namespace dev prod --ignore-not-found
```

# 3. Limpiar el repositorio Git local
```bash
rm -rf /home/gmt/sre-linux-mastery/Fase5/WS_6/repo-gitops/.git
rm -rf /home/gmt/sre-linux-mastery/Fase5/WS_6/repo-gitops/*
```

echo "[OK] Entorno purgado y listo para una nueva ejecución limpia."
```"""

limpieza_nueva = """## FASE 9: Reseteo del Laboratorio (Para Repetir sin Borrar Archivos)

Este procedimiento elimina únicamente los recursos desplegados en Kubernetes y en Git, **conservando intactos todos los archivos de configuración y manifiestos**:

# 1. Eliminar aplicaciones en ArgoCD (elimina pods y servicios automáticamente)
```bash
kubectl delete application root-application dev-web-app prod-web-app -n argocd --ignore-not-found
```

# 2. Purgar namespaces dev y prod si persisten
```bash
kubectl delete namespace dev prod --ignore-not-found
```

# 3. Eliminar y recrear el repositorio en Gitea (queda limpio a 0 commits)
```bash
curl -s -X DELETE "http://localhost:3000/api/v1/repos/devops/multi-env-gitops" -u \x27devops:Password123!\x27
curl -s -X POST "http://localhost:3000/api/v1/user/repos" \\
  -H "accept: application/json" \\
  -H "Content-Type: application/json" \\
  -u \x27devops:Password123!\x27 \\
  -d \x27{"name": "multi-env-gitops", "private": false}\x27
```

# 4. Limpiar únicamente los metadatos locales de Git (.git) conservando los archivos YAML
```bash
rm -rf /home/gmt/sre-linux-mastery/Fase5/WS_6/repo-gitops/.git

echo "[OK] Clúster y Git limpios. Todos los manifiestos YAML se conservan intactos para reiniciar desde la Fase 5."
```"""
```

if limpieza_vieja in text:
    text = text.replace(limpieza_vieja, limpieza_nueva)
    with open(path, "w") as f:
        f.write(text)
    print("[OK] RUNBOOK.md actualizado con la lógica de preservación de archivos.")
else:
    print("[INFO] La sección de limpieza ya estaba actualizada o difiere levemente.")
'

---

## Resolucion de problemas

| Sintoma | Causa probable | Solucion |
| :--- | :--- | :--- |
| `event not found` al usar la contrasena | Expansion de `!` en Bash | Usar comillas simples o `%21` en URLs. |
| La aplicacion queda en `Unknown` con error de repositorio | El cluster no resuelve `local-gitea` | Repetir el Paso 2.2 y validar con el 2.3. |
| El webhook falla con error de conexion | Gitea bloquea hosts privados o rechaza el certificado | Agregar las variables del Paso 1.1 y recrear Gitea. |
| El webhook devuelve 400 o no refresca | Secreto distinto o clave incorrecta | Confirmar `webhook.gogs.secret` y reiniciar `argocd-server`. |
| `OutOfSync` permanente | Error de sintaxis en un overlay | Ejecutar `kubectl kustomize` sobre el overlay y corregir. |
| `apply` de ArgoCD falla por anotacion demasiado grande | `apply` cliente sobre CRDs | Usar `--server-side` como en el Paso 3.1. |
| No abre `https://localhost:8443` | Falta el mapeo de puertos o el NodePort | Revisar `kind-config.yaml` y el Paso 3.3. |

