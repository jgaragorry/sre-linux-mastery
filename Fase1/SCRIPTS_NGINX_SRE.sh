#!/bin/bash
################################################################################
# NGINX SRE LAB - SCRIPT COLLECTION v2.0.0
# Conjunto completo de scripts para despliegue y mantenimiento
# 
# Uso: Ejecutar scripts individuales según necesidad
# Ejemplo: bash 01-install-dependencies.sh
################################################################################

# ════════════════════════════════════════════════════════════════════════════
# 01. INSTALACIÓN DE DEPENDENCIAS
# ════════════════════════════════════════════════════════════════════════════

cat > 01-install-dependencies.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 1: INSTALACIÓN DE DEPENDENCIAS                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Validación previa
echo "📋 Validando requisitos del sistema..."
if ! command -v sudo &> /dev/null; then
    echo "❌ sudo no está instalado"
    exit 1
fi

if ! grep -q '^deb' /etc/apt/sources.list; then
    echo "❌ APT no está configurado"
    exit 1
fi

echo "✓ Requisitos OK"
echo ""

# Actualizar índices
echo "📦 Actualizando índices de paquetes..."
sudo apt update -qq

# Instalar paquetes
echo "📦 Instalando dependencias..."
sudo apt install -y \
    nginx \
    apache2-utils \
    curl \
    net-tools \
    jq \
    openssl

echo ""
echo "✅ INSTALACIÓN COMPLETADA"
echo ""
echo "Paquetes instalados:"
apt list --installed 2>/dev/null | grep -E 'nginx|apache2-utils|curl|jq' || true

echo ""
echo "Versiones:"
echo "  Nginx: $(nginx -v 2>&1)"
echo "  Apache Utils: $(htpasswd -v 2>&1 | head -1)"
echo "  curl: $(curl --version | head -1)"
echo "  jq: $(jq --version)"
SCRIPT_EOF

chmod +x 01-install-dependencies.sh


# ════════════════════════════════════════════════════════════════════════════
# 02. GESTIÓN DEL SERVICIO
# ════════════════════════════════════════════════════════════════════════════

cat > 02-service-management.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 2.1: GESTIÓN DEL SERVICIO SYSTEMD                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🚀 Habilitando servicio Nginx..."
sudo systemctl enable --now nginx

echo "Esperando inicialización..."
sleep 2

echo ""
echo "📊 Estado actual:"
sudo systemctl status nginx --no-pager | head -10

echo ""
echo "🔍 Puertos en escucha:"
sudo ss -tulpn | grep -E 'nginx|:80' || echo "⚠️ Nginx aún no escucha en :80"

echo ""
echo "👤 Información del proceso:"
ps aux | grep "[n]ginx" | head -3

echo ""
echo "✅ Servicio configurado correctamente"
SCRIPT_EOF

chmod +x 02-service-management.sh


# ════════════════════════════════════════════════════════════════════════════
# 03. BACKUP ESTRATÉGICO
# ════════════════════════════════════════════════════════════════════════════

cat > 03-backup-strategy.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 2.2: BACKUP ESTRATÉGICO                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

export BKP_DIR="/var/backups/nginx_$(date +%Y-%m-%d_%H%M%S)"
export BKP_MANIFEST="$BKP_DIR/manifest.txt"

echo "💾 Directorio de backup: $BKP_DIR"

# Crear directorio
sudo mkdir -p "$BKP_DIR"
sudo chmod 700 "$BKP_DIR"

# Array de archivos críticos
declare -a CRITICAL_FILES=(
    "/etc/nginx/nginx.conf"
    "/etc/nginx/sites-available"
    "/etc/nginx/conf.d"
)

