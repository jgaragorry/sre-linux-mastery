# Runbook: GitOps de cero a producción local

- **Ruta base:** `/home/gmt/sre-linux-mastery/Fase5/WS_Easy`
- **Duración aproximada:** 25 a 35 minutos con las imágenes ya descargadas
- **Regla de la clase:** a partir de la Fase 5 no cambio cargas de trabajo con `kubectl`, salvo cuando quiero provocar un drift a propósito. Todo lo demás entra por Git.

### Mapa de puertos

| Puerto del host | Destino | Para qué |
| :--- | :--- | :--- |
| 3000 | Gitea (HTTP) | Interfaz web y `git push` |
| 222 | Gitea (SSH) | No lo usamos, pero queda publicado |
| 8443 | NodePort 30443 de KinD | Interfaz de Argo CD |
| 8080 | NodePort 30080 de KinD | La aplicación Nginx |

### Credenciales del laboratorio

| Servicio | Usuario | Clave |
| :--- | :--- | :--- |
| Gitea | `devops` | `Devops12345` |
| Argo CD | `admin` | se obtiene en el Paso 3.4 |

---

## Fase 0: Preparación del entorno

**Meta:** confirmar que las herramientas están y que los puertos están libres, antes de crear nada.

### Paso 0.1: Verificar herramientas

```bash
docker version --format '{{.Server.Version}}'
docker compose version
kind version
kubectl version --client
git --version
curl --version | head -n 1
```

- `docker version --format '{{.Server.Version}}'`: imprime solo la versión del servidor Docker. Si falla, el Docker Engine no está activo y hay que arrancarlo antes de seguir.
- `docker compose version`: confirma que el plugin Compose v2 existe (se usa como `docker compose`, sin guion).
- `kind version`, `kubectl version --client`, `git --version`: confirman que están instaladas. `--client` evita que `kubectl` busque un clúster que todavía no existe.
- `curl --version | head -n 1`: muestra solo la primera línea de la versión.

### Paso 0.2: Verificar puertos libres

```bash
ss -ltn | grep -E ':(3000|222|8443|8080)\b' || echo "Puertos libres"
```

- `ss -ltn`: lista sockets TCP (`-t`) en escucha (`-l`) con puertos numéricos (`-n`).
- `grep -E`: filtra los cuatro puertos que necesito, con expresión regular extendida.
- `|| echo ...`: si `grep` no encuentra nada, imprime el mensaje. Si aparece alguna línea, ese puerto está ocupado y hay que liberarlo.

### Paso 0.3: Crear la estructura de directorios

```bash
mkdir -p /home/gmt/sre-linux-mastery/Fase5/WS_Easy/{infra,repo-app}
cd /home/gmt/sre-linux-mastery/Fase5/WS_Easy
```

- `mkdir -p`: crea toda la ruta y no falla si algún tramo ya existe.
- `{infra,repo-app}`: expansión de llaves de Bash. Crea las dos carpetas hijas con un solo comando.
- `infra/` guarda lo que monta la plataforma. `repo-app/` guarda el código que irá a Git.
- `cd`: me paso a la ruta base. **Todos los comandos siguientes se ejecutan desde aquí**, salvo que indique lo contrario.

**Comprobación:** `ls` muestra `infra` y `repo-app`.

---

## Fase 1: Levantar Gitea

**Meta:** tener un servidor Git propio, accesible desde el navegador y desde otros contenedores por nombre.

### Paso 1.1: Crear `infra/docker-compose.yml`

Directorio: `WS_Easy/`. Archivo que se crea: `infra/docker-compose.yml`.

```bash
cat << 'EOF' > infra/docker-compose.yml
networks:
  gitops-net:
    name: gitops-net
    driver: bridge

volumes:
  gitea-data:
    name: gitea-data

services:
  gitea:
    image: gitea/gitea:1.22.0
    container_name: local-gitea
    restart: always
    ports:
      - "3000:3000"
      - "222:22"
    volumes:
      - gitea-data:/data
    networks:
      - gitops-net
EOF
```

Sobre el comando:

- `cat << 'EOF' > archivo`: escribe en el archivo todo lo que va hasta la línea `EOF`. Las comillas simples en `'EOF'` evitan que Bash interprete variables dentro del texto, así que el contenido queda literal.

