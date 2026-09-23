# Runbook: Fundamentos Operativos de Kubernetes con Kind en WSL2

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29+-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![Kind](https://img.shields.io/badge/Kind-v0.24.0-2496ED?style=flat-square&logo=docker&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Ubuntu%2024.04%20LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Nivel](https://img.shields.io/badge/Nivel-Introductorio-yellow?style=flat-square)
![Duración](https://img.shields.io/badge/Duración-45--60%20min-informational?style=flat-square)
![Estado](https://img.shields.io/badge/Estado-Listo%20para%20usar-success?style=flat-square)

---

## Índice

1. [Objetivo del runbook](#objetivo-del-runbook)
2. [Requisitos del entorno](#requisitos-del-entorno)
3. [Fase 1 — Instalación de herramientas de control](#fase-1--instalación-de-herramientas-de-control)
4. [Fase 2 — Aprovisionamiento del clúster](#fase-2--aprovisionamiento-del-clúster)
5. [Fase 3 — Despliegue y autorreparación](#fase-3--despliegue-y-autorreparación)
6. [Fase 4 — Exposición de servicios](#fase-4--exposición-de-servicios)
7. [Fase 5 — Escalado horizontal](#fase-5--escalado-horizontal)
8. [Fase 6 — Desmantelamiento controlado](#fase-6--desmantelamiento-controlado)
9. [Solución de problemas comunes](#solución-de-problemas-comunes)
10. [Glosario rápido](#glosario-rápido)
11. [Cierre y siguientes pasos](#cierre-y-siguientes-pasos)

---

## Objetivo del runbook

Este documento guía, paso a paso, la construcción de un clúster de Kubernetes local usando **Kind** sobre **WSL2**. El propósito no es solo ejecutar comandos, sino entender qué hace cada uno y por qué existe. Al terminar, vas a haber tocado con tus propias manos los cuatro pilares operativos de Kubernetes: el plano de control, el ciclo de vida de los Pods, la autorreparación y el escalado de cargas de trabajo.

> **Cómo usar este runbook:** cada fase sigue la misma estructura: qué se hace, por qué se hace, los comandos exactos, cómo verificar que salió bien, y qué deberías haber aprendido. No saltes la verificación: es la parte que confirma que el paso anterior realmente funcionó.

---

## Requisitos del entorno

| Componente | Requisito |
|---|---|
| Sistema operativo | Ubuntu 24.04 LTS sobre WSL2 |
| Motor de contenedores | Docker Engine instalado y en ejecución |
| Permisos | Usuario perteneciente al grupo `docker` (evita usar `sudo` en cada comando) |

### Verificación inicial

```bash
docker ps
```

Si el comando devuelve la cabecera de la tabla de contenedores sin errores de permisos ni fallos de conexión al socket, el entorno está listo. Si en cambio aparece un error de tipo `permission denied` al hablar con el socket de Docker, revisa la sección de [solución de problemas](#solución-de-problemas-comunes) antes de continuar.

---

## Fase 1 — Instalación de herramientas de control

![Fase](https://img.shields.io/badge/Fase-1%20de%206-blue?style=flat-square)

### Qué se hace

Se instalan dos binarios en el sistema anfitrión:

- **`kubectl`**: cliente de línea de comandos para enviar instrucciones al clúster.
- **`kind`**: herramienta que usa contenedores Docker para simular nodos completos de Kubernetes.

### Por qué se hace

Kubernetes expone toda su funcionalidad a través de una API HTTP servida por el `kube-apiserver`. En lugar de construir peticiones HTTP a mano, `kubectl` traduce comandos legibles en llamadas a esa API. Por su parte, `kind` elimina la necesidad de levantar servidores físicos o máquinas virtuales pesadas: cada "nodo" de Kubernetes es, en realidad, un contenedor Docker.

### Comandos de ejecución

```bash
# 1. Descargar el binario oficial de kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# 2. Asignar permisos y mover a una ruta global del sistema
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 3. Descargar el binario de kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64

# 4. Habilitar ejecución y mover al PATH del sistema
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Verificación del paso

```bash
kubectl version --client
kind version
```

Ambos comandos deben reportar su versión de compilación sin errores.

### Qué aprendes aquí

- `kubectl` es un cliente agnóstico: no contiene ningún clúster por sí mismo, solo sabe comunicarse con uno cuando recibe un archivo de configuración.
- `install` es un comando estándar de Linux que copia el archivo, le asigna propietario y le da permisos de ejecución en una única operación atómica.

---

## Fase 2 — Aprovisionamiento del clúster

![Fase](https://img.shields.io/badge/Fase-2%20de%206-blue?style=flat-square)

### Qué se hace

Se crea un clúster local llamado `primer-cluster` utilizando Kind.

### Por qué se hace

Para tener un entorno operativo completo necesitamos todos los componentes del plano de control activos: la base de datos distribuida (`etcd`), el servidor de API (`kube-apiserver`), el programador de tareas (`kube-scheduler`), el administrador de controladores (`kube-controller-manager`) y el complemento de red para contenedores (CNI).

### Comandos de ejecución

```bash
kind create cluster --name primer-cluster
```

### Verificación del paso

```bash
kubectl cluster-info
kubectl get nodes
```

> **Nota operativa:** durante los primeros 10 a 15 segundos tras la creación, es normal que el nodo aparezca en estado `NotReady`. Esto ocurre mientras el CNI (Kindnet) compila las reglas internas de enrutamiento y asigna los rangos de red. Vuelve a ejecutar `kubectl get nodes` cada pocos segundos hasta ver el estado `Ready`.

### Qué aprendes aquí

- `kind` automatizó por dentro un `kubeadm init`, descargó las imágenes base necesarias y generó los certificados TLS de seguridad.
- Tu archivo `~/.kube/config` se actualizó automáticamente con el contexto `kind-primer-cluster`, que le indica a `kubectl` a qué dirección IP y puerto enviar las órdenes.

---

## Fase 3 — Despliegue y autorreparación

![Fase](https://img.shields.io/badge/Fase-3%20de%206-blue?style=flat-square)

### Qué se hace

Se despliega un servidor web Nginx con dos réplicas mediante un objeto `Deployment`. Después se elimina manualmente uno de los Pods generados para observar cómo reacciona el clúster.

### Por qué se hace

En Kubernetes casi nunca se despliegan contenedores sueltos. Se usan objetos de mayor jerarquía como el `Deployment`, que a su vez gestiona un `ReplicaSet`. La única tarea de ese `ReplicaSet` es asegurar que la cantidad de réplicas solicitadas coincida siempre con la realidad observada.

### Comandos de ejecución

```bash
# 1. Crear el Deployment solicitando 2 réplicas de Nginx
kubectl create deployment mi-web --image=nginx:alpine --replicas=2

# 2. Inspeccionar la asignación de IPs y nodos de los Pods
kubectl get pods -o wide
```

Anota el nombre exacto de uno de los Pods listados en la columna `NAME` (por ejemplo, `mi-web-xxxxxxxxxx-yyyyy`) y elimínalo:

```bash
kubectl delete pod <NOMBRE_DE_TU_POD>
```

Inmediatamente después, consulta el estado general:

```bash
kubectl get pods
```

### Qué aprendes aquí

- La columna `AGE` demuestra que el Pod que borraste ya no existe, pero hay uno nuevo con apenas segundos de vida.
- Acabas de presenciar el **bucle de reconciliación** en acción: el controlador detectó que el número deseado de réplicas (2) no coincidía con el actual (1), y ordenó de inmediato la creación de un Pod sustituto, sin intervención humana. Esto es la **autorreparación** (*self-healing*).

---

## Fase 4 — Exposición de servicios

![Fase](https://img.shields.io/badge/Fase-4%20de%206-blue?style=flat-square)

### Qué se hace

Se crea un objeto `Service` de tipo `ClusterIP` para la aplicación web y se abre un túnel con `port-forward` para acceder a ella desde el navegador del sistema anfitrión.

### Por qué se hace

Los Pods son recursos efímeros: nacen, mueren, y al recrearse obtienen una IP distinta. Si un cliente se conectara directamente a la IP de un Pod, la conexión fallaría en cada reinicio. El `Service` resuelve esto actuando como una puerta fija, con una IP estable, que balancea el tráfico entre los Pods sanos. Como `ClusterIP` solo es visible dentro de la red del clúster, `port-forward` sirve como mecanismo de depuración local para abrir un canal hacia el host.

### Comandos de ejecución

```bash
# 1. Exponer el Deployment mi-web bajo un Service interno
kubectl expose deployment mi-web --type=ClusterIP --port=80 --target-port=80

# 2. Obtener la IP virtual fija asignada al Service
kubectl get svc mi-web

# 3. Abrir el túnel TCP desde tu máquina local (puerto 8080) hacia el Service (puerto 80)
kubectl port-forward svc/mi-web 8080:80
```

> **Nota operativa:** `port-forward` bloquea la terminal para mantener el túnel abierto. Deja esa terminal activa y abre una segunda pestaña de WSL para continuar con el resto del runbook.

### Verificación del paso

Desde la segunda terminal, o directamente desde el navegador del sistema operativo:

```bash
curl http://localhost:8080
```

La respuesta debe incluir el HTML oficial con el mensaje `Welcome to nginx!`.

### Qué aprendes aquí

- El `Service` actúa como balanceador interno de capa 4 (TCP), canalizando el tráfico entrante hacia los Pods que coincidan con sus etiquetas (`labels`).
- El parámetro `--port` define dónde escucha el `Service`; `--target-port` define dónde escucha realmente el proceso dentro del contenedor Nginx.

---

## Fase 5 — Escalado horizontal

![Fase](https://img.shields.io/badge/Fase-5%20de%206-blue?style=flat-square)

### Qué se hace

Se aumenta la capacidad de la aplicación de 2 a 5 réplicas, sin detener el servicio en ningún momento.

### Por qué se hace

Las aplicaciones productivas necesitan responder a picos de tráfico ampliando o reduciendo su infraestructura en segundos, sin reiniciar las instancias existentes ni generar indisponibilidad para los clientes ya conectados.

### Comandos de ejecución

En la segunda terminal (con el `port-forward` de la Fase 4 aún activo en la primera):

```bash
kubectl scale deployment mi-web --replicas=5
```

### Verificación del paso

```bash
kubectl get pods
```

Los dos Pods creados en la Fase 3 mostrarán un `AGE` alto (varios minutos), mientras que los tres Pods nuevos tendrán apenas segundos de existencia. Si repites `curl http://localhost:8080`, la conexión sigue respondiendo sin cortes.

### Qué aprendes aquí

- `kubectl scale` no crea servidores nuevos: actualiza el campo `replicas` en la base de datos `etcd`.
- El `Service` detecta automáticamente los tres Pods nuevos y los incorpora al reparto de peticiones, sin requerir ningún ajuste de red adicional.

---

## Fase 6 — Desmantelamiento controlado

![Fase](https://img.shields.io/badge/Fase-6%20de%206-blue?style=flat-square)

### Qué se hace

Se eliminan todos los recursos creados durante el laboratorio, en orden, y se destruye el clúster local de Kind.

### Por qué se hace

En operaciones de infraestructura, el desmontaje sigue el orden inverso al de la creación: primero se cierran las conexiones externas, luego los servicios de red, después las cargas de cómputo, y finalmente el clúster. Destruir el clúster directamente dejaría procesos locales colgados intentando reconectarse a recursos que ya no existen.

### Comandos de ejecución

```bash
# 1. Finalizar el proceso del túnel local
pkill -f "kubectl port-forward" 2>/dev/null || true

# 2. Eliminar el Service de red
kubectl delete service mi-web

# 3. Eliminar el Deployment y sus Pods asociados
kubectl delete deployment mi-web

# 4. Validar que no quedan recursos activos en el namespace
kubectl get all

# 5. Destruir por completo el clúster de kind
kind delete cluster --name primer-cluster
```

### Verificación final del entorno

```bash
kind get clusters
docker ps
```

- `kind get clusters` debe devolver `No kind clusters found`.
- `docker ps` no debe mostrar ningún contenedor en ejecución vinculado a Kubernetes.

### Qué aprendes aquí

- `kubectl delete deployment` envía señales de apagado gradual (`SIGTERM`) a los Pods, dándoles tiempo de cerrar sus conexiones antes de forzar la detención (`SIGKILL`).
- `kind delete cluster` purga los contenedores, las redes virtuales tipo *bridge*, y limpia los certificados del archivo `~/.kube/config`, evitando conflictos si decides reiniciar el laboratorio desde cero.

---

## Solución de problemas comunes

| Síntoma | Causa probable | Acción recomendada |
|---|---|---|
| `permission denied` al ejecutar `docker ps` | El usuario no pertenece al grupo `docker` | Ejecutar `sudo usermod -aG docker $USER` y reiniciar la sesión de WSL |
| Nodo en `NotReady` por más de un minuto | El CNI aún no terminó de configurar la red | Esperar y reintentar `kubectl get nodes`; si persiste, revisar `kubectl describe node` |
| `curl http://localhost:8080` no responde | El `port-forward` se cerró o corre en otra terminal | Verificar que la terminal del túnel siga abierta y sin errores |
| `kind create cluster` falla por nombre duplicado | Ya existe un clúster con ese nombre | Ejecutar `kind get clusters` y eliminar el clúster previo con `kind delete cluster --name <nombre>` |

---

## Glosario rápido

- **kube-apiserver**: puerta de entrada única a todas las operaciones del clúster.
- **etcd**: base de datos distribuida donde se guarda el estado real del clúster.
- **kube-scheduler**: decide en qué nodo se ejecuta cada Pod nuevo.
- **kube-controller-manager**: ejecuta los bucles de reconciliación (como el de autorreparación visto en la Fase 3).
- **CNI (Container Network Interface)**: complemento que provee red a los Pods.
- **ReplicaSet**: garantiza que el número de Pods en ejecución coincida con el número deseado.
- **ClusterIP**: tipo de `Service` accesible únicamente dentro de la red interna del clúster.

---

## Cierre y siguientes pasos

![Completado](https://img.shields.io/badge/Runbook-Completado-success?style=flat-square)

Si llegaste hasta acá con todas las verificaciones en verde, ya operaste un clúster de Kubernetes de punta a punta: lo instalaste, lo poblaste, rompiste una parte a propósito para ver cómo se autorreparaba, la expusiste a la red y la escalaste en caliente. Como siguiente paso natural, se recomienda explorar los objetos `ConfigMap` y `Secret` para gestión de configuración, y el tipo de `Service` `NodePort` o `LoadBalancer` como alternativa a `port-forward` para exposición externa.

