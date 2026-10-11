# Runbook tecnico: WS_5 GitOps con ArgoCD

![Estado](https://img.shields.io/badge/Estado-Validado-166534?style=flat-square)
![Nivel](https://img.shields.io/badge/Nivel-Enterprise_Foundation-8A2BE2?style=flat-square)
![SO](https://img.shields.io/badge/SO-Ubuntu_24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Kubernetes](https://img.shields.io/badge/KinD-Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.10.4-EF7B4D?style=flat-square&logo=argo&logoColor=white)
![Gitea](https://img.shields.io/badge/Gitea-1.22.0-609926?style=flat-square&logo=gitea&logoColor=white)

| Dato | Valor |
| :--- | :--- |
| Ubicacion base | `/home/gmt/sre-linux-mastery/Fase5/WS_5` |
| Entorno | WSL2 con Ubuntu 24.04 LTS sobre Windows 11 |
| Audiencia | Ingenieros SRE y DevOps en formacion |
| Duracion estimada | 45 a 60 minutos |
| Vision general | Ver [README.md](./README.md) |

Convenciones de este documento:

- Cada fase indica su objetivo, los comandos con su explicacion y la validacion esperada.
- Las variables de ruta se definen una sola vez en la Fase 1 y se reutilizan.
- Los bloques de configuracion usan `'EOF'` entre comillas para que el shell no expanda variables dentro del archivo.

Mapa del procedimiento:

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#1e3a8a','primaryTextColor':'#fff','lineColor':'#94a3b8','fontFamily':'Inter, Segoe UI, sans-serif'}}}%%
flowchart TD
    A["Fase 0: Verificar herramientas"] --> B["Fase 1: Crear estructura"]
    B --> C["Fase 2: Gitea con Compose"]
    C --> D["Fase 3: Cluster KinD"]
    D --> E{"El nodo resuelve<br/>local-gitea?"}
    E -- "No" --> E1["Revisar docker network connect"]
    E1 --> E
    E -- "Si" --> F["Fase 4: Instalar ArgoCD"]
    F --> G["Fase 5: Repo y manifiestos"]
    G --> H["Fase 6: Application CRD"]
    H --> I["Fase 7: Pruebas"]
    I --> J["Fase 8: Limpieza"]

    classDef prep fill:#581c87,stroke:#c084fc,color:#fff
    classDef infra fill:#1e3a8a,stroke:#60a5fa,color:#fff
    classDef gitops fill:#9a3412,stroke:#fb923c,color:#fff
    classDef test fill:#166534,stroke:#4ade80,color:#fff
    classDef decision fill:#854d0e,stroke:#facc15,color:#fff
    classDef clean fill:#991b1b,stroke:#f87171,color:#fff
    class A,B prep
    class C,D,E1 infra
    class F,G,H gitops
    class I test
    class E decision
    class J clean
```

---

## Fase 0: Verificacion del entorno

**Objetivo:** confirmar que existen los binarios y que el demonio de Docker responde antes de crear nada.

```bash
echo "=== Binarios ==="
for cmd in docker kind kubectl git curl; do
  if command -v "$cmd" &>/dev/null; then
    echo "[OK]   $cmd instalado"
  else
    echo "[FAIL] $cmd no encontrado"
  fi
done

echo "=== Docker Daemon ==="
docker info >/dev/null 2>&1 && echo "[OK]   Docker activo" || echo "[FAIL] Docker no responde"
```

| Elemento | Explicacion |
| :--- | :--- |
| `command -v` | Busca el binario en el `PATH` sin ejecutarlo. |
| `&>/dev/null` | Descarta salida estandar y de error; solo importa el codigo de retorno. |
| `docker info` | Falla si el demonio esta detenido o el usuario no tiene permisos sobre el socket. |

**Validacion:** las seis lineas deben mostrar `[OK]`. Si Docker falla, inicia el servicio con `sudo service docker start` o verifica que tu usuario pertenezca al grupo `docker`.

---

## Fase 1: Estructura del directorio de trabajo

**Objetivo:** crear el arbol del taller y definir la variable de ruta base.

```bash
export WS=/home/gmt/sre-linux-mastery/Fase5/WS_5
mkdir -p "$WS"/{infra,repo-app}
cd "$WS"
```

| Elemento | Explicacion |
| :--- | :--- |
| `export WS=...` | Variable de entorno valida solo en esta sesion de terminal. Si abres otra, vuelve a definirla. |
| `mkdir -p` | Crea la ruta completa y no falla si ya existe. |
| `{infra,repo-app}` | Expansion de llaves de Bash: crea ambos directorios en un solo comando. |

Estructura resultante y responsabilidad de cada parte:

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#1f2937','primaryTextColor':'#f9fafb','lineColor':'#94a3b8','fontFamily':'Inter, Segoe UI, sans-serif'}}}%%
flowchart LR
    WS["WS_5"]
    WS --> R["README.md<br/>Documentacion"]
    WS --> B["RUNBOOK.md<br/>Procedimiento"]
    WS --> I["infra/<br/>Plataforma"]
    WS --> A["repo-app/<br/>Aplicacion"]
    I --> I1["docker-compose.yml<br/>Gitea y red"]
    I --> I2["kind-config.yaml<br/>Cluster y puertos"]
    I --> I3["argocd-app.yaml<br/>Application CRD"]
    A --> A1[".git/<br/>Historial"]
    A --> A2["deployment.yaml<br/>Nginx y Service"]

    classDef root fill:#581c87,stroke:#c084fc,color:#fff
    classDef doc fill:#0f766e,stroke:#2dd4bf,color:#fff
    classDef infra fill:#1e3a8a,stroke:#60a5fa,color:#fff
    classDef app fill:#9a3412,stroke:#fb923c,color:#fff
    class WS root
    class R,B doc
    class I,I1,I2,I3 infra
    class A,A1,A2 app
```

---

## Fase 2: Servidor Git local (Gitea)

**Objetivo:** levantar Gitea en una red Docker propia, a la que luego se conectara el cluster.

### 2.1 Archivo `infra/docker-compose.yml`

```bash
cat <<'EOF' > "$WS/infra/docker-compose.yml"
services:
  gitea:
    image: gitea/gitea:1.22.0
    container_name: local-gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__security__INSTALL_LOCK=true
      - GITEA__server__DISABLE_SSH=true
      - GITEA__server__HTTP_PORT=3000
      - GITEA__server__ROOT_URL=http://local-gitea:3000/
      - GITEA__service__DISABLE_REGISTRATION=false
      - GITEA__service__REQUIRE_SIGNIN_VIEW=false
    ports:
      - "3000:3000"
    volumes:
      - gitea-data:/data
    networks:
      - gitops-net
    restart: unless-stopped

volumes:
  gitea-data:

networks:
  gitops-net:
    name: gitops-net
EOF
```

| Clave | Valor | Explicacion |
| :--- | :--- | :--- |
| `image` | `gitea/gitea:1.22.0` | Version fija para reproducibilidad. Evita `latest`. |
| `container_name` | `local-gitea` | Nombre que otros contenedores usaran como host DNS. |
| `USER_UID`, `USER_GID` | `1000` | El proceso interno corre con el mismo UID que tu usuario de WSL, evitando problemas de permisos. |
| `GITEA__security__INSTALL_LOCK` | `true` | Omite el asistente web de instalacion. El prefijo `GITEA__seccion__clave` mapea a `app.ini`. |
| `GITEA__server__DISABLE_SSH` | `true` | Solo se usa HTTP; no se publica el puerto SSH. |
| `GITEA__server__HTTP_PORT` | `3000` | Puerto de escucha dentro del contenedor. |
| `GITEA__server__ROOT_URL` | `http://local-gitea:3000/` | URL base que Gitea considera propia. Coincide con la que usa ArgoCD. |
| `DISABLE_REGISTRATION` | `false` | Permite crear usuarios desde la web. Solo para laboratorio. |
| `REQUIRE_SIGNIN_VIEW` | `false` | Los repositorios publicos se leen sin autenticar, lo que simplifica ArgoCD. |
| `ports` | `3000:3000` | Publica la interfaz y la API en `localhost:3000`. |
| `volumes` | `gitea-data:/data` | Volumen nombrado: los repositorios sobreviven a un reinicio del contenedor. |
| `networks.gitops-net.name` | `gitops-net` | Fija el nombre real de la red. Sin `name`, Compose la prefijaria con el proyecto. |
| `restart` | `unless-stopped` | Reinicia el servicio tras un reinicio de Docker. |

### 2.2 Iniciar el servicio

```bash
docker compose -f "$WS/infra/docker-compose.yml" up -d
```

| Elemento | Explicacion |
| :--- | :--- |
| `-f` | Indica el archivo Compose, porque no estamos en su directorio. |
| `up -d` | Crea red, volumen y contenedor, y devuelve la terminal (modo desacoplado). |

**Validacion:**

```bash
docker ps --filter name=local-gitea --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000
```

Debe mostrar el contenedor en estado `Up` y el codigo `200`.

---

## Fase 3: Cluster KinD e integracion de red

**Objetivo:** crear el cluster, publicar los puertos necesarios y permitirle resolver el nombre `local-gitea`.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#1e3a8a','primaryTextColor':'#fff','lineColor':'#94a3b8','fontFamily':'Inter, Segoe UI, sans-serif'}}}%%
flowchart LR
    subgraph DOCKER["Docker en WSL2"]
        subgraph N1["Red: bridge de KinD"]
            CP["enterprise-gitops-control-plane"]
        end
        subgraph N2["Red: gitops-net"]
            GT["local-gitea"]
        end
        CP -. "docker network connect" .-> N2
    end
    H1["localhost:8080"] --> CP
    H2["localhost:8443"] --> CP

    classDef k fill:#1e3a8a,stroke:#60a5fa,color:#fff
    classDef g fill:#166534,stroke:#4ade80,color:#fff
    classDef h fill:#581c87,stroke:#c084fc,color:#fff
    class CP k
    class GT g
    class H1,H2 h
```

El nodo queda con dos interfaces de red: una de KinD y otra de `gitops-net`. Gracias al DNS interno de Docker, en esta segunda red `local-gitea` se resuelve por nombre.

### 3.1 Archivo `infra/kind-config.yaml`

```bash
cat <<'EOF' > "$WS/infra/kind-config.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
  - containerPort: 30443
    hostPort: 8443
    protocol: TCP
EOF
```

| Clave | Explicacion |
| :--- | :--- |
| `kind` y `apiVersion` | Identifican el esquema de configuracion de KinD. |
| `role: control-plane` | Un solo nodo que cumple funciones de control y de trabajo. Suficiente para el taller. |
| `extraPortMappings` | Publica puertos del contenedor del nodo hacia el host. Solo se aplica al crear el cluster. |
| `containerPort: 30080` | NodePort del Service `demo-web-service`. |
| `hostPort: 8080` | Puerto accesible desde Windows y WSL. |
| `containerPort: 30443` | NodePort del servicio `argocd-server`. |
| `hostPort: 8443` | Puerto de la interfaz de ArgoCD. |

### 3.2 Crear el cluster

```bash
kind create cluster --name enterprise-gitops --config "$WS/infra/kind-config.yaml"
```

El contenedor del nodo se llamara `enterprise-gitops-control-plane` y el contexto de kubectl `kind-enterprise-gitops`.

### 3.3 Conectar el nodo a la red de Gitea

```bash
docker network connect gitops-net enterprise-gitops-control-plane
```

### 3.4 Validar la conectividad

```bash
docker exec enterprise-gitops-control-plane curl -s -I http://local-gitea:3000
```

**Validacion:** la primera linea debe ser `HTTP/1.1 200 OK`. Si falla con `Could not resolve host`, repite el paso 3.3 y confirma con `docker network inspect gitops-net`.

---

## Fase 4: Instalacion y exposicion de ArgoCD

**Objetivo:** desplegar ArgoCD y hacerlo accesible desde el navegador.

### 4.1 Desplegar los manifiestos

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.4/manifests/install.yaml
```

Este paso requiere internet para descargar el manifiesto y las imagenes. El archivo `install.yaml` crea CRDs, roles, el `argocd-server`, el `repo-server`, el `application-controller` y Redis.

### 4.2 Esperar disponibilidad

```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

El comando bloquea hasta que el Deployment este disponible o se agoten 300 segundos.

### 4.3 Exponer la interfaz por NodePort

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'
```

| Campo | Explicacion |
| :--- | :--- |
| `type: NodePort` | Abre un puerto en el nodo. |
| `port: 443` | Puerto del Service dentro del cluster. |
| `targetPort: 8080` | Puerto real donde escucha el pod de ArgoCD. |
| `nodePort: 30443` | Debe coincidir con `containerPort` de `kind-config.yaml`. |

### 4.4 Obtener la contrasena inicial

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

El usuario es `admin`. El secreto esta codificado en base64; `base64 -d` lo decodifica.

**Validacion:** abre `https://localhost:8443`, acepta la advertencia del certificado autofirmado e inicia sesion.

---

## Fase 5: Repositorio Git y manifiestos de la aplicacion

**Objetivo:** crear el usuario y el repositorio remoto, escribir el manifiesto y publicarlo.

### 5.1 Usuario administrador y repositorio en Gitea

```bash
docker exec -u 1000 local-gitea gitea admin user create \
  --username devops --password 'Password123!' \
  --email devops@local.lan --admin --must-change-password=false

curl -s -X POST "http://localhost:3000/api/v1/user/repos" \
  -H "Content-Type: application/json" \
  -u 'devops:Password123!' \
  -d '{"name":"sample-app","private":false}'
```

| Elemento | Explicacion |
| :--- | :--- |
| `docker exec -u 1000` | Ejecuta la CLI de Gitea como el usuario no privilegiado del contenedor. |
| `--admin` | Concede rol de administrador. |
| `--must-change-password=false` | Evita que Gitea exija cambiar la clave, lo que bloquearia las llamadas a la API. |
| `POST /api/v1/user/repos` | Crea un repositorio bajo el usuario autenticado. |
| `"private": false` | Repositorio publico, de modo que ArgoCD lo clona sin credenciales. |

### 5.2 Repositorio local y manifiesto

```bash
cd "$WS/repo-app"
git init -b main
git config user.name "DevOps Engineer"
git config user.email "devops@local.lan"
```

```bash
cat <<'EOF' > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web
  labels:
    app: demo-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: demo-web-service
spec:
  type: NodePort
  selector:
    app: demo-web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

| Seccion | Clave | Explicacion |
| :--- | :--- | :--- |
| Deployment | `replicas: 2` | Estado deseado inicial; se cambiara a 4 en las pruebas. |
| Deployment | `selector.matchLabels` | Debe coincidir con las etiquetas de la plantilla, o Kubernetes rechaza el recurso. |
| Deployment | `image: nginx:1.25-alpine` | Imagen liviana con version fija. |
| Service | `type: NodePort` | Publica la aplicacion fuera del cluster. |
| Service | `selector: app: demo-web` | Dirige el trafico a los pods con esa etiqueta. |
| Service | `nodePort: 30080` | Coincide con el mapeo `8080` de KinD. |
| Archivo | separador `---` | Permite dos recursos en un mismo YAML. |

### 5.3 Commit y publicacion

```bash
git add .
git commit -m "feat: despliegue inicial de nginx"
git remote add origin http://localhost:3000/devops/sample-app.git
git push http://devops:Password123!@localhost:3000/devops/sample-app.git main
```

Se envian las credenciales en la URL solo por comodidad del taller. En un entorno real se usaria un credential helper o un token.

**Validacion:** `http://localhost:3000/devops/sample-app` debe mostrar `deployment.yaml`.

---

## Fase 6: Declaracion de la aplicacion en ArgoCD

**Objetivo:** indicar a ArgoCD que repositorio vigilar y donde desplegarlo.

```bash
cat <<'EOF' > "$WS/infra/argocd-app.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://local-gitea:3000/devops/sample-app.git
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

kubectl apply -f "$WS/infra/argocd-app.yaml"
```

| Clave | Valor | Explicacion |
| :--- | :--- | :--- |
| `metadata.namespace` | `argocd` | Las `Application` deben vivir en el namespace de ArgoCD. |
| `spec.project` | `default` | Proyecto de ArgoCD sin restricciones adicionales. |
| `source.repoURL` | `http://local-gitea:3000/...` | Usa el nombre DNS de la red `gitops-net`, no `localhost`, porque la consulta la hace un pod. |
| `source.targetRevision` | `HEAD` | Sigue el ultimo commit de la rama por defecto. |
| `source.path` | `.` | Raiz del repositorio; ArgoCD aplica todos los YAML que encuentre. |
| `destination.server` | `https://kubernetes.default.svc` | API del mismo cluster donde corre ArgoCD. |
| `destination.namespace` | `default` | Namespace de destino de los recursos. |
| `automated.prune` | `true` | Elimina del cluster lo que se borre de Git. |
| `automated.selfHeal` | `true` | Revierte cambios manuales hechos con kubectl. |
| `CreateNamespace=true` | opcion | Crea el namespace destino si no existe. |

**Validacion:**

```bash
kubectl get application -n argocd
```

Debe mostrar `Synced` y `Healthy` en pocos segundos.

---

## Fase 7: Pruebas de validacion y operacion

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#166534','primaryTextColor':'#fff','lineColor':'#94a3b8','fontFamily':'Inter, Segoe UI, sans-serif'}}}%%
flowchart LR
    T1["Prueba 1<br/>Estado inicial"] --> T2["Prueba 2<br/>Escalar via Git"]
    T2 --> T3["Prueba 3<br/>Drift manual"]
    T3 --> T4["Prueba 4<br/>Borrado destructivo"]

    classDef t fill:#166534,stroke:#4ade80,color:#fff
    class T1,T2,T3,T4 t
```

### Prueba 1: Estado inicial

```bash
kubectl get application -n argocd
kubectl get pods -l app=demo-web
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080
```

Esperado: aplicacion `Synced/Healthy`, 2 pods en `Running` y codigo HTTP `200`.

### Prueba 2: Escalado declarativo desde Git

```bash
cd "$WS/repo-app"
sed -i 's/replicas: 2/replicas: 4/' deployment.yaml
git add deployment.yaml
git commit -m "scale: subir replicas a 4"
git push http://devops:Password123!@localhost:3000/devops/sample-app.git main
kubectl get pods -l app=demo-web -w
```

El cambio llega por polling (hasta 3 minutos). Para acelerarlo:

```bash
kubectl annotate application sample-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

Esperado: aparecen 4 pods. Sal del modo `-w` con `Ctrl+C`.

### Prueba 3: Autorreparacion ante deriva

```bash
kubectl scale deployment demo-web --replicas=1
kubectl get deployment demo-web -w
```

Esperado: ArgoCD detecta el cambio manual y vuelve a 4 replicas.

### Prueba 4: Autorreparacion ante borrado

```bash
kubectl delete deployment demo-web
kubectl get deployment demo-web -w
```

Esperado: el Deployment se recrea con 4 replicas.

Resumen de comportamientos:

| Prueba | Accion | Resultado esperado | Mecanismo |
| :--- | :--- | :--- | :--- |
| 1 | Ninguna | Synced y Healthy | Sincronizacion inicial |
| 2 | Commit en Git | 4 pods | Sync automatico |
| 3 | `kubectl scale` | Vuelve a 4 | `selfHeal` |
| 4 | `kubectl delete` | Se recrea | `selfHeal` |

---

## Fase 8: Limpieza completa

```bash
kind delete cluster --name enterprise-gitops
docker compose -f "$WS/infra/docker-compose.yml" down -v
rm -rf "$WS/repo-app/.git" "$WS/repo-app/deployment.yaml"
```

| Comando | Efecto |
| :--- | :--- |
| `kind delete cluster` | Elimina el contenedor del nodo y el contexto de kubectl. |
| `down -v` | Detiene Gitea, borra la red y el volumen `gitea-data` (se pierden los repositorios). |
| `rm -rf` | Limpia el repositorio local para repetir el taller desde la Fase 2. |

---

## Solucion de problemas

| Sintoma | Causa probable | Accion |
| :--- | :--- | :--- |
| `Could not resolve host: local-gitea` desde el nodo | El nodo no esta en `gitops-net` | Repetir el paso 3.3 y revisar `docker network inspect gitops-net` |
| Application en `Unknown` con error de repositorio | Nombre DNS no resuelto desde los pods | Verificar el paso 3.4; reiniciar CoreDNS con `kubectl -n kube-system rollout restart deploy/coredns` |
| `https://localhost:8443` no abre | Patch del Service no aplicado o puerto ocupado | `kubectl get svc argocd-server -n argocd` y `ss -tlnp` |
| `port is already allocated` al crear el cluster | Puerto 8080 u 8443 en uso | Liberar el puerto o cambiar `hostPort` |
| Gitea devuelve 401 en la API | Contrasena obligada a cambiar | Recrear el usuario con `--must-change-password=false` |
| Los cambios tardan en aparecer | Polling de 3 minutos | Forzar con la anotacion `refresh=hard` |

