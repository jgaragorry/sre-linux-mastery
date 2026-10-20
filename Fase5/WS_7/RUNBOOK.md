<div align="center">

# Runbook: Laboratorio 2, Argo CD con Repositorio Propio

![Fases](https://img.shields.io/badge/Fases-11-EF7B4D?style=for-the-badge)
![Riesgo](https://img.shields.io/badge/Riesgo-Bajo%20(local)-2EA44F?style=for-the-badge)

</div>

---

## Convenciones

* `${USUARIO}`: tu usuario de GitHub. Se define una sola vez al inicio (Fase 1) como variable de entorno.
* Los bloques **Comando** se ejecutan en WSL2.
* Los bloques **Validación** indican qué debes ver antes de avanzar a la siguiente fase.
* Si cierras la terminal y la reabres, vuelve a ejecutar `export USUARIO=...` antes de continuar.

---

## Fase 1. Crear el clúster kind

**Objetivo:** Disponer de un Kubernetes local desechable con el nombre exacto que usará el resto del laboratorio.

```mermaid
flowchart LR
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff

    C[kind create cluster] --> N[Contenedor Docker]
    N --> V([Nodo Ready])

    class C cmd
    class N k8s
    class V ok
```

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

**Comando:**

```bash
kubectl get pods -n mi-app
```

**Validación:** Deben verse 2 pods de nginx en estado `Running`.

---

## Fase 8. Cambio en Git y medición de latencia

**Objetivo:** Demostrar que el clúster reacciona a un cambio hecho puramente en Git.

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

**Prueba A (prune):**

```bash
cd ~/argocd-lab-2/repo-git
git rm service.yaml && git commit -m "chore: eliminar service" && git push
kubectl annotate application mi-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
sleep 15
kubectl get svc -n mi-app
```

**Validación A:** El Service desaparece del clúster.

**Prueba B (selfHeal):**

```bash
kubectl scale deploy mi-app -n mi-app --replicas=10
sleep 15
kubectl get deploy mi-app -n mi-app
```

**Validación B:** Argo CD revierte las réplicas al valor de Git (5).

---

## Fase 10. Rollback con git revert

**Objetivo:** Restaurar el Service eliminado en la Fase 9 sin tocar el clúster.

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

| Síntoma | Causa probable | Acción |
| :--- | :--- | :--- |
| `ComparisonError` o repo en estado `Failed` | Error de autenticación SSH. | Verifica que la Deploy key esté registrada en GitHub (Fase 5, paso 2) y que el Secret tenga la clave privada correcta. |
| `OutOfSync` persistente | Cambio manual en el clúster con `selfHeal` desactivado, o `path` incorrecto en la Application. | Revisa `syncPolicy` y `spec.source.path` en el YAML de la Application (Fase 6). |
| `ImagePullBackOff` | Problema de red o nombre de imagen incorrecto. | `kubectl describe pod -n mi-app` para ver el error. |
| Puerto 8080 ocupado | Otro servicio en WSL. | Usa otro puerto: `kubectl port-forward svc/argocd-server -n argocd 9090:443`. |
| `repoURL` con `<USUARIO>` o vacío | La variable `USUARIO` no estaba definida en esa terminal. | Ejecuta `export USUARIO=tu_usuario` y repite el comando. |
| `kubectl wait` agota el timeout | Se esperó por pods que no llegan a `Ready`. | Usa los comandos de la Fase 2 (`Deployment` y `StatefulSet`). |

