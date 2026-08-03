---

## Fase 1 — Preparación del entorno de control

### 1.1 Directorio de trabajo y llaves SSH dedicadas

Nunca usen sus llaves SSH personales para un laboratorio efímero. Generamos un par exclusivo para aislar credenciales:

```bash
mkdir -p ~/desafio-ansible && cd ~/desafio-ansible

test -f ~/.ssh/id_desafio_ansible || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_desafio_ansible
```

> Uso Ed25519 en lugar de RSA porque ofrece mejor rendimiento y un nivel criptográfico superior con claves más cortas.

### 1.2 Dockerfile con la clave inyectada

```bash
KEY_CONTENT=$(cat ~/.ssh/id_desafio_ansible.pub)

cat << EOF > Dockerfile
FROM ubuntu:24.04

RUN apt update && apt install -y openssh-server python3 sudo curl && \
    mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "$KEY_CONTENT" > /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

EXPOSE 22 80
CMD ["/usr/sbin/sshd", "-D"]
EOF
```

> **Atención:** OpenSSH exige permisos `700` en `.ssh` y `600` en `authorized_keys`. Si se equivocan aquí, la conexión será rechazada sin excepción.

### 1.3 Construcción de la imagen y despliegue de nodos

```bash
docker build -t desafio-node:24.04 .

docker rm -f app-node01 app-node02 2>/dev/null

docker run -d --name app-node01 -p 2223:22 -p 8083:80 desafio-node:24.04
docker run -d --name app-node02 -p 2224:22 -p 8084:80 desafio-node:24.04
```

| Contenedor | Puerto SSH (host) | Puerto HTTP (host) |
|---|---|---|
| app-node01 | 2223 | 8083 |
| app-node02 | 2224 | 8084 |

### 1.4 Verificación de acceso desatendido

```bash
ssh-keygen -f ~/.ssh/known_hosts -R '[127.0.0.1]:2223' -R '[127.0.0.1]:2224' 2>/dev/null

ssh -i ~/.ssh/id_desafio_ansible -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2223 root@127.0.0.1 "hostname -I"
ssh -i ~/.ssh/id_desafio_ansible -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2224 root@127.0.0.1 "hostname -I"
```

Si ambos comandos les devuelven una IP interna sin pedir contraseña, la capa de autenticación está lista y pueden avanzar.

---

## Fase 2 — Inventario y configuración global

### 2.1 Inventario (`inventory.ini`)

```bash
cat << 'EOF' > inventory.ini
[webservers]
app-node01 ansible_host=127.0.0.1 ansible_port=2223
app-node02 ansible_host=127.0.0.1 ansible_port=2224

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
```

### 2.2 Configuración (`ansible.cfg`)

```bash
cat << 'EOF' > ansible.cfg
[defaults]
inventory = ./inventory.ini
host_key_checking = False
remote_user = root
private_key_file = ~/.ssh/id_desafio_ansible
interpreter_python = auto_silent
EOF
```

`host_key_checking = False` nos evita la validación interactiva de llaves, algo ideal en laboratorios con contenedores que se recrean constantemente.

### 2.3 Prueba de conectividad

```bash
ansible all -m ansible.builtin.ping
```

Una respuesta `"ping": "pong"` en verde confirma que Ansible ya ejecuta código Python remoto por SSH sin fricción.

---

## Fase 3 — Variables y plantillas Jinja2

```bash
mkdir -p templates group_vars/webservers
```

### 3.1 Variables de grupo (`group_vars/webservers/vars.yml`)

```bash
cat << 'EOF' > group_vars/webservers/vars.yml
---
environment_name: "Staging"
app_owner: "SRE Student Team"
enable_health_check: true
EOF
```

### 3.2 Plantilla principal (`templates/index.j2`)

```bash
cat << 'EOF' > templates/index.j2
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>App - {{ environment_name }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #0f172a; color: #f8fafc; }
        .box { background: #1e293b; padding: 25px; border-radius: 10px; border: 1px solid #334155; }
        h1 { color: #38bdf8; }
    </style>
</head>
<body>
    <div class="box">
        <h1>Aplicacion Web [Ambiente: {{ environment_name }}]</h1>
        <p><strong>Servidor Objetivo:</strong> {{ ansible_facts['hostname'] }}</p>
        <p><strong>IP Registrada:</strong> {{ ansible_facts['default_ipv4']['address'] | default('127.0.0.1') }}</p>
        <p><strong>Equipo Responsable:</strong> {{ app_owner }}</p>
    </div>
</body>
</html>
EOF
```