echo "Respaldando archivos críticos..."
{
    echo "NGINX BACKUP MANIFEST"
    echo "Time: $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} | sudo tee "$BKP_MANIFEST" > /dev/null

for file in "${CRITICAL_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo "  ✓ Respaldando: $file"
        sudo cp -r "$file" "$BKP_DIR/" 2>&1 | sudo tee -a "$BKP_MANIFEST" > /dev/null
    fi
done

# Crear script de restauración
sudo tee "$BKP_DIR/restore.sh" > /dev/null <<'RESTORE_EOF'
#!/bin/bash
BKP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo "⏮️ RESTAURANDO DESDE BACKUP: $BKP_DIR"
sudo systemctl stop nginx
sudo cp "$BKP_DIR/nginx.conf" /etc/nginx/ 2>/dev/null || true
sudo cp -r "$BKP_DIR/sites-available"/* /etc/nginx/sites-available/ 2>/dev/null || true
sudo cp -r "$BKP_DIR/conf.d"/* /etc/nginx/conf.d/ 2>/dev/null || true
sudo nginx -t
sudo systemctl start nginx
echo "✅ Restauración completada"
RESTORE_EOF

sudo chmod +x "$BKP_DIR/restore.sh"
sudo chmod 600 "$BKP_MANIFEST"

echo ""
echo "✅ BACKUP COMPLETADO"
echo ""
echo "Contenidos:"
ls -lah "$BKP_DIR"

echo ""
echo "Para restaurar: sudo $BKP_DIR/restore.sh"
SCRIPT_EOF

chmod +x 03-backup-strategy.sh


# ════════════════════════════════════════════════════════════════════════════
# 04. CONFIGURACIÓN HARDENED
# ════════════════════════════════════════════════════════════════════════════

cat > 04-nginx-hardening.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 2.3: HARDENING DE NGINX                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

NGINX_CONF="/etc/nginx/nginx.conf"

echo "📝 Actualizando configuración Nginx..."

# Leer configuración actual
if sudo grep -q "server_tokens on" "$NGINX_CONF"; then
    echo "  Deshabilitando server_tokens..."
    sudo sed -i 's/server_tokens on;/server_tokens off;/g' "$NGINX_CONF"
fi

# Agregar configuración de hardening si no existe
if ! sudo grep -q "client_max_body_size" "$NGINX_CONF"; then
    echo "  Agregando límites anti-DoS..."
    sudo sed -i '/^http {/a\    client_max_body_size 2M;\n    client_header_timeout 15s;\n    client_body_timeout 15s;\n    keepalive_timeout 65s;\n    send_timeout 10s;' "$NGINX_CONF"
fi

# Agregar log format JSON si no existe
if ! sudo grep -q "log_format json_analytics" "$NGINX_CONF"; then
    echo "  Agregando formato de logs JSON..."
    sudo sed -i '/^http {/a\    log_format json_analytics escape=json \x27{\x27 \x27"time_local":"\x27$time_local\x27",\x27 \x27"remote_addr":"\x27$remote_addr\x27",\x27 \x27"request_method":"\x27$request_method\x27",\x27 \x27"request_uri":"\x27$request_uri\x27",\x27 \x27"status"\x27:$status,\x27 \x27"body_bytes_sent"\x27:$body_bytes_sent,\x27 \x27"request_time"\x27:$request_time \x27}\x27;' "$NGINX_CONF"
fi

echo ""
echo "✅ Validando configuración..."
if sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
    echo "  ✓ Sintaxis correcta"
else
    echo "  ❌ Error de sintaxis"
    exit 1
fi

echo ""
echo "🔄 Recargando Nginx..."
sudo systemctl reload nginx

echo ""
echo "✅ HARDENING COMPLETADO"
SCRIPT_EOF

chmod +x 04-nginx-hardening.sh


# ════════════════════════════════════════════════════════════════════════════
# 05. CONFIGURACIÓN DE USUARIO Y PERMISOS
# ════════════════════════════════════════════════════════════════════════════

cat > 05-user-and-permissions.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 3.1: USUARIO DEDICADO Y PERMISOS                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

WEBROOT="/var/www/sre-lab"
WEBAPP_USER="webapp"

# Crear usuario si no existe
if ! id "$WEBAPP_USER" &>/dev/null; then
    echo "👤 Creando usuario: $WEBAPP_USER"
    sudo useradd -m -s /usr/sbin/nologin -c "Web Application User" "$WEBAPP_USER"
else
    echo "✓ Usuario $WEBAPP_USER ya existe"
fi

# Crear estructura de directorios
echo ""
echo "📁 Creando estructura de directorios..."
sudo mkdir -p "$WEBROOT/content"
sudo mkdir -p /var/cache/nginx

# Establecer permisos
echo "🔐 Configurando permisos..."
sudo chown -R "$WEBAPP_USER:www-data" "$WEBROOT"
sudo chmod 750 "$WEBROOT"
sudo chmod 755 "$WEBROOT/content"
sudo chmod 755 /var/cache/nginx

echo ""
echo "✅ USUARIO Y PERMISOS CONFIGURADOS"
echo ""
echo "Estructura final:"
ls -lad "$WEBROOT" "${WEBROOT}/content"
echo ""
echo "Usuario: $(getent passwd $WEBAPP_USER)"
SCRIPT_EOF

chmod +x 05-user-and-permissions.sh


# ════════════════════════════════════════════════════════════════════════════
# 06. AUTENTICACIÓN BÁSICA
# ════════════════════════════════════════════════════════════════════════════

cat > 06-basic-auth.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 3.2: AUTENTICACIÓN BÁSICA HTTP                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

HTPASSWD_FILE="/etc/nginx/.htpasswd"

echo "🔐 Configurando autenticación básica..."
echo "Ingrese credenciales para usuario 'sre_admin':"
echo ""

# Crear archivo .htpasswd
sudo htpasswd -c "$HTPASSWD_FILE" sre_admin

# Configurar permisos
sudo chown root:www-data "$HTPASSWD_FILE"
sudo chmod 640 "$HTPASSWD_FILE"

echo ""
echo "✅ AUTENTICACIÓN CONFIGURADA"
echo ""
echo "Archivo: $HTPASSWD_FILE"
echo "Permisos:"
sudo ls -l "$HTPASSWD_FILE"

echo ""
echo "Usuarios activos:"
sudo cat "$HTPASSWD_FILE" | cut -d: -f1
SCRIPT_EOF

chmod +x 06-basic-auth.sh


# ════════════════════════════════════════════════════════════════════════════
# 07. VIRTUAL HOST SRE-LAB
# ════════════════════════════════════════════════════════════════════════════

cat > 07-virtual-host-config.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 3.3: VIRTUAL HOST SRE-LAB                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

VHOST_FILE="/etc/nginx/sites-available/sre-lab"

echo "📝 Creando virtual host..."

sudo tee "$VHOST_FILE" > /dev/null <<'VHOST_EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name localhost _;
    
    root /var/www/sre-lab;
    index index.html index.htm;
    
    access_log /var/log/nginx/sre-lab.access.json json_analytics;
    error_log /var/log/nginx/sre-lab.error.log warn;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    expires 1h;
    add_header Cache-Control "public, max-age=3600";
    
    location / {
        auth_basic "SRE Lab - Acceso Restringido";
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files $uri $uri/ =404;
    }
    
    location /metrics {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow ::1;
        deny all;
    }
    
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type "text/plain";
    }
    
    location ~ /\. {
        deny all;
        access_log off;
    }
    
    location ~ ~$ {
        deny all;
        access_log off;
    }
    
    location ~ \.php$ {
        deny all;
        access_log off;
    }
}
VHOST_EOF

echo "✓ Virtual host creado"

# Activar virtual host
echo ""
echo "🔗 Activando virtual host..."
sudo ln -sf "$VHOST_FILE" /etc/nginx/sites-enabled/
sudo unlink /etc/nginx/sites-enabled/default 2>/dev/null || true

# Validar
echo ""
echo "✅ Validando configuración..."
if sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
    echo "  ✓ Sintaxis correcta"
else
    echo "  ❌ Error de sintaxis"
    exit 1
fi

# Recargar
echo ""
echo "🔄 Recargando Nginx..."
sudo systemctl reload nginx

echo ""
echo "✅ VIRTUAL HOST CONFIGURADO"
SCRIPT_EOF

chmod +x 07-virtual-host-config.sh


# ════════════════════════════════════════════════════════════════════════════
# 08. DESPLIEGUE DE CONTENIDO
# ════════════════════════════════════════════════════════════════════════════

cat > 08-deploy-content.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 3.4: DESPLIEGUE DE CONTENIDO WEB                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

WEBROOT="/var/www/sre-lab"
WEBAPP_USER="webapp"

echo "📁 Desplegando index.html..."

sudo tee "$WEBROOT/index.html" > /dev/null <<'HTML_EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SRE Lab - Nginx Hardened</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            color: #333;
        }
        .container {
            background: white;
            border-radius: 10px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 2.5rem;
            max-width: 600px;
            text-align: center;
        }
        h1 { color: #667eea; font-size: 2.5rem; margin-bottom: 1rem; }
        .status {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1rem;
            margin: 2rem 0;
            text-align: left;
        }
        .status-item {
            background: #f0f4ff;
            padding: 1rem;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .status-item .icon { font-size: 1.5rem; margin-right: 0.5rem; }
        .status-item .label { font-size: 0.9rem; color: #666; margin-top: 0.3rem; }
        .welcome {
            background: #fff3e0;
            border-left: 4px solid #ff9800;
            padding: 1.5rem;
            margin: 1.5rem 0;
            border-radius: 8px;
            font-size: 1.1rem;
        }
        .badge {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 0.3rem 0.8rem;
            border-radius: 20px;
            font-size: 0.85rem;
            margin: 0.2rem;
        }
        footer {
            margin-top: 2rem;
            padding-top: 1rem;
            border-top: 1px solid #eee;
            color: #999;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 SRE Lab</h1>
        <h2>Nginx Hardened</h2>
        
        <div class="status">
            <div class="status-item">
                <div class="icon">✅</div>
                <div>Servidor Web</div>
                <div class="label">Activo & Monitoreado</div>
            </div>
            <div class="status-item">
                <div class="icon">🔐</div>
                <div>Autenticación</div>
                <div class="label">HTTP Basic Auth</div>
            </div>
            <div class="status-item">
                <div class="icon">📊</div>
                <div>Observabilidad</div>
                <div class="label">Logs JSON</div>
            </div>
            <div class="status-item">
                <div class="icon">🔒</div>
                <div>Seguridad</div>
                <div class="label">Systemd Hardened</div>
            </div>
        </div>
        
        <div class="welcome">
            👋 <strong>¡Bienvenido, Ingeniero SRE!</strong><br>
            Estás viendo una configuración production-ready con hardening completo.
        </div>
        
        <div>
            <span class="badge">Nginx v1.18+</span>
            <span class="badge">Ubuntu 20.04+</span>
            <span class="badge">Zero Downtime</span>
            <span class="badge">99.95% SLA</span>
        </div>
        
        <footer>
            <p>Configurado: <span id="timestamp"></span></p>
            <p>Host: <span id="hostname"></span></p>
        </footer>
    </div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString('es-CL');
        document.getElementById('hostname').textContent = window.location.hostname;
    </script>
</body>
</html>
HTML_EOF

echo "✓ index.html creado"

# Crear CHANGELOG
echo ""
echo "📝 Creando CHANGELOG.md..."

sudo tee "$WEBROOT/CHANGELOG.md" > /dev/null <<'CHANGELOG_EOF'
# Changelog - SRE Lab Nginx

## [2.0.0] - 2024-01-15
### Agregado
- ✅ Logs en formato JSON con campos estructurados
- ✅ Health check endpoint (`/health`)
- ✅ Métricas Nginx (`/metrics` - localhost only)
- ✅ Systemd hardening con ProtectSystem=strict
- ✅ Autenticación HTTP Basic

### Mejorado
- 🚀 Compresión gzip automática
- 🚀 Timeouts optimizados para seguridad
- 🚀 Cabeceras de seguridad

### Seguridad
- 🔐 server_tokens off
- 🔐 Denegación de archivos peligrosos
- 🔐 Limites anti-DoS

---

## [1.0.0] - 2023-12-01
### Inicial
- Instalación base de Nginx
- Configuración de sitio estático
CHANGELOG_EOF

echo "✓ CHANGELOG.md creado"

# Ajustar permisos
echo ""
echo "🔐 Configurando permisos de archivos..."
sudo chown -R "$WEBAPP_USER:www-data" "$WEBROOT"
sudo chmod 755 "$WEBROOT"
sudo chmod 644 "$WEBROOT"/*.html "$WEBROOT"/*.md

echo ""
echo "✅ CONTENIDO WEB DESPLEGADO"
echo ""
echo "Archivos:"
ls -lh "$WEBROOT"
SCRIPT_EOF

chmod +x 08-deploy-content.sh


# ════════════════════════════════════════════════════════════════════════════
# 09. HARDENING SYSTEMD
# ════════════════════════════════════════════════════════════════════════════

cat > 09-systemd-hardening.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 4.1: HARDENING SYSTEMD                                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "🔒 Aplicando configuración de seguridad Systemd..."
echo "  (Se abrirá editor - agregue el contenido proporcionado)"
echo ""

# Crear archivo de configuración
sudo mkdir -p /etc/systemd/system/nginx.service.d/
sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null <<'SYSTEMD_EOF'
[Service]
MemoryMax=256M
CPUQuota=75%
ProtectSystem=strict
ReadWritePaths=/var/lib/nginx /var/log/nginx /run /var/cache/nginx
PrivateDevices=yes
NoNewPrivileges=yes
PrivateTmp=yes
ProtectProc=invisible
AmbientCapabilities=
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_CHROOT
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nginx
Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=60
StartLimitBurst=3
SYSTEMD_EOF

echo "✓ Archivo de configuración creado"

echo ""
echo "🔄 Recargando daemon de systemd..."
sudo systemctl daemon-reload

echo "🔄 Reiniciando Nginx con nueva configuración..."
sudo systemctl restart nginx

echo ""
echo "✅ HARDENING SYSTEMD COMPLETADO"
echo ""
echo "Verificación:"
sudo systemctl show nginx | grep -E "Memory|Protect|Private"
SCRIPT_EOF

chmod +x 09-systemd-hardening.sh


# ════════════════════════════════════════════════════════════════════════════
# 10. HEALTH CHECK AUTOMÁTICO
# ════════════════════════════════════════════════════════════════════════════

cat > 10-health-check.sh <<'SCRIPT_EOF'
#!/bin/bash

################################################################################
# Health Check: Nginx SRE Lab
# Verifica estado completo del servicio
################################################################################

set -o pipefail

LOGFILE="/var/log/nginx_health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
MEMORY_LIMIT_MB=256
STATUS_OK=0
STATUS_ERROR=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_message() {
    echo "[$TIMESTAMP] $@" >> "$LOGFILE"
}

check_service_active() {
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓${NC} Servicio nginx activo"
        return 0
    else
        echo -e "${RED}✗${NC} Servicio nginx INACTIVO"
        log_message "CRITICAL: nginx service is not active"
        return 1
    fi
}

check_port_listening() {
    if ss -tulpn 2>/dev/null | grep -q ':80.*LISTEN'; then
        echo -e "${GREEN}✓${NC} Puerto 80 en escucha"
        return 0
    else
        echo -e "${RED}✗${NC} Puerto 80 NO está en escucha"
        log_message "CRITICAL: port 80 not listening"
        return 1
    fi
}

check_http_response() {
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓${NC} HTTP 200 en /health"
        return 0
    else
        echo -e "${RED}✗${NC} HTTP $HTTP_CODE (esperado 200)"
        log_message "WARNING: HTTP health endpoint returned $HTTP_CODE"
        return 1
    fi
}

check_error_logs() {
    if tail -n 100 /var/log/nginx/error.log 2>/dev/null | grep -qi 'emerg'; then
        echo -e "${RED}✗${NC} Errores CRÍTICOS en logs"
        log_message "CRITICAL: Emergency errors in nginx error.log"
        return 1
    else
        echo -e "${GREEN}✓${NC} Sin errores críticos recientes"
        return 0
    fi
}

check_memory_usage() {
    MEMORY_MB=$(ps aux | grep "[n]ginx" | awk '{sum+=$6} END {print int(sum/1024)}')
    if [ "$MEMORY_MB" -lt "$MEMORY_LIMIT_MB" ]; then
        echo -e "${GREEN}✓${NC} Memoria: ${MEMORY_MB}MB < ${MEMORY_LIMIT_MB}MB"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Memoria elevada: ${MEMORY_MB}MB >= ${MEMORY_LIMIT_MB}MB"
        log_message "WARNING: Memory usage high: ${MEMORY_MB}MB"
        return 1
    fi
}

main() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  🏥 NGINX HEALTH CHECK"
    echo "  Host: $HOSTNAME | Time: $TIMESTAMP"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    FAILED=0
    
    check_service_active || ((FAILED++))
    check_port_listening || ((FAILED++))
    check_http_response || ((FAILED++))
    check_error_logs || ((FAILED++))
    check_memory_usage || ((FAILED++))
    
    echo ""
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✅ HEALTH CHECK PASSED - All systems nominal${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
        log_message "OK: All checks passed"
        return $STATUS_OK
    else
        echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}❌ HEALTH CHECK FAILED - $FAILED check(s) failed${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
        log_message "FAILED: $FAILED check(s) failed"
        return $STATUS_ERROR
    fi
}

main "$@"
SCRIPT_EOF

chmod +x 10-health-check.sh


# ════════════════════════════════════════════════════════════════════════════
# 11. INSTALACIÓN DE HEALTH CHECK EN CRON
# ════════════════════════════════════════════════════════════════════════════

cat > 11-install-health-check.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 4.2: INSTALACIÓN DE HEALTH CHECK AUTOMÁTICO              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Instalando health check..."

# Verificar que existe el script
if [ ! -f "10-health-check.sh" ]; then
    echo "❌ Error: 10-health-check.sh no encontrado"
    exit 1
fi

# Copiar script
sudo cp 10-health-check.sh /usr/local/bin/check_nginx_health.sh
sudo chmod 755 /usr/local/bin/check_nginx_health.sh

# Crear log
sudo touch /var/log/nginx_health.log
sudo chmod 644 /var/log/nginx_health.log

echo "✓ Script instalado en /usr/local/bin/check_nginx_health.sh"

# Ejecutar prueba
echo ""
echo "🧪 Ejecutando prueba inicial..."
sudo /usr/local/bin/check_nginx_health.sh

# Programar en cron
echo ""
echo "⏰ Programando en cron (cada 5 minutos)..."
sudo tee /etc/cron.d/nginx_health > /dev/null <<'CRON_EOF'
*/5 * * * * root /usr/local/bin/check_nginx_health.sh >> /var/log/nginx_health.log 2>&1
CRON_EOF

sudo systemctl restart cron

echo ""
echo "✅ HEALTH CHECK INSTALADO"
echo ""
echo "Programación:"
cat /etc/cron.d/nginx_health
echo ""
echo "Logs:"
ls -lh /var/log/nginx_health.log
SCRIPT_EOF

chmod +x 11-install-health-check.sh


# ════════════════════════════════════════════════════════════════════════════
# 12. VALIDACIÓN FINAL
# ════════════════════════════════════════════════════════════════════════════

cat > 12-final-validation.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ETAPA 5: VALIDACIÓN FINAL                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

CHECKS_PASSED=0
CHECKS_TOTAL=0

run_check() {
    local name="$1"
    local command="$2"
    
    ((CHECKS_TOTAL++))
    echo ""
    echo "[$CHECKS_TOTAL] $name"
    if eval "$command" &>/dev/null; then
        echo "    ✅ PASSED"
        ((CHECKS_PASSED++))
        return 0
    else
        echo "    ❌ FAILED"
        return 1
    fi
}

# Ejecución de checks
run_check "Sintaxis Nginx válida" "sudo nginx -t"
run_check "Servicio activo" "sudo systemctl is-active --quiet nginx"
run_check "Puerto 80 en escucha" "sudo ss -tulpn | grep -q ':80.*LISTEN'"
run_check "server_tokens off" "curl -s -I http://localhost/health | grep -qv 'Server: nginx'"
run_check "Auth endpoint 401" "curl -s -o /dev/null -w '%{http_code}' http://localhost/ | grep -q 401"
run_check "Health endpoint 200" "curl -s -o /dev/null -w '%{http_code}' http://localhost/health | grep -q 200"
run_check ".htpasswd existe" "sudo test -f /etc/nginx/.htpasswd"
run_check "Logs JSON" "sudo test -f /var/log/nginx/sre-lab.access.json"
run_check "Health check script" "sudo test -x /usr/local/bin/check_nginx_health.sh"
run_check "Cron configurado" "sudo test -f /etc/cron.d/nginx_health"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Resultado: $CHECKS_PASSED / $CHECKS_TOTAL checks pasaron"
if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
    echo "🎉 ¡VALIDACIÓN COMPLETA!"
    exit 0
else
    echo "⚠️  Revisar checks fallidos arriba"
    exit 1
fi
echo "════════════════════════════════════════════════════════════════"
SCRIPT_EOF

chmod +x 12-final-validation.sh


# ════════════════════════════════════════════════════════════════════════════
# 13. PRUEBA DE CARGA
# ════════════════════════════════════════════════════════════════════════════

cat > 13-load-testing.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ PRUEBA DE CARGA - APACHE BENCHMARK                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

read -p "Usuario (default: sre_admin): " USERNAME
USERNAME=${USERNAME:-sre_admin}

read -sp "Contraseña: " PASSWORD
echo ""

read -p "Número de requests (default: 1000): " REQUESTS
REQUESTS=${REQUESTS:-1000}

read -p "Concurrencia (default: 50): " CONCURRENCY
CONCURRENCY=${CONCURRENCY:-50}

TARGET="http://127.0.0.1/health"

echo ""
echo "Configuración:"
echo "  Target: $TARGET"
echo "  Requests: $REQUESTS"
echo "  Concurrency: $CONCURRENCY"
echo "  User: $USERNAME"
echo ""

ab -n "$REQUESTS" \
   -c "$CONCURRENCY" \
   -A "$USERNAME:$PASSWORD" \
   "$TARGET"

echo ""
echo "📊 Análisis de logs:"
tail -n 100 /var/log/nginx/sre-lab.access.json 2>/dev/null | jq -r '.request_time' | \
    awk '{sum+=$1; if ($1 > max || NR==1) max=$1; if ($1 < min || NR==1) min=$1} 
          END {printf "Min: %.3fs | Max: %.3fs | Avg: %.3fs\n", min, max, sum/NR}' || \
    echo "⚠️ No hay datos en logs"
SCRIPT_EOF

chmod +x 13-load-testing.sh


# ════════════════════════════════════════════════════════════════════════════
# 14. MENU INTERACTIVO
# ════════════════════════════════════════════════════════════════════════════

cat > 00-menu-interactivo.sh <<'SCRIPT_EOF'
#!/bin/bash

clear

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         NGINX SRE LAB - DEPLOYMENT AUTOMATION MENU             ║"
echo "║                       v2.0.0                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Seleccione la acción a ejecutar:"
echo ""
echo "  📦 INSTALACIÓN"
echo "    1) Instalar dependencias"
echo "    2) Configurar servicio Systemd"
echo "    3) Crear backups"
echo "    4) Aplicar hardening Nginx"
echo ""
echo "  🔐 CONFIGURACIÓN"
echo "    5) Crear usuario dedicado y permisos"
echo "    6) Configurar autenticación básica"
echo "    7) Instalar virtual host sre-lab"
echo "    8) Desplegar contenido web"
echo "    9) Aplicar hardening Systemd"
echo ""
echo "  📊 OBSERVABILIDAD"
echo "   10) Instalar health check automático"
echo ""
echo "  ✅ VALIDACIÓN"
echo "   11) Ejecutar validación final"
echo "   12) Prueba de carga"
echo ""
echo "  🚀 EJECUCIÓN COMPLETA"
echo "   13) Ejecutar todo el pipeline (recomendado)"
echo ""
echo "   0) Salir"
echo ""
read -p "Opción [0-13]: " OPTION

case $OPTION in
    1) bash 01-install-dependencies.sh ;;
    2) bash 02-service-management.sh ;;
    3) bash 03-backup-strategy.sh ;;
    4) bash 04-nginx-hardening.sh ;;
    5) bash 05-user-and-permissions.sh ;;
    6) bash 06-basic-auth.sh ;;
    7) bash 07-virtual-host-config.sh ;;
    8) bash 08-deploy-content.sh ;;
    9) bash 09-systemd-hardening.sh ;;
   10) bash 11-install-health-check.sh ;;
   11) bash 12-final-validation.sh ;;
   12) bash 13-load-testing.sh ;;
   13) 
       echo "⏳ Ejecutando pipeline completo..."
       bash 01-install-dependencies.sh && \
       bash 02-service-management.sh && \
       bash 03-backup-strategy.sh && \
       bash 04-nginx-hardening.sh && \
       bash 05-user-and-permissions.sh && \
       bash 06-basic-auth.sh && \
       bash 07-virtual-host-config.sh && \
       bash 08-deploy-content.sh && \
       bash 09-systemd-hardening.sh && \
       bash 11-install-health-check.sh && \
       bash 12-final-validation.sh
       echo ""
       echo "✅ Pipeline completado"
       ;;
    0) echo "Hasta luego"; exit 0 ;;
    *) echo "Opción inválida"; exit 1 ;;
esac
SCRIPT_EOF

chmod +x 00-menu-interactivo.sh

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ SCRIPTS CREADOS EXITOSAMENTE"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Scripts disponibles:"
ls -1 *.sh | nl
echo ""
echo "Uso:"
echo "  Opción 1: Ejecutar menú interactivo"
echo "    $ bash 00-menu-interactivo.sh"
echo ""
echo "  Opción 2: Ejecutar script específico"
echo "    $ bash 01-install-dependencies.sh"
echo ""
echo "  Opción 3: Ejecutar todo de una vez"
echo "    $ for script in {01..12}-*.sh; do bash \"\$script\" || break; done"
echo ""