Sobre el archivo:

- `networks.gitops-net`: define una red virtual privada. Los contenedores que estén en ella se ven por nombre.
- `name: gitops-net`: fijo el nombre real de la red. Sin esto, Compose le antepone el nombre de la carpeta (`infra_gitops-net`) y el nombre cambia según desde dónde se lance.
- `driver: bridge`: tipo de red de Docker más común; aísla a los contenedores del resto.
- `volumes.gitea-data`: volumen con nombre fijo para los datos de Gitea (usuarios, repos, base SQLite). Lo declaro para poder borrarlo con certeza en la Fase 8.
- `image: gitea/gitea:1.22.0`: versión fija, para que la clase sea reproducible.
- `container_name: local-gitea`: este nombre es el que luego usará Argo CD para encontrar el servidor.
- `restart: always`: si el contenedor cae o se reinicia Docker, vuelve a levantarse.
- `ports "3000:3000"`: puerto del host a la izquierda, puerto del contenedor a la derecha. Es la web de Gitea.
- `ports "222:22"`: SSH de Gitea. No lo usamos, pero queda expuesto.
- `volumes gitea-data:/data`: monta el volumen en `/data`, donde Gitea guarda todo.

### Paso 1.2: Arrancar Gitea

```bash
docker compose -f infra/docker-compose.yml up -d
docker compose -f infra/docker-compose.yml ps
```

- `-f infra/docker-compose.yml`: indica qué archivo Compose usar, porque no estoy dentro de `infra/`.
- `up`: crea la red, el volumen y el contenedor, y descarga la imagen si hace falta.
- `-d`: modo *detached*, deja el contenedor corriendo en segundo plano.
- `ps`: lista el estado de los servicios del archivo.

**Comprobación:** `local-gitea` aparece como `running`.

### Paso 1.3: Instalación inicial desde el navegador

En Windows abro `http://localhost:3000`. Gitea muestra su asistente de instalación.

1. Dejo la base de datos en **SQLite3** (valor por defecto; no necesito nada más pesado).
2. Bajo hasta **Administrator Account Settings** y completo:
   - Administrator Username: `devops`
   - Password: `Devops12345`
   - Email: `devops@local.lan`
3. Pulso **Install Gitea** y espero a que cargue el panel.

El asistente existe porque Gitea arranca sin configurar. Aquí se crea la cuenta que usaremos para subir el código.

### Paso 1.4: Crear el repositorio vacío

En Gitea: **+** (arriba a la derecha) → **New Repository**.

- Repository Name: `easy-gitops`
- Visibility: **público**. Así Argo CD puede leerlo sin credenciales, que es lo que usa este laboratorio.
- **No** marco "Initialize Repository". Lo quiero totalmente vacío: el primer commit lo hago yo desde la terminal.

**Comprobación:** `http://localhost:3000/devops/easy-gitops` abre un repositorio vacío con instrucciones de clonado.

---

## Fase 2: Crear el clúster Kubernetes con KinD y conectarlo a Gitea

**Meta:** tener un clúster local con los puertos 8443 y 8080 del host apuntando a su interior, y que ese clúster pueda ver a Gitea por nombre.

### Paso 2.1: Crear `infra/kind-config.yaml`

```bash
cat << 'EOF' > infra/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: enterprise-gitops
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30443
    hostPort: 8443
    protocol: TCP
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
EOF
```

Sobre el archivo:

- `kind: Cluster` y `apiVersion`: dicen a KinD que este YAML describe un clúster.
- `name: enterprise-gitops`: nombre del clúster. El contenedor del nodo se llamará `enterprise-gitops-control-plane`, y ese nombre lo uso en el Paso 2.3.
- `nodes` con un solo `role: control-plane`: un único nodo que hace de plano de control y de trabajador. Para la clase sobra.
- `extraPortMappings`: publica puertos del contenedor-nodo en el host. Sin esto, el navegador de Windows no llega a nada dentro del clúster.
  - `containerPort: 30443` a `hostPort: 8443`: el NodePort donde expondré Argo CD.
  - `containerPort: 30080` a `hostPort: 8080`: el NodePort de la aplicación Nginx.
  - `protocol: TCP`: el protocolo de ambos puertos.

### Paso 2.2: Crear el clúster

