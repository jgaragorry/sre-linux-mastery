<div align="center">

# Runbook: Laboratorio 2, Argo CD con Repositorio Propio

![Tipo](https://img.shields.io/badge/Documento-Runbook-0969DA?style=for-the-badge)
![Fases](https://img.shields.io/badge/Fases-12-EF7B4D?style=for-the-badge)
![Argo CD](https://img.shields.io/badge/Argo%20CD-stable-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![kind](https://img.shields.io/badge/kind-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Riesgo](https://img.shields.io/badge/Riesgo-Bajo%20(local)-2EA44F?style=for-the-badge)

</div>

---

## Convenciones

| Marcador | Significado |
|---|---|
| `<USUARIO>` | Tu usuario de GitHub; reemplázalo en cada comando |
| Bloque **Comando** | Se ejecuta tal cual en la terminal de WSL2 |
| Bloque **Validación** | Resultado esperado antes de avanzar |
| Bloque **Si falla** | Diagnóstico rápido |

## Mapa de fases

| Fase | Nombre | Categoría | Duración |
|---|---|---|---|
| 0 | Verificación de requisitos | Preparación | 2 min |
| 1 | Crear clúster kind | Infraestructura | 3 min |
| 2 | Instalar Argo CD | Infraestructura | 4 min |
| 3 | Acceder a la UI | Infraestructura | 2 min |
| 4 | Crear repositorio propio | Fuente de verdad | 5 min |
| 5 | Generar credencial SSH | Seguridad | 3 min |
| 6 | Registrar repositorio en Argo CD | Seguridad | 3 min |
| 7 | Crear la Application | GitOps | 3 min |
| 8 | Verificar Synced y Healthy | Validación | 2 min |
| 9 | Cambio en Git y medición | Prueba | 6 min |
| 10 | Prune y selfHeal | Prueba | 6 min |
| 11 | Rollback con git revert | Prueba | 4 min |
| 12 | Limpieza | Cierre | 1 min |

---

## Fase 0. Verificación de requisitos

**Objetivo:** confirmar que las herramientas están disponibles antes de crear nada.

```mermaid
flowchart LR
    S([Inicio]):::s --> D{docker ps<br/>responde?}:::d
    D -- Sí --> K{kind y kubectl<br/>instalados?}:::d
    D -- No --> FD[Iniciar Docker<br/>Desktop o servicio]:::f
    FD --> D
    K -- Sí --> G{SSH a GitHub<br/>funciona?}:::d
    K -- No --> FK[Instalar<br/>herramientas]:::f
    FK --> K
    G -- Sí --> OK([Listo para Fase 1]):::ok
    G -- No --> FG[Configurar<br/>clave SSH]:::f
    FG --> G

    classDef s fill:#57606A,stroke:#24292F,color:#fff
    classDef d fill:#B08800,stroke:#6B5400,color:#fff
    classDef f fill:#CF222E,stroke:#82071E,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
```

| Elemento | Leyenda |
|---|---|
| Rombos dorados | Puntos de decisión; cada uno verifica una dependencia |
| Rectángulos rojos | Acción correctiva; tras ejecutarla se vuelve a la decisión |
| Óvalo verde | Condición de salida: todas las dependencias están cubiertas |
| Óvalo gris | Punto de entrada |

**Comando**

```bash
docker ps
kind version
kubectl version --client
git --version
ssh -T git@github.com
```

**Validación:** `docker ps` lista cabeceras sin error y `ssh -T` responde `Hi <USUARIO>! You've successfully authenticated`.

---

## Fase 1. Crear clúster kind

**Objetivo:** disponer de un Kubernetes local desechable.

```mermaid
flowchart LR
    C[kind create cluster]:::cmd --> N[Contenedor Docker<br/>control-plane]:::k8s
    N --> KC[Kubeconfig actualizado<br/>~/.kube/config]:::cfg
    KC --> V([kubectl get nodes<br/>Ready]):::ok

    classDef cmd fill:#57606A,stroke:#24292F,color:#fff
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff
    classDef cfg fill:#B08800,stroke:#6B5400,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
```

| Elemento | Leyenda |
|---|---|
| Comando (gris) | Instrucción ejecutada por el operador |
| Contenedor control-plane (azul) | Nodo único que aloja API server, etcd y kubelet |
| Kubeconfig (dorado) | kind registra el contexto `kind-argo-lab2` para `kubectl` |
| Resultado (verde) | Nodo en estado `Ready` |

**Comando**

```bash
kind create cluster --name argo-lab2
kubectl cluster-info --context kind-argo-lab2
kubectl get nodes
```

**Validación:** nodo `argo-lab2-control-plane` en `Ready`.

**Si falla:** `docker ps` para confirmar Docker activo; `kind delete cluster --name argo-lab2` y reintentar.

---

## Fase 2. Instalar Argo CD

**Objetivo:** desplegar el motor GitOps en el namespace `argocd`.

```mermaid
flowchart TD
    NS[Crear namespace argocd]:::cmd --> AP[Aplicar install.yaml<br/>manifiesto oficial]:::cmd
    AP --> CRD[CRDs: Application,<br/>AppProject]:::cfg
    AP --> PODS
    subgraph PODS[Pods de Argo CD]
        S[argocd-server<br/>UI y API]:::argo
        R[argocd-repo-server<br/>clona Git]:::argo
        C[application-controller<br/>reconcilia]:::argo
        RD[redis<br/>caché]:::argo
    end
    PODS --> W([Todos Running]):::ok

    classDef cmd fill:#57606A,stroke:#24292F,color:#fff
    classDef cfg fill:#B08800,stroke:#6B5400,color:#fff
    classDef argo fill:#EF7B4D,stroke:#B3501F,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
```

| Componente | Función |
|---|---|
| CRDs (dorado) | Extienden la API de Kubernetes con el tipo `Application` |
| argocd-server | Expone la interfaz web y la API |
| argocd-repo-server | Clona repositorios Git y genera los manifiestos finales |
| application-controller | Compara estado deseado vs. real y sincroniza |
| redis | Caché interna de estado |

**Comando**

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
kubectl get pods -n argocd
```

**Validación:** todos los pods en `Running` y `1/1` o `2/2` en READY.

**Si falla:** `kubectl describe pod <pod> -n argocd`. Causas comunes: falta de memoria o descarga de imágenes lenta; esperar y repetir `kubectl wait`.

---

## Fase 3. Acceder a la UI

**Objetivo:** iniciar sesión como `admin`.

```mermaid
sequenceDiagram
    autonumber
    participant O as Operador
    participant K as kubectl
    participant S as argocd-server
    O->>K: get secret argocd-initial-admin-secret
    K-->>O: Contraseña inicial (base64)
    O->>K: port-forward svc/argocd-server 8080:443
    K->>S: Túnel localhost:8080
    O->>S: https://localhost:8080 (admin + contraseña)
    S-->>O: Dashboard de Argo CD
```

| Paso | Leyenda |
|---|---|
| 1 y 2 | Se lee el secret donde Argo CD guarda la contraseña generada en la instalación |
| 3 y 4 | `port-forward` crea un túnel entre tu máquina y el servicio interno |
| 5 y 6 | Acceso por HTTPS; el navegador advertirá certificado autofirmado, es esperado |

**Comando** (terminal 1, mantener abierta)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Validación:** abrir `https://localhost:8080` e ingresar con usuario `admin`.

> Usa una segunda terminal para las fases siguientes.

---

## Fase 4. Crear repositorio propio

**Objetivo:** construir la fuente de verdad con los manifiestos de la aplicación.

```mermaid
flowchart LR
    GH[Crear repo vacío<br/>argocd-lab2-app]:::git --> CL[git clone]:::cmd
    CL --> MF[Crear k8s/<br/>3 manifiestos]:::cfg
    MF --> CM[git commit]:::cmd
    CM --> PS([git push origin main]):::ok

    classDef git fill:#24292F,stroke:#000,color:#fff
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff
    classDef cfg fill:#B08800,stroke:#6B5400,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
```

| Archivo | Contenido |
|---|---|
| `namespace.yaml` | Namespace `demo` donde vivirá la aplicación |
| `deployment.yaml` | Deployment `web` con nginx y 2 réplicas |
| `service.yaml` | Service `web` tipo ClusterIP en el puerto 80 |

**Comando** (crear primero un repositorio vacío en GitHub llamado `argocd-lab2-app`)

```bash
cd ~ && git clone git@github.com:<USUARIO>/argocd-lab2-app.git && cd argocd-lab2-app
mkdir k8s

cat > k8s/namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: demo
EOF

cat > k8s/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels: { app: web }
  template:
    metadata:
      labels: { app: web }
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports: [{ containerPort: 80 }]
EOF

cat > k8s/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: demo
spec:
  selector: { app: web }
  ports: [{ port: 80, targetPort: 80 }]
EOF

git add . && git commit -m "feat: manifiestos iniciales" && git branch -M main && git push -u origin main
```

**Validación:** los tres archivos visibles en GitHub bajo `k8s/`.

---

## Fase 5. Generar credencial SSH

**Objetivo:** crear un par de claves dedicado y de solo lectura para Argo CD.

```mermaid
flowchart LR
    KG[ssh-keygen<br/>ed25519]:::cmd --> PR[Clave privada<br/>argocd_lab2]:::sec
    KG --> PU[Clave pública<br/>argocd_lab2.pub]:::git
    PU --> DK[Deploy key en GitHub<br/>solo lectura]:::git
    PR --> NX[Se entrega a Argo CD<br/>en Fase 6]:::argo

    classDef cmd fill:#57606A,stroke:#24292F,color:#fff
    classDef sec fill:#CF222E,stroke:#82071E,color:#fff
    classDef git fill:#24292F,stroke:#000,color:#fff
    classDef argo fill:#EF7B4D,stroke:#B3501F,color:#fff
```

| Elemento | Leyenda |
|---|---|
| Clave privada (rojo) | Secreto; nunca se sube a Git ni se comparte |
| Clave pública (negro) | Se registra en GitHub como Deploy key |
| Deploy key | Credencial limitada a un único repositorio; principio de mínimo privilegio |

**Comando**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/argocd_lab2 -C "argocd-lab2" -N ""
cat ~/.ssh/argocd_lab2.pub
```

En GitHub: repositorio, **Settings**, **Deploy keys**, **Add deploy key**; pegar la clave pública, dejar **Allow write access** desactivado y guardar.

**Validación:** la deploy key aparece listada en el repositorio.

---

## Fase 6. Registrar el repositorio en Argo CD

**Objetivo:** entregar a Argo CD la URL y la clave privada mediante un Secret declarativo.

```mermaid
flowchart LR
    SEC[Secret repo-lab2<br/>url, type, sshPrivateKey]:::sec --> LB[Etiqueta<br/>secret-type=repository]:::cfg
    LB --> DET[Argo CD detecta<br/>el repositorio]:::argo
    DET --> CON{Conexión<br/>exitosa?}:::d
    CON -- Sí --> OK([Estado Successful]):::ok
    CON -- No --> ER[Revisar deploy key<br/>y URL SSH]:::f

    classDef sec fill:#CF222E,stroke:#82071E,color:#fff
    classDef cfg fill:#B08800,stroke:#6B5400,color:#fff
    classDef argo fill:#EF7B4D,stroke:#B3501F,color:#fff
    classDef d fill:#8250DF,stroke:#4C2889,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
    classDef f fill:#57606A,stroke:#24292F,color:#fff
```

| Elemento | Leyenda |
|---|---|
| Secret | Contiene la URL SSH, el tipo `git` y la clave privada |
| Etiqueta `argocd.argoproj.io/secret-type=repository` | Indica a Argo CD que este Secret es una credencial de repositorio |
| Decisión | Argo CD intenta conectar; el resultado se ve en la UI |

**Comando**

```bash
kubectl create secret generic repo-lab2 -n argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:<USUARIO>/argocd-lab2-app.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd_lab2
kubectl label secret repo-lab2 -n argocd argocd.argoproj.io/secret-type=repository
```

**Validación:** UI, **Settings**, **Repositories**: estado **Successful**.

**Si falla:** confirmar que la URL usa formato `git@github.com:` y que la deploy key corresponde a la clave pública.

---

## Fase 7. Crear la Application

**Objetivo:** vincular repositorio, ruta y destino con sincronización automática.

```mermaid
flowchart LR
    APP[Application lab2-app]:::argo --> SRC[Origen<br/>repoURL, path k8s,<br/>HEAD]:::git
    APP --> DST[Destino<br/>clúster local,<br/>namespace demo]:::k8s
    APP --> POL[Política automatizada]:::cfg
    POL --> P1[prune: true<br/>borra huérfanos]:::cfg
    POL --> P2[selfHeal: true<br/>revierte deriva]:::cfg
    POL --> P3[CreateNamespace<br/>si falta]:::cfg

    classDef argo fill:#EF7B4D,stroke:#B3501F,color:#fff
    classDef git fill:#24292F,stroke:#000,color:#fff
    classDef k8s fill:#326CE5,stroke:#1B3F94,color:#fff
    classDef cfg fill:#B08800,stroke:#6B5400,color:#fff
```

| Campo | Leyenda |
|---|---|
| `source.path` | Carpeta del repositorio que se sincroniza |
| `destination.server` | `https://kubernetes.default.svc` representa el clúster donde corre Argo CD |
| `prune` | Elimina del clúster lo que se borra de Git |
| `selfHeal` | Deshace cambios manuales hechos con `kubectl` |

**Comando**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lab2-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:<USUARIO>/argocd-lab2-app.git
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

**Validación:** la aplicación `lab2-app` aparece en el dashboard.

---

## Fase 8. Verificar Synced y Healthy

```mermaid
stateDiagram-v2
    [*] --> OutOfSync: Application creada
    OutOfSync --> Syncing: Sincronización automática
    Syncing --> Synced: Recursos aplicados
    Synced --> Healthy: Pods Ready
    Healthy --> [*]
    Syncing --> Degraded: Error en recurso
    Degraded --> Syncing: Corrección en Git
```

| Estado | Leyenda |
|---|---|
| OutOfSync | Git y clúster difieren; estado inicial |
| Syncing | Argo CD está aplicando los manifiestos |
| Synced | El clúster coincide con Git |
| Healthy | Los pods están listos; objetivo de esta fase |
| Degraded | Algún recurso falla; se corrige en Git, no en el clúster |

**Comando**

```bash
kubectl get application lab2-app -n argocd
kubectl get all -n demo
```

**Validación:** columnas `SYNC STATUS = Synced` y `HEALTH STATUS = Healthy`; 2 pods `web` en `Running`.

---

## Fase 9. Cambio en Git y medición de latencia

**Objetivo:** observar la propagación Git a clúster y medir el tiempo de reacción.

```mermaid
sequenceDiagram
    autonumber
    participant D as Desarrollador
    participant G as GitHub
    participant A as Argo CD
    participant K as Clúster
    D->>G: push (replicas 2 a 4)
    Note over A: Polling cada 3 min por defecto
    A->>G: Consulta cambios
    G-->>A: Nuevo commit
    A->>K: Aplica diff
    K-->>A: 4 réplicas Ready
    A-->>D: Synced y Healthy
```

| Paso | Leyenda |
|---|---|
| 1 | El cambio se hace solo en Git |
| Nota | Sin webhook, Argo CD detecta por sondeo; la latencia máxima ronda 3 minutos |
| 3 a 5 | Argo CD compara, aplica la diferencia y confirma salud |

**Comando**

```bash
cd ~/argocd-lab2-app
sed -i 's/replicas: 2/replicas: 4/' k8s/deployment.yaml
git commit -am "feat: escalar a 4 replicas" && git push
date +%T
kubectl get deploy web -n demo -w
```

Para acelerar la detección (medición con refresh forzado):

```bash
kubectl annotate application lab2-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

**Registro de mediciones**

| Escenario | Hora del push | Hora de 4 réplicas | Latencia |
|---|---|---|---|
| Polling natural | | | |
| Refresh forzado | | | |

**Validación:** `kubectl get deploy web -n demo` muestra `4/4`.

---

## Fase 10. Prune y selfHeal

**Objetivo:** comprobar que Git manda sobre el clúster en ambos sentidos.

```mermaid
flowchart TD
    subgraph PRUNE[Prueba A: prune]
        A1[git rm k8s/service.yaml<br/>+ push]:::git --> A2[Service queda huérfano]:::cfg
        A2 --> A3([Argo CD elimina el Service]):::ok
    end
    subgraph HEAL[Prueba B: selfHeal]
        B1[kubectl scale<br/>replicas=10]:::cmd --> B2[Deriva detectada<br/>OutOfSync]:::cfg
        B2 --> B3([Argo CD restaura<br/>réplicas de Git]):::ok
    end

    classDef git fill:#24292F,stroke:#000,color:#fff
    classDef cmd fill:#CF222E,stroke:#82071E,color:#fff
    classDef cfg fill:#B08800,stroke:#6B5400,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
```

| Elemento | Leyenda |
|---|---|
| Prueba A (negro) | El cambio legítimo viaja por Git y Argo CD limpia lo que ya no existe |
| Prueba B (rojo) | El cambio ilegítimo se hace directo en el clúster y es revertido |
| Verde | Resultado esperado de cada prueba |

**Comando: prueba A**

```bash
cd ~/argocd-lab2-app
git rm k8s/service.yaml && git commit -m "chore: eliminar service" && git push
kubectl annotate application lab2-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get svc -n demo
```

**Comando: prueba B**

```bash
kubectl scale deploy web -n demo --replicas=10
kubectl get deploy web -n demo -w
```

**Validación:** A, el Service `web` desaparece. B, las réplicas regresan al valor de Git (4).

---

## Fase 11. Rollback con git revert

**Objetivo:** restaurar el Service sin tocar el clúster.

```mermaid
flowchart LR
    H1[Commit 3<br/>eliminar service]:::bad --> RV[git revert HEAD]:::cmd
    RV --> H2[Commit 4<br/>restaura service]:::ok
    H2 --> PS[git push]:::cmd
    PS --> AR[Argo CD recrea<br/>el Service]:::argo

    classDef bad fill:#CF222E,stroke:#82071E,color:#fff
    classDef cmd fill:#57606A,stroke:#24292F,color:#fff
    classDef ok fill:#2EA44F,stroke:#1A6B31,color:#fff
    classDef argo fill:#EF7B4D,stroke:#B3501F,color:#fff
```

| Elemento | Leyenda |
|---|---|
| Commit rojo | Cambio que se desea deshacer |
| `git revert` | Crea un commit inverso; conserva el historial y es seguro en ramas compartidas |
| Commit verde | Nuevo estado deseado: el Service vuelve a existir |

**Comando**

```bash
cd ~/argocd-lab2-app
git revert HEAD --no-edit && git push
kubectl annotate application lab2-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get svc -n demo
```

**Validación:** el Service `web` reaparece y la aplicación vuelve a `Synced` y `Healthy`.

---

## Fase 12. Limpieza

```bash
kind delete cluster --name argo-lab2
rm ~/.ssh/argocd_lab2 ~/.ssh/argocd_lab2.pub
```

Eliminar además la deploy key en GitHub si el repositorio se conserva.

---

## Resolución de problemas

| Síntoma | Causa probable | Acción |
|---|---|---|
| Repositorio con estado `Failed` | Deploy key ausente o URL en formato HTTPS | Verificar clave y usar `git@github.com:` |
| `ComparisonError` | Ruta `path` incorrecta o YAML inválido | Revisar `k8s/` y la sintaxis |
| Aplicación `OutOfSync` persistente | Sincronización automática desactivada | Confirmar bloque `automated` |
| UI inaccesible | `port-forward` cerrado | Reiniciar el comando de la Fase 3 |
| Pods en `Pending` | Recursos insuficientes en WSL2 | Aumentar memoria en `.wslconfig` |
| `ImagePullBackOff` | Sin red o límite de pulls | Reintentar o revisar conectividad |

## Criterios de aceptación

- [ ] Repositorio registrado como `Successful`
- [ ] Aplicación `Synced` y `Healthy`
- [ ] Cambio de réplicas propagado desde Git
- [ ] Latencias registradas en la tabla de la Fase 9
- [ ] Prune y selfHeal verificados
- [ ] Rollback con `git revert` verificado

## Referencias

- Documentación oficial de Argo CD: https://argo-cd.readthedocs.io
- kind: https://kind.sigs.k8s.io

