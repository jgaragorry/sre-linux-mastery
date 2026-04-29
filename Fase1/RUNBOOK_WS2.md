<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Runbook: Despliegue Seguro de Nginx + Hardening | SRE-LAB</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            background: linear-gradient(135deg, #0b2b2b 0%, #0a1a1a 100%);
            font-family: 'Segoe UI', 'Fira Code', 'Cascadia Code', monospace;
            padding: 2rem;
            color: #e0e0e0;
        }
        .container {
            max-width: 1300px;
            margin: 0 auto;
            background: rgba(18, 25, 30, 0.85);
            backdrop-filter: blur(2px);
            border-radius: 2rem;
            padding: 2rem;
            box-shadow: 0 25px 45px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.05);
            border: 1px solid rgba(0,255,255,0.2);
        }
        h1 {
            font-size: 2.5rem;
            background: linear-gradient(135deg, #a5f0ff, #3bc9db);
            -webkit-background-clip: text;
            background-clip: text;
            color: transparent;
            border-left: 5px solid #0ff;
            padding-left: 1.5rem;
            margin-bottom: 1.5rem;
        }
        h2 {
            color: #7ee0ff;
            margin-top: 2rem;
            margin-bottom: 1rem;
            border-bottom: 2px solid #2c5a5a;
            padding-bottom: 0.5rem;
        }
        h3 {
            color: #b2f0c0;
            margin: 1.2rem 0 0.6rem 0;
        }
        .badge {
            background: #0a2f2f;
            border-radius: 20px;
            padding: 0.2rem 0.8rem;
            font-size: 0.8rem;
            font-weight: bold;
            color: #0ff;
            display: inline-block;
            margin-right: 1rem;
        }
        pre, code {
            background: #0b1219;
            font-family: 'Fira Code', 'Cascadia Code', monospace;
            border-radius: 12px;
            font-size: 0.9rem;
        }
        code {
            padding: 0.2rem 0.4rem;
            background: #0f1a1f;
            color: #f0b27a;
        }
        pre {
            padding: 1rem;
            overflow-x: auto;
            border-left: 4px solid #0ff;
            margin: 1rem 0;
            box-shadow: 0 4px 10px rgba(0,0,0,0.3);
        }
        .step-card {
            background: #0e1a1c;
            border-radius: 1.2rem;
            padding: 1.2rem;
            margin: 1rem 0;
            transition: all 0.2s;
            border: 1px solid #2a4b4b;
        }
        .step-card:hover {
            border-color: #0ff;
            box-shadow: 0 5px 12px rgba(0,255,255,0.1);
        }
        .verification {
            background: #052222;
            border-left: 4px solid #0fa;
            padding: 0.6rem 1rem;
            border-radius: 12px;
            margin: 0.8rem 0;
            font-size: 0.9rem;
        }
        .danger {
            border-left-color: #f77;
            background: #2a1515;
        }
        .note {
            background: #1e2a2a;
            border-radius: 12px;
            padding: 0.6rem 1rem;
            font-style: italic;
            color: #ccc;
        }
        hr {
            border: none;
            height: 1px;
            background: linear-gradient(90deg, #0ff, transparent);
            margin: 2rem 0;
        }
        footer {
            text-align: center;
            margin-top: 3rem;
            font-size: 0.8rem;
            opacity: 0.7;
        }
        @media (max-width: 680px) {
            body { padding: 0.8rem; }
            pre { font-size: 0.7rem; }
        }
    </style>
</head>
<body>
<div class="container">
    <h1>🚀 SRE‑LAB Runbook<br>Despliegue Nginx + Hardening + Aislamiento</h1>
    <p><strong>Objetivo:</strong> Configurar un servidor web Nginx con autenticación básica, seguridad reforzada, limitaciones de recursos (systemd), monitorización automática y pruebas de carga. <br>
    <strong>Sistema:</strong> Ubuntu 24.04 LTS (para operadores sin experiencia en Linux).</p>
    <div class="note">📌 Cada comando incluye su <strong>explicación</strong> y <strong>verificación</strong>. Lee todo antes de ejecutar.</div>

    <!-- Fase 1 -->
    <h2>🔧 Fase 1 – Preparación del sistema</h2>
    <div class="step-card">
        <h3>1.1 Actualizar repositorios</h3>
        <pre><code>sudo apt update</code></pre>
        <p><strong>¿Por qué?</strong> Sincroniza la lista de paquetes disponibles. Sin esto, podrías instalar versiones antiguas.</p>
        <div class="verification">✅ Verifica que la última línea sea <code>Leyendo lista de paquetes... Listo</code></div>
    </div>
    <div class="step-card">
        <h3>1.2 Instalar utilidades básicas</h3>
        <pre><code>sudo apt install -y curl wget ufw apache2-utils</code></pre>
        <p><code>apache2-utils</code> incluye <code>htpasswd</code> para autenticación. <code>ufw</code> es el firewall.</p>
        <div class="verification">✅ <code>htpasswd -v</code> debe mostrar opciones (no error).</div>
    </div>

    <!-- Fase 2 Instalación base -->
    <h2>📦 Fase 2 – Instalación de Nginx</h2>
    <div class="step-card">
        <h3>2.1 Instalar Nginx</h3>
        <pre><code>sudo apt install -y nginx</code></pre>
        <div class="verification">✅ <code>sudo systemctl status nginx --no-pager</code> → <strong>active (running)</strong></div>
    </div>

    <!-- Fase 3 Backup estratégico (CORREGIDO) -->
    <h2>💾 Fase 3 – Backup estratégico (corregido)</h2>
    <div class="step-card">
        <h3>3.1 Crear carpeta de snapshots</h3>
        <pre><code>sudo mkdir -p /etc/nginx/snapshots</code></pre>
    </div>
    <div class="step-card">
        <h3>3.2 Copia de seguridad completa (recursiva)</h3>
        <pre><code>sudo cp -a /etc/nginx /etc/nginx/snapshots/nginx.original.$(date +%Y%m%d_%H%M%S)</code></pre>
        <p><strong>❌ Error común:</strong> olvidar que <code>/etc/nginx</code> es un directorio. <code>cp -a</code> copia recursivamente preservando atributos (equivale a <code>-dR --preserve=all</code>). Si prefieres, puedes usar <code>cp -r</code> pero <code>-a</code> es más completo.</p>
        <div class="verification">✅ <code>ls /etc/nginx/snapshots/</code> muestra un directorio con fecha.</div>
    </div>

    <!-- Fase 4 Hardening + JSON log -->
    <h2>🔐 Fase 4 – Hardening y logs en JSON (corregido)</h2>
    <div class="step-card">
        <h3>4.1 Ocultar versión de Nginx</h3>
        <pre><code>sudo nano /etc/nginx/nginx.conf</code></pre>
        <p>Dentro del bloque <code>http { ... }</code> añadir: <code>server_tokens off;</code></p>
        <div class="verification">✅ <code>sudo nginx -t</code> → syntax ok.</div>
    </div>
    <div class="step-card">
        <h3>4.2 Definir formato JSON (¡al inicio del bloque http!)</h3>
        <p><strong>⚠️ Importante:</strong> la definición de <code>log_format</code> debe ir <strong>justo después de abrir <code>http {</code></strong>, no al final del archivo. Si la pones al final, Nginx no la reconoce y falla.</p>
        <pre><code>sudo nano /etc/nginx/nginx.conf</code></pre>
        <p>Editar para que quede así:</p>
        <pre><code>http {
    log_format json escape=json '{ "time": "$time_iso8601", '
        '"remote_addr": "$remote_addr", '
        '"request": "$request", '
        '"status": $status, '
        '"body_bytes_sent": $body_bytes_sent, '
        '"request_time": $request_time, '
        '"http_referrer": "$http_referer", '
        '"http_user_agent": "$http_user_agent" }';
    # resto de directivas ...</code></pre>
        <div class="verification">✅ <code>sudo nginx -t</code> debe pasar sin errores.</div>
    </div>
    <div class="step-card">
        <h3>4.3 Firewall UFW</h3>
        <pre><code>sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw --force enable
sudo ufw status verbose</code></pre>
    </div>

    <!-- Fase 5 Virtual Host -->
    <h2>🌐 Fase 5 – Virtual Host sre‑lab</h2>
    <div class="step-card">
        <h3>5.1 Directorio del sitio</h3>
        <pre><code>sudo mkdir -p /var/www/sre-lab/html
sudo chown $USER:$USER /var/www/sre-lab/html
echo '&lt;h1&gt;Bienvenido a SRE-LAB&lt;/h1&gt;' | sudo tee /var/www/sre-lab/html/index.html</code></pre>
    </div>
    <div class="step-card">
        <h3>5.2 Configuración del virtual host (con log JSON)</h3>
        <pre><code>sudo nano /etc/nginx/sites-available/sre-lab</code></pre>
        <p>Contenido:</p>
        <pre><code>server {
    listen 80;
    server_name _;
    root /var/www/sre-lab/html;
    index index.html;
    autoindex off;
    server_tokens off;
    access_log /var/log/nginx/sre-lab-access.log json;
    error_log /var/log/nginx/sre-lab-error.log;
    location / {
        try_files $uri $uri/ =404;
    }
}</code></pre>
    </div>
    <div class="step-card">
        <h3>5.3 Activar sitio</h3>
        <pre><code>sudo ln -s /etc/nginx/sites-available/sre-lab /etc/nginx/sites-enabled/
sudo unlink /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx</code></pre>
    </div>

    <!-- Fase 6 Autenticación -->
    <h2>👤 Fase 6 – Autenticación básica y usuario webapp</h2>
    <div class="step-card">
        <h3>6.1 Crear archivo .htpasswd</h3>
        <pre><code>sudo htpasswd -c /etc/nginx/.htpasswd admin</code></pre>
        <p>Introduce una contraseña (por ejemplo <code>123</code>).</p>
    </div>
    <div class="step-card">
        <h3>6.2 Agregar protección al sitio</h3>
        <pre><code>sudo nano /etc/nginx/sites-available/sre-lab</code></pre>
        <p>Dentro del bloque <code>location / {</code> añadir:</p>
        <pre><code>auth_basic "Área Restringida";
auth_basic_user_file /etc/nginx/.htpasswd;</code></pre>
        <p>Recargar: <code>sudo nginx -t && sudo systemctl reload nginx</code></p>
        <div class="verification">✅ <code>curl -u admin:contraseña http://localhost/</code> muestra el HTML.</div>
    </div>
    <div class="step-card">
        <h3>6.3 Usuario dedicado webapp</h3>
        <pre><code>sudo useradd -r -s /usr/sbin/nologin webapp
sudo usermod -a -G www-data webapp
sudo chown -R webapp:www-data /var/www/sre-lab</code></pre>
    </div>

    <!-- Fase 7 Aislamiento systemd (corregido) -->
    <h2>🔒 Fase 7 – Aislamiento con systemd (sin errores)</h2>
    <div class="step-card">
        <h3>7.1 Crear directorio drop-in</h3>
        <pre><code>sudo mkdir -p /etc/systemd/system/nginx.service.d</code></pre>
    </div>
    <div class="step-card">
        <h3>7.2 Archivo de restricciones (rutas completas + directorios previos)</h3>
        <p><strong>⚠️ Antes de escribir el override, crea los directorios que Nginx necesita escribir:</strong></p>
        <pre><code>sudo mkdir -p /var/cache/nginx /var/lib/nginx
sudo chown www-data:www-data /var/cache/nginx /var/lib/nginx</code></pre>
        <p>Ahora crea el archivo:</p>
        <pre><code>sudo nano /etc/systemd/system/nginx.service.d/override.conf</code></pre>
        <p>Contenido <strong>probado y funcional</strong> (sin <code>ProtectSystem=strict</code> para evitar bloqueos, y con todas las rutas necesarias):</p>
        <pre><code>[Service]
MemoryMax=256M
MemoryHigh=200M
CPUQuota=50%
PrivateTmp=yes
NoNewPrivileges=yes
ReadWritePaths=/var/log/nginx /var/www /etc/nginx/.htpasswd /run /var/cache/nginx /var/lib/nginx</code></pre>
        <p><strong>Explicación:</strong> <code>ReadWritePaths</code> permite escritura solo en esas carpetas. <code>PrivateTmp</code> aísla /tmp. Sin <code>ProtectSystem</code> total para evitar problemas con permisos de pid y caché.</p>
    </div>
    <div class="step-card">
        <h3>7.3 Recargar y reiniciar</h3>
        <pre><code>sudo systemctl daemon-reload
sudo systemctl restart nginx
sudo systemctl status nginx --no-pager</code></pre>
        <div class="verification">✅ Debe mostrar <code>active (running)</code> y las líneas <code>Memory: ... max: 256.0M</code>.</div>
    </div>

    <!-- Fase 8 Health Checks -->
    <h2>🩺 Fase 8 – Health checks automáticos (cron + script)</h2>
    <div class="step-card">
        <h3>8.1 Script de verificación (usa autenticación)</h3>
        <pre><code>sudo nano /usr/local/bin/health-check.sh</code></pre>
        <pre><code>#!/bin/bash
CHECK_URL="http://localhost/"
HTTP_CODE=$(curl -u admin:123 -o /dev/null -s -w "%{http_code}" $CHECK_URL)
if [ "$HTTP_CODE" = "200" ]; then
    echo "OK - Nginx responde correctamente"
    exit 0
else
    echo "CRITICAL - Nginx devuelve $HTTP_CODE"
    exit 2
fi</code></pre>
        <p><code>sudo chmod +x /usr/local/bin/health-check.sh</code></p>
        <div class="verification">✅ <code>sudo /usr/local/bin/health-check.sh</code> imprime <code>OK</code>.</div>
    </div>
    <div class="step-card">
        <h3>8.2 Programar en cron cada 5 minutos</h3>
        <pre><code>sudo crontab -e</code></pre>
        <p>Añadir línea:</p>
        <pre><code>*/5 * * * * /usr/local/bin/health-check.sh >> /var/log/health-check.log 2>&1</code></pre>
        <div class="verification">✅ <code>sudo crontab -l</code> muestra la tarea. Esperar unos minutos y <code>cat /var/log/health-check.log</code> debe contener <code>OK</code>.</div>
    </div>
    <div class="step-card">
        <h3>8.3 Script de métricas (opcional)</h3>
        <pre><code>sudo nano /usr/local/bin/metrics.sh</code></pre>
        <pre><code>#!/bin/bash
NOW=$(date -Iseconds)
REQUESTS=$(sudo cat /var/log/nginx/sre-lab-access.log | wc -l)
ERRORS=$(sudo grep -c '"status": 5' /var/log/nginx/sre-lab-access.log || echo 0)
echo "$NOW requests=$REQUESTS errors=$ERRORS" >> /var/log/metrics.log</code></pre>
        <p><code>sudo chmod 750 /usr/local/bin/metrics.sh</code> y añadir al cron: <code>*/10 * * * * /usr/local/bin/metrics.sh</code></p>
    </div>

    <!-- Fase 9 Validación final con ab corregido -->
    <h2>✅ Fase 9 – Validación final y pruebas de carga</h2>
    <div class="step-card">
        <h3>9.1 Probar acceso con autenticación</h3>
        <pre><code>curl -u admin:123 http://localhost/</code></pre>
        <div class="verification">✅ Devuelve <code>&lt;h1&gt;Bienvenido a SRE-LAB&lt;/h1&gt;</code></div>
    </div>
    <div class="step-card">
        <h3>9.2 Verificar que sin contraseña da 401</h3>
        <pre><code>curl http://localhost/</code></pre>
        <div class="verification">✅ <code>401 Authorization Required</code></div>
    </div>
    <div class="step-card">
        <h3>9.3 Backups presentes</h3>
        <pre><code>ls -la /etc/nginx/snapshots/</code></pre>
    </div>
    <div class="step-card">
        <h3>9.4 Prueba de carga con <code>ab</code> (ApacheBench) <span style="color:#f77;">CORREGIDO</span></h3>
        <p><strong>❌ Error común:</strong> usar <code>-u admin:contraseña</code> (esa opción es para datos POST). El parámetro correcto para autenticación básica es <code>-A usuario:contraseña</code> (A mayúscula).</p>
        <pre><code>ab -n 1000 -c 10 -A admin:123 http://localhost/</code></pre>
        <p><strong>Interpretación de resultados:</strong></p>
        <ul>
            <li><code>Failed requests: 0</code> → sin errores.</li>
            <li><code>Requests per second</code> → rendimiento (ideal > 500).</li>
            <li><code>Time per request (mean)</code> → latencia media.</li>
        </ul>
        <div class="verification">✅ El test debe completar 1000 peticiones sin fallos.</div>
    </div>
    <div class="step-card">
        <h3>9.5 Verificar límites de memoria después de la carga</h3>
        <pre><code>systemctl show nginx | grep -E "MemoryMax|MemoryPeak"</code></pre>
        <p><code>MemoryPeak</code> debe mostrar un valor menor o cercano a <code>MemoryMax</code> (256 MB).</p>
    </div>

    <!-- Fase 10 Producción -->
    <h2>🚀 Fase 10 – Puesta en producción y documentación final</h2>
    <div class="step-card">
        <h3>10.1 Crear documento de acceso</h3>
        <pre><code>sudo tee /root/README_DEPLOY.txt <<EOF
=== SRE-LAB DEPLOYMENT ===
URL: http://$(hostname -I | awk '{print $1}')
Usuario: admin
Contraseña: 123
Archivo contraseñas: /etc/nginx/.htpasswd
Backup: /etc/nginx/snapshots/
Logs: /var/log/nginx/sre-lab-access.log
Health checks: /var/log/health-check.log
EOF
sudo chmod 600 /root/README_DEPLOY.txt</code></pre>
    </div>
    <div class="step-card">
        <h3>10.2 Validación automática final</h3>
        <pre><code>echo "=== VALIDACIÓN ==="
systemctl is-active nginx
curl -s -o /dev/null -w "%{http_code}\n" -u admin:123 http://localhost/
systemctl show nginx | grep MemoryMax</code></pre>
        <div class="verification">✅ Todo correcto si ves <code>active</code>, <code>200</code>, y <code>MemoryMax=268435456</code>.</div>
    </div>
    <hr>
    <p>🎉 <strong>Has completado el despliegue seguro de Nginx con hardening, aislamiento y monitorización.</strong>  
    Este runbook ya incluye todas las correcciones aplicadas durante la práctica real: backup recursivo, formato JSON bien posicionado, rutas completas en systemd, y comando <code>ab -A</code>.</p>
    <footer>Runbook generado para laboratorio SRE-LAB | Ubuntu 24.04 LTS | Revisión final 2026</footer>
</div>
</body>
</html>