```bash
kind create cluster --config infra/kind-config.yaml
kubectl get nodes
```

- `kind create cluster`: levanta Kubernetes dentro de un contenedor Docker.
- `--config`: usa el archivo que acabo de escribir en vez de los valores por defecto.
- `kubectl get nodes`: lista los nodos. KinD configura solo el contexto `kind-enterprise-gitops`, así que no hace falta nada más.

**Comprobación:** un nodo `enterprise-gitops-control-plane` en estado `Ready`.

### Paso 2.3: Conectar el nodo a la red de Gitea

```bash
docker network connect gitops-net enterprise-gitops-control-plane
docker exec enterprise-gitops-control-plane curl -sI http://local-gitea:3000
```

- `docker network connect <red> <contenedor>`: añade una segunda red a un contenedor que ya corre. El nodo KinD estaba solo en su red `kind`; ahora también está en `gitops-net`, igual que Gitea.
- `docker exec <contenedor> <comando>`: ejecuta un comando dentro del nodo.
- `curl -sI`: `-s` silencia la barra de progreso e `-I` pide solo las cabeceras. Es una prueba de conectividad barata.

**Comprobación:** la respuesta empieza con `HTTP/1.1 200 OK` (o una redirección 303 a `/user/login`, según el momento). Si dice que no resuelve `local-gitea`, el nodo no está en la red correcta.

---

## Fase 3: Instalar y exponer Argo CD

**Meta:** Argo CD corriendo en el clúster y accesible por `https://localhost:8443`, con la contraseña inicial en la mano.

### Paso 3.1: Instalar Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.4/manifests/install.yaml
```

- `create namespace argocd`: una carpeta lógica dentro del clúster donde vivirá todo Argo CD.
- `apply`: crea o actualiza los recursos que describe el manifiesto.
- `-n argocd`: los instala en ese namespace.
- `--server-side`: el clúster fusiona los cambios, en lugar de guardarlos como anotación en cada objeto. Con los CRDs de Argo CD, que son grandes, el modo normal falla por el límite de tamaño de la anotación `last-applied-configuration`.
- `-f <URL>`: lee el manifiesto oficial de la versión **v2.10.4** directamente desde internet. Es el único paso que lo requiere.

### Paso 3.2: Esperar a que esté disponible

```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl get pods -n argocd
```

- `kubectl wait`: bloquea la terminal hasta que se cumpla la condición.
- `--for=condition=available`: espera a que el Deployment tenga réplicas listas.
- `--timeout=300s`: si en 5 minutos no ocurre, aborta con error.
- `get pods -n argocd`: muestro los pods para ver el repertorio completo (servidor, controlador, repo-server, redis y otros).

**Comprobación:** todos los pods en `Running`. El controlador (`argocd-application-controller`) puede tardar unos segundos más que el servidor.

### Paso 3.3: Exponer el servidor como NodePort

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30443}]}}'
```

- `patch svc argocd-server`: modifica el Service existente sin reescribirlo.
- `-p '<json>'`: el cambio a aplicar.
- `"type":"NodePort"`: por defecto el servicio es `ClusterIP`, solo alcanzable desde dentro. `NodePort` abre un puerto en el nodo.
- `"port":443`: puerto del servicio al que se refiere este cambio (el HTTPS).
- `"targetPort":8080`: puerto del pod que atiende.
- `"nodePort":30443`: el puerto que abrí en KinD en el Paso 2.1 y que llega al host como 8443.

La cadena completa es: navegador → `localhost:8443` → nodo KinD `:30443` → servicio → pod `:8080`.

### Paso 3.4: Obtener la contraseña inicial

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

- `get secret argocd-initial-admin-secret`: Argo CD genera este secreto en la primera instalación con la clave del usuario `admin`.
- `-o jsonpath='{.data.password}'`: extrae solo el campo `password`.
- `| base64 -d`: Kubernetes guarda los secretos en base64; `-d` los decodifica.
- `; echo`: añade un salto de línea para que el prompt no quede pegado a la clave.

Copio el resultado. Lo uso en la Fase 6.

---

## Fase 4: Crear el código y cargarlo en Gitea

**Meta:** que Gitea contenga el manifiesto de Nginx, el estado deseado inicial.

### Paso 4.1: Crear `repo-app/deployment.yaml`