### 3.3 Plantilla de salud (`templates/health.j2`)

```bash
cat << 'EOF' > templates/health.j2
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Health Check</title>
    <style>
        body { font-family: monospace; padding: 20px; background: #111827; color: #10b981; }
        .status { font-size: 20px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="status">STATUS: UP / HEALTHY</div>
    <hr>
    <p>Host: {{ ansible_facts['hostname'] }}</p>
    <p>Memoria Libre: {{ ansible_facts['memfree_mb'] }} MB</p>
    <p>Timestamp Evaluacion: {{ ansible_facts['date_time']['iso8601'] }}</p>
</body>
</html>
EOF
```

---

## Fase 4 — Playbook y ejecución

### 4.1 Playbook principal (`deploy.yml`)

```bash
cat << 'EOF' > deploy.yml
---
- name: Desafio de Aprovisionamiento Web y Monitoreo SRE
  hosts: webservers
  gather_facts: true

  tasks:
    - name: Actualizar la cache de APT
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Instalar el servidor Nginx
      ansible.builtin.apt:
        name: nginx
        state: present

    - name: Desplegar pagina principal index.html
      ansible.builtin.template:
        src: templates/index.j2
        dest: /var/www/html/index.html
        owner: www-data
        group: www-data
        mode: '0644'

    - name: Desplegar endpoint de salud /health.html
      ansible.builtin.template:
        src: templates/health.j2
        dest: /var/www/html/health.html
        owner: www-data
        group: www-data
        mode: '0644'
      when: enable_health_check | default(false)

    - name: Asegurar servicio Nginx activo
      ansible.builtin.service:
        name: nginx
        state: started
EOF
```

### 4.2 Validación y primera ejecución

```bash
ansible-playbook deploy.yml --syntax-check
ansible-playbook deploy.yml
```

En esta primera corrida van a ver tareas marcadas en amarillo como `changed`. Es exactamente lo esperado: Ansible está creando algo que antes no existía.

### 4.3 Prueba de idempotencia

```bash
ansible-playbook deploy.yml --check
```

```mermaid
graph LR
    A[Primera ejecucion] -->|changed > 0| B[Estado aplicado]
    B --> C[Segunda ejecucion --check]
    C -->|changed = 0| D[Idempotencia confirmada]
    style D fill:#10b981,color:#fff
```

Si el `PLAY RECAP` final muestra `changed=0` en verde, el estado real del servidor coincide exactamente con lo que declaramos en código. Esa es la prueba definitiva de un playbook bien escrito.

---

## Validación de servicios

```bash
curl -s http://127.0.0.1:8083 | grep "Aplicacion Web"
curl -s http://127.0.0.1:8084 | grep "Aplicacion Web"

curl -s http://127.0.0.1:8083/health.html | grep "STATUS:"
curl -s http://127.0.0.1:8084/health.html | grep "STATUS:"
```

Desde el navegador de Windows, usen la IP que VirtualBox asignó a la máquina (por ejemplo `192.168.1.148`):

| Recurso | URL |
|---|---|
| Página principal — Nodo 1 | `http://192.168.1.148:8083` |
| Health check — Nodo 1 | `http://192.168.1.148:8083/health.html` |
| Página principal — Nodo 2 | `http://192.168.1.148:8084` |
| Health check — Nodo 2 | `http://192.168.1.148:8084/health.html` |

---

## Limpieza del entorno

Al terminar el laboratorio, destruimos todo lo que creamos para no dejar residuos en el sistema.

```bash
cat << 'EOF' > cleanup.sh
#!/bin/bash
echo "Iniciando limpieza del entorno..."

docker rm -f app-node01 app-node02 2>/dev/null
docker rmi desafio-node:24.04 2>/dev/null

ssh-keygen -f ~/.ssh/known_hosts -R '[127.0.0.1]:2223' 2>/dev/null
ssh-keygen -f ~/.ssh/known_hosts -R '[127.0.0.1]:2224' 2>/dev/null

echo "Entorno destruido y limpio correctamente."
EOF

chmod +x cleanup.sh
./cleanup.sh
```

---

## Cierre

Con esto completamos el ciclo completo: preparación, inventario, plantillas, aprovisionamiento, verificación de idempotencia y limpieza. Este mismo esqueleto lo pueden reutilizar en cualquier proyecto real, cambiando el rol de Nginx por el servicio que necesiten desplegar.

![Estado](https://img.shields.io/badge/Laboratorio-Completo-success?style=flat-square)
![Idempotencia](https://img.shields.io/badge/changed-0-brightgreen?style=flat-square)