```bash
cat << 'EOF' > repo-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
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
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: default
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

Un solo archivo con dos recursos separados por `---`.

**Deployment `web-app`:**

- `replicas: 1`: cuántos pods quiero. **Este es el número que voy a cambiar en la Fase 7.**
- `selector.matchLabels` y `template.metadata.labels`: la etiqueta `app: web-app` es la que une al Deployment con sus pods. Tienen que coincidir.
- `image: nginx:1.25-alpine`: imagen ligera de Nginx, con versión fija.
- `containerPort: 80`: puerto donde escucha Nginx dentro del pod.

**Service `web-service`:**

- `type: NodePort`: abre un puerto en el nodo.
- `selector: app: web-app`: reparte tráfico entre los pods con esa etiqueta.
- `nodePort: 30080`: el puerto que KinD publica como 8080 en el host.

### Paso 4.2: Inicializar Git y subir a Gitea

```bash
cd repo-app
git init -b main
git config user.name "DevOps Engineer"
git config user.email "devops@local.lan"
git add deployment.yaml
git commit -m "feat: initial nginx deployment manifests"
git remote add origin 'http://devops:Devops12345@localhost:3000/devops/easy-gitops.git'
git push -u origin main
cd ..
```

- `cd repo-app`: este directorio, y solo este, es el repositorio.
- `git init -b main`: crea el repo local con la rama `main`.
- `git config user.name` / `user.email`: identidad de los commits. Sin `--global`, solo afecta a este repo.
- `git add deployment.yaml`: marca el archivo para el commit.
- `git commit -m`: guarda el cambio con su mensaje.
- `git remote add origin <URL>`: registra la dirección de Gitea con el nombre `origin`. Las comillas simples evitan que Bash interprete caracteres especiales de la clave. La URL lleva usuario y clave solo porque es un laboratorio local.
- `git push -u origin main`: sube la rama y fija `origin/main` como destino por defecto, así los siguientes `push` no necesitan argumentos.
- `cd ..`: vuelvo a la ruta base.

**Comprobación:** en `http://localhost:3000/devops/easy-gitops` aparece `deployment.yaml`.

---

## Fase 5: Conectar Argo CD con el repositorio

**Meta:** decirle a Argo CD qué repo vigilar y dónde desplegarlo.

### Paso 5.1: Crear `infra/argocd-app.yaml`

```bash
cat << 'EOF' > infra/argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: easy-gitops-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://local-gitea:3000/devops/easy-gitops.git
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
```

Sobre el archivo:

- `kind: Application`: un recurso propio de Argo CD (existe gracias a sus CRDs). Representa "este repo va a este destino".
- `metadata.namespace: argocd`: las `Application` deben vivir en el namespace de Argo CD, aunque desplieguen en otro.
- `finalizers: resources-finalizer.argocd.argoproj.io`: si borro la `Application`, Argo CD también borra los recursos que creó. Sin esto, quedarían huérfanos.
- `project: default`: proyecto de Argo CD que trae por defecto, sin restricciones.
- `source.repoURL`: dirección del repo. Uso `local-gitea:3000` y no `localhost`, porque Argo CD corre **dentro** del clúster. Para él, `localhost` sería él mismo.
- `targetRevision: HEAD`: sigue el último commit de la rama por defecto.
- `path: .`: carpeta del repo donde están los manifiestos. Aquí es la raíz, porque `deployment.yaml` está suelto.
- `destination.server: https://kubernetes.default.svc`: la dirección interna del propio clúster donde corre Argo CD.
- `destination.namespace: default`: namespace de destino.
- `automated`: Argo CD sincroniza solo, sin que yo pulse nada.
- `prune: true`: si quito un recurso de Git, lo borra del clúster.
- `selfHeal: true`: si alguien cambia algo a mano en el clúster, lo revierte al estado de Git.
- `CreateNamespace=true`: crea el namespace de destino si no existe.

### Paso 5.2: Aplicar la Application

```bash
kubectl apply -f infra/argocd-app.yaml
kubectl get application easy-gitops-app -n argocd
kubectl get pods -n default
```

- `apply -f`: crea el recurso en el clúster. Es el **último** `apply` manual de la clase; desde aquí manda Git.
- `get application`: muestra sincronización y salud. Tarda unos segundos en pasar a `Synced` y `Healthy`.
- `get pods -n default`: aparece un pod `web-app-...` creado por Argo CD, no por mí.

Si la `Application` queda en `Unknown` o con error de conexión al repo, vuelvo al Paso 2.3. Casi siempre es que el nodo no está en `gitops-net`.

---

## Fase 6: Estado inicial, antes del cambio

**Meta:** que los alumnos vean el punto de partida, para comparar después.

### Paso 6.1: Entrar a Argo CD

1. Abro `https://localhost:8443`.
2. El navegador avisa de un certificado no confiable. Es autofirmado y es esperado; acepto el riesgo y continúo.
3. Usuario `admin` y la clave del Paso 3.4.

### Paso 6.2: Qué debe verse

- La tarjeta `easy-gitops-app` con dos etiquetas verdes: **Synced** (el clúster coincide con el commit de Git) y **Healthy** (los recursos funcionan).
- Al abrirla, el árbol de recursos: `Application` → `web-service` (Service) y `web-app` (Deployment) → ReplicaSet → **1 Pod**.
- Anoto el commit que muestra Argo CD: es el que Git tiene ahora.

### Paso 6.3: Verificar la aplicación desde la terminal

```bash
kubectl get deployment web-app -n default
curl -sI http://localhost:8080
```

- Primer comando: la columna `READY` marca `1/1`.
- `curl -sI http://localhost:8080`: debería responder `HTTP/1.1 200 OK` con la cabecera `Server: nginx`. Es la cadena host → NodePort 30080 → pod.

Este es el estado base: **1 réplica**, `Synced`, `Healthy`.

---

## Fase 7: Incremento de réplicas y cómo se refleja

Hago dos pruebas. La primera es el camino correcto en GitOps: cambiar Git. La segunda es el camino que GitOps corrige: cambiar el clúster a mano.

```mermaid
sequenceDiagram
    participant I as Instructor
    participant G as Gitea
    participant A as Argo CD
    participant K as Clúster

    Note over I,K: Prueba A: el cambio entra por Git
    I->>G: git push (replicas: 3)
    A->>G: detecta commit nuevo
    A->>K: sincroniza, crea 2 pods más
    K-->>A: 3 pods, Synced y Healthy

    Note over I,K: Prueba B: el cambio entra al clúster
    I->>K: kubectl scale --replicas=5
    A->>K: detecta diferencia con Git
    A->>K: self-heal, vuelve a 3
```

### Prueba A: subir réplicas desde Git

**Paso 7.1: Editar y subir el cambio**

```bash
sed -i 's/replicas: 1/replicas: 3/' repo-app/deployment.yaml
cd repo-app
git add deployment.yaml
git commit -m "scale: web-app a 3 replicas"
git push
cd ..
```

- `sed -i 's/replicas: 1/replicas: 3/'`: reemplaza el texto directamente en el archivo (`-i` edita en el sitio). Abrir el archivo en un editor y cambiar el número a mano es equivalente.
- `git add`, `git commit`, `git push`: el mismo ciclo de siempre. Como en el Paso 4.2 usé `-u`, el `push` no necesita más argumentos.

**Paso 7.2: Acelerar la detección (opcional)**

Argo CD consulta el repo cada 3 minutos por defecto. Para no esperar:

```bash
kubectl annotate application easy-gitops-app -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

- `annotate`: añade una anotación a la `Application`.
- `argocd.argoproj.io/refresh=hard`: le pide a Argo CD que vuelva a leer el repo ahora y descarte su caché.
- `--overwrite`: permite repetir el comando si la anotación ya existe.

Desde el navegador se consigue lo mismo con el botón **Refresh** de la tarjeta.

**Paso 7.3: Observar**

Dejo esto corriendo en una terminal:

```bash
kubectl get pods -n default -w
```

- `-w` (watch): la terminal queda escuchando y muestra cada cambio de estado de los pods.

Y miro el navegador:

- La tarjeta pasa brevemente a **OutOfSync** (hay un commit nuevo que el clúster aún no refleja) y luego a **Syncing**.
- En el árbol de recursos aparecen **tres pods** bajo el ReplicaSet.
- Termina en **Synced** y **Healthy**, con el commit nuevo.

Comprobación: `kubectl get deployment web-app -n default` muestra `3/3`. Salgo del modo watch con `Ctrl+C`.

### Prueba B: drift y self-heal

El estado deseado en Git es ahora 3. Fuerzo a 5 para que el cambio sea inconfundible.

**Paso 7.4: Alterar el clúster saltándome Git**

```bash
kubectl scale deployment web-app --replicas=5 -n default
kubectl get pods -n default -w
```

- `kubectl scale`: cambia el número de réplicas directamente en el clúster, sin pasar por Git. Eso es el *drift*.
- `-w`: observo en vivo cómo aparecen y desaparecen pods.

Lo que se ve: aparecen cinco pods, y a los pocos segundos Argo CD detecta que Git dice 3, aplica `selfHeal` y los dos pods sobrantes se eliminan. El Deployment queda en `3/3`.

**Paso 7.5: Ver el OutOfSync con calma (opcional)**

El autorreparado es tan rápido que **OutOfSync** puede verse un instante o no verse. Para que los alumnos lo vean fijo, desactivo `selfHeal` un momento:

```bash
kubectl patch application easy-gitops-app -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'
kubectl scale deployment web-app --replicas=5 -n default
```

- `patch --type merge`: fusiona el cambio con la `Application` existente y conserva `prune: true`.
- `selfHeal: false`: Argo CD sigue sincronizando cambios de Git, pero deja de revertir los cambios manuales.

En el navegador:

- La tarjeta queda en **OutOfSync**, de color amarillo, y se queda así.
- Al abrirla, **App Diff** muestra la diferencia: `replicas: 3` en Git contra `replicas: 5` en el clúster.
- Hay cinco pods corriendo, pero Argo CD avisa de que ese estado no es el declarado.

Ahora lo reactivo y observo la corrección:

```bash
kubectl patch application easy-gitops-app -n argocd --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true}}}}'
kubectl get pods -n default -w
```

En pocos segundos la tarjeta vuelve a **Synced** y los pods bajan de 5 a 3.

**Paso 7.6: Validación final**

```bash
kubectl get deployment web-app -n default
kubectl get application easy-gitops-app -n argocd
```

Esperado: `READY 3/3`, `SYNC STATUS Synced`, `HEALTH STATUS Healthy`.

La idea que quiero que se lleven: **la verdad está en Git**. Subir réplicas por Git es un cambio legítimo; hacerlo por `kubectl` es una desviación que Argo CD marca y corrige.

---

## Fase 8: Eliminación del laboratorio

**Meta:** dejar la máquina como si el laboratorio nunca hubiera existido.

El orden no es arbitrario. El nodo de KinD está conectado a `gitops-net`; hay que borrar el clúster antes de que Docker pueda eliminar la red.

```bash
cd /home/gmt/sre-linux-mastery/Fase5

# 1. Clúster Kubernetes (borra también el contexto de kubectl)
kind delete cluster --name enterprise-gitops

# 2. Gitea, su red y su volumen de datos
docker compose -f WS_Easy/infra/docker-compose.yml down -v

# 3. Archivos del laboratorio
rm -rf WS_Easy

echo "Laboratorio destruido"
```

- `cd .../Fase5`: salgo de `WS_Easy` antes de borrarlo; no se puede borrar el directorio en el que se está.
- `kind delete cluster --name`: elimina el contenedor del nodo y quita el contexto `kind-enterprise-gitops` del kubeconfig. Con él se van Argo CD, la `Application` y Nginx.
- `docker compose ... down`: detiene y elimina el contenedor `local-gitea` y la red `gitops-net`.
- `-v`: elimina además el volumen `gitea-data`. Sin esta opción, el usuario `devops` y el repositorio sobrevivirían a la próxima corrida.
- `rm -rf WS_Easy`: borra recursivamente (`-r`) y sin confirmaciones (`-f`) todos los archivos del taller, incluidos `README.md` y `runbook.md`. Si quiero conservar los documentos, los copio antes a otra ruta.

### Verificación de que no queda nada

```bash
kind get clusters
docker ps -a --filter name=local-gitea
docker network ls --filter name=gitops-net
docker volume ls --filter name=gitea-data
```

Los cuatro comandos deben salir vacíos (el primero dice `No kind clusters found.`). Para volver a empezar, repito el runbook desde la Fase 0.

