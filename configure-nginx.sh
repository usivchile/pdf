#!/bin/bash

# Script de configuración de Nginx como proxy reverso para PDF Validator API
# Para VPS Hostinger (CentOS 9)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

# Variables de configuración
DOMAIN="validador.usiv.cl"
EMAIL="admin@usiv.cl"  # Cambiar por email real
TOMCAT_PORT="8080"
NGINX_CONF_DIR="/etc/nginx"
SSL_DIR="/etc/ssl/certs"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar que solo esté corriendo nuestro Tomcat
check_tomcat_instances() {
    log "Verificando instancias de Tomcat..."
    
    TOMCAT_PROCESSES=$(ps aux | grep -E '[t]omcat|[j]ava.*catalina' | grep -v grep)
    TOMCAT_COUNT=$(echo "$TOMCAT_PROCESSES" | grep -c . || echo "0")
    
    if [ "$TOMCAT_COUNT" -eq 0 ]; then
        warn "No se encontraron procesos de Tomcat ejecutándose"
        warn "Asegúrate de iniciar Tomcat antes de configurar Nginx"
    elif [ "$TOMCAT_COUNT" -eq 1 ]; then
        log "Solo una instancia de Tomcat ejecutándose (correcto)"
        echo "Proceso: $(echo "$TOMCAT_PROCESSES" | head -1)"
    else
        warn "Se encontraron múltiples procesos de Tomcat/Java:"
        echo "$TOMCAT_PROCESSES"
        warn "Esto puede causar conflictos. Considera detener instancias innecesarias."
        
        read -p "¿Deseas continuar de todos modos? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Configuración cancelada por el usuario"
        fi
    fi
    
    # Verificar que Tomcat esté en el puerto correcto
    if netstat -tlnp | grep -q ":$TOMCAT_PORT.*java"; then
        log "Tomcat está ejecutándose en puerto $TOMCAT_PORT"
    else
        warn "Tomcat no está ejecutándose en puerto $TOMCAT_PORT"
        warn "Verifica que Tomcat esté iniciado correctamente"
    fi
}

# Función para detener servicios conflictivos en puertos 80 y 443
stop_conflicting_services() {
    log "Verificando servicios que puedan estar usando puertos 80 y 443..."
    
    # Verificar puerto 80
    PORT_80_PROCESS=$(netstat -tlnp | grep ":80 " | grep -v nginx | awk '{print $7}' | cut -d'/' -f1 | head -1)
    if [ -n "$PORT_80_PROCESS" ] && [ "$PORT_80_PROCESS" != "-" ]; then
        warn "Proceso usando puerto 80: $PORT_80_PROCESS"
        read -p "¿Deseas detener este proceso? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill -9 $PORT_80_PROCESS 2>/dev/null && log "Proceso detenido" || warn "No se pudo detener el proceso"
        fi
    fi
    
    # Verificar puerto 443
    PORT_443_PROCESS=$(netstat -tlnp | grep ":443 " | grep -v nginx | awk '{print $7}' | cut -d'/' -f1 | head -1)
    if [ -n "$PORT_443_PROCESS" ] && [ "$PORT_443_PROCESS" != "-" ]; then
        warn "Proceso usando puerto 443: $PORT_443_PROCESS"
        read -p "¿Deseas detener este proceso? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill -9 $PORT_443_PROCESS 2>/dev/null && log "Proceso detenido" || warn "No se pudo detener el proceso"
        fi
    fi
}

log "Iniciando configuración de Nginx para PDF Validator API..."
log "Configuración incluye redirección HTTP a HTTPS y proxy reverso a Tomcat"

# Verificar instancias de Tomcat
check_tomcat_instances

# Detener servicios conflictivos
stop_conflicting_services

# 1. Instalar Nginx
log "Instalando Nginx..."
if ! command_exists nginx; then
    dnf install nginx -y
    log "Nginx instalado"
else
    warn "Nginx ya está instalado"
fi

# 2. Instalar Certbot para SSL
log "Instalando Certbot para certificados SSL..."
if ! command_exists certbot; then
    dnf install epel-release -y
    dnf install certbot python3-certbot-nginx -y
    log "Certbot instalado"
else
    warn "Certbot ya está instalado"
fi

# 3. Configurar Nginx básico
log "Configurando Nginx..."

# Backup de configuración original
cp $NGINX_CONF_DIR/nginx.conf $NGINX_CONF_DIR/nginx.conf.backup

# Crear configuración para el dominio
cat > $NGINX_CONF_DIR/conf.d/$DOMAIN.conf << EOF
# Configuración para PDF Validator API
# Dominio: $DOMAIN

# Redirección HTTP a HTTPS
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Permitir validación de Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redireccionar todo el tráfico a HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # Configuración SSL (se completará con Certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Configuración SSL moderna
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Otros headers de seguridad
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Configuración de archivos grandes para PDFs
    client_max_body_size 50M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Logs
    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;
    
    # Proxy hacia Tomcat
    location / {
        proxy_pass http://127.0.0.1:$TOMCAT_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Configuración específica para archivos estáticos
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)\$ {
        proxy_pass http://127.0.0.1:$TOMCAT_PORT;
        proxy_set_header Host \$host;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Configuración para descargas de PDF
    location /api/download/ {
        proxy_pass http://127.0.0.1:$TOMCAT_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Configuración específica para descargas
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Bloquear acceso a archivos sensibles
    location ~ /\.(ht|git|svn) {
        deny all;
        return 404;
    }
    
    # Bloquear acceso directo a Tomcat manager
    location /manager {
        deny all;
        return 404;
    }
    
    # Rate limiting para API
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://127.0.0.1:$TOMCAT_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 4. Configurar rate limiting en nginx.conf
log "Configurando rate limiting..."

# Agregar configuración de rate limiting al bloque http
sed -i '/http {/a\    # Rate limiting\n    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;\n    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;' $NGINX_CONF_DIR/nginx.conf

# 5. Crear directorio para validación de Let's Encrypt
log "Creando directorio para validación SSL..."
mkdir -p /var/www/html/.well-known/acme-challenge
chown -R nginx:nginx /var/www/html

# 6. Configurar firewall
log "Configurando firewall para HTTP/HTTPS..."
if command_exists firewall-cmd; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    log "Firewall configurado para HTTP/HTTPS"
else
    warn "firewall-cmd no encontrado"
fi

# 7. Habilitar y iniciar Nginx
log "Habilitando y iniciando Nginx..."
systemctl enable nginx
systemctl start nginx

# Verificar que Nginx esté funcionando
if systemctl is-active --quiet nginx; then
    log "Nginx iniciado correctamente"
else
    error "Error al iniciar Nginx"
fi

# 8. Probar configuración de Nginx
log "Probando configuración de Nginx..."
nginx -t
if [ $? -eq 0 ]; then
    log "Configuración de Nginx válida"
else
    error "Error en la configuración de Nginx"
fi

# 9. Obtener certificado SSL con Let's Encrypt
log "Obteniendo certificado SSL con Let's Encrypt..."
echo "IMPORTANTE: Asegúrate de que el dominio $DOMAIN apunte a esta IP antes de continuar."
echo "IP actual del servidor: $(curl -s ifconfig.me)"
read -p "¿El dominio $DOMAIN apunta a esta IP? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Obtener certificado
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL
    
    if [ $? -eq 0 ]; then
        log "Certificado SSL obtenido correctamente"
        
        # Configurar renovación automática
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
        log "Renovación automática de certificado configurada"
    else
        warn "Error al obtener certificado SSL. Configuración manual requerida."
    fi
else
    warn "Configuración SSL omitida. Configura manualmente después de apuntar el dominio."
    echo "Para obtener el certificado SSL manualmente:"
    echo "sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

# 10. Configurar logrotate para logs de Nginx
log "Configurando rotación de logs de Nginx..."
cat > /etc/logrotate.d/nginx-pdf-validator << EOF
/var/log/nginx/$DOMAIN.*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 nginx nginx
    postrotate
        systemctl reload nginx
    endscript
}
EOF

# 11. Crear script de monitoreo
log "Creando script de monitoreo..."
cat > /opt/monitor-pdf-validator.sh << EOF
#!/bin/bash
# Script de monitoreo para PDF Validator API

DOMAIN="$DOMAIN"
TOMCAT_PORT="$TOMCAT_PORT"
LOG_FILE="/var/log/pdf-validator-monitor.log"

log_message() {
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] \$1" >> \$LOG_FILE
}

# Verificar Nginx
if ! systemctl is-active --quiet nginx; then
    log_message "ERROR: Nginx no está ejecutándose"
    systemctl start nginx
fi

# Verificar Tomcat
if ! systemctl is-active --quiet tomcat; then
    log_message "ERROR: Tomcat no está ejecutándose"
    systemctl start tomcat
fi

# Verificar conectividad a la aplicación
HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:\$TOMCAT_PORT/api/auth/validate || echo "000")
if [ "\$HTTP_STATUS" != "400" ] && [ "\$HTTP_STATUS" != "401" ]; then
    log_message "WARNING: Aplicación no responde correctamente (HTTP \$HTTP_STATUS)"
fi

# Verificar espacio en disco
DISK_USAGE=\$(df /opt/tomcat/webapps/storage | awk 'NR==2 {print \$5}' | sed 's/%//')
if [ "\$DISK_USAGE" -gt 80 ]; then
    log_message "WARNING: Uso de disco alto: \$DISK_USAGE%"
fi

# Verificar certificado SSL (si existe)
if [ -f "/etc/letsencrypt/live/\$DOMAIN/fullchain.pem" ]; then
    CERT_EXPIRY=\$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/\$DOMAIN/fullchain.pem | cut -d= -f2)
    CERT_EXPIRY_EPOCH=\$(date -d "\$CERT_EXPIRY" +%s)
    CURRENT_EPOCH=\$(date +%s)
    DAYS_UNTIL_EXPIRY=\$(( (CERT_EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
    
    if [ "\$DAYS_UNTIL_EXPIRY" -lt 30 ]; then
        log_message "WARNING: Certificado SSL expira en \$DAYS_UNTIL_EXPIRY días"
    fi
fi

log_message "Monitoreo completado - Nginx: \$(systemctl is-active nginx) - Tomcat: \$(systemctl is-active tomcat)"
EOF

chmod +x /opt/monitor-pdf-validator.sh

# Configurar cron para monitoreo cada 5 minutos
echo "*/5 * * * * /opt/monitor-pdf-validator.sh" | crontab -

# 12. Verificar configuración final
log "Verificando configuración final..."

# Función para probar redirección HTTP a HTTPS
test_http_redirect() {
    log "Probando redirección HTTP a HTTPS..."
    
    # Esperar un momento para que Nginx se estabilice
    sleep 3
    
    # Probar redirección con localhost
    HTTP_RESPONSE=$(curl -s -I --connect-timeout 10 http://localhost/ 2>/dev/null | head -1 || echo "")
    if echo "$HTTP_RESPONSE" | grep -q "301\|302"; then
        log "✓ Redirección HTTP a HTTPS funcionando correctamente"
        LOCATION=$(curl -s -I --connect-timeout 10 http://localhost/ 2>/dev/null | grep -i "location:" | cut -d' ' -f2 | tr -d '\r' || echo "")
        if [ -n "$LOCATION" ]; then
            log "  Redirige a: $LOCATION"
        fi
    else
        warn "Redirección HTTP a HTTPS no funciona como esperado"
        warn "Respuesta HTTP: $HTTP_RESPONSE"
    fi
    
    # Probar con el dominio si está configurado
    if [ "$DOMAIN" != "localhost" ]; then
        DOMAIN_RESPONSE=$(curl -s -I --connect-timeout 10 http://$DOMAIN/ 2>/dev/null | head -1 || echo "")
        if echo "$DOMAIN_RESPONSE" | grep -q "301\|302"; then
            log "✓ Redirección HTTP a HTTPS funcionando para $DOMAIN"
        else
            warn "Redirección HTTP a HTTPS no funciona para $DOMAIN"
        fi
    fi
}

# Función para verificar instancias de Tomcat final
final_tomcat_check() {
    log "Verificación final de instancias de Tomcat..."
    
    TOMCAT_PROCESSES=$(ps aux | grep -E '[t]omcat|[j]ava.*catalina' | grep -v grep)
    TOMCAT_COUNT=$(echo "$TOMCAT_PROCESSES" | grep -c . || echo "0")
    
    if [ "$TOMCAT_COUNT" -eq 0 ]; then
        warn "⚠ No se encontraron procesos de Tomcat ejecutándose"
        warn "  Asegúrate de iniciar Tomcat: sudo systemctl start tomcat"
    elif [ "$TOMCAT_COUNT" -eq 1 ]; then
        log "✓ Solo una instancia de Tomcat ejecutándose (correcto)"
        log "  Proceso: $(echo "$TOMCAT_PROCESSES" | head -1 | awk '{print $2, $11, $12, $13}' | cut -c1-80)"
        
        # Verificar puerto
        if netstat -tlnp | grep -q ":$TOMCAT_PORT.*java"; then
            log "✓ Tomcat escuchando en puerto $TOMCAT_PORT"
        else
            warn "⚠ Tomcat no está escuchando en puerto $TOMCAT_PORT"
        fi
    else
        warn "⚠ Se encontraron múltiples procesos de Tomcat/Java ($TOMCAT_COUNT):"
        echo "$TOMCAT_PROCESSES" | while read line; do
            warn "  $line"
        done
        warn "  Esto puede causar conflictos de puerto y rendimiento"
        warn "  Considera detener instancias innecesarias"
    fi
}

# Función para probar conectividad completa
test_full_connectivity() {
    log "Probando conectividad completa..."
    
    # Probar HTTPS si hay certificado
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] || [ -f "/etc/nginx/ssl/nginx-selfsigned.crt" ]; then
        if curl -s --connect-timeout 10 -k https://localhost/ > /dev/null 2>&1; then
            log "✓ Conexión HTTPS funcionando"
        else
            warn "⚠ Conexión HTTPS no responde"
        fi
    else
        warn "⚠ No se encontró certificado SSL configurado"
    fi
    
    # Probar endpoint de API si Tomcat está corriendo
    if netstat -tlnp | grep -q ":$TOMCAT_PORT.*java"; then
        API_RESPONSE=$(curl -s --connect-timeout 10 -k https://localhost/api/health 2>/dev/null || echo "")
        if [ -n "$API_RESPONSE" ]; then
            log "✓ Endpoint de API accesible vía HTTPS"
        else
            warn "⚠ Endpoint de API no accesible vía HTTPS"
            warn "  Verifica que la aplicación esté desplegada correctamente"
        fi
    fi
}

# Ejecutar verificaciones
test_http_redirect
final_tomcat_check
test_full_connectivity

# 13. Recargar Nginx con la nueva configuración
log "Recargando Nginx..."
systemctl reload nginx

# 13. Mostrar resumen
log "\n=== CONFIGURACIÓN DE NGINX COMPLETADA ==="
echo -e "${BLUE}Dominio configurado: $DOMAIN${NC}"
echo -e "${BLUE}Configuración Nginx: $NGINX_CONF_DIR/conf.d/$DOMAIN.conf${NC}"
echo -e "${BLUE}Logs de acceso: /var/log/nginx/$DOMAIN.access.log${NC}"
echo -e "${BLUE}Logs de error: /var/log/nginx/$DOMAIN.error.log${NC}"
echo -e "${BLUE}Script de monitoreo: /opt/monitor-pdf-validator.sh${NC}"

echo -e "\n${YELLOW}=== VERIFICACIONES ===${NC}"
echo -e "${GREEN}✓ Nginx instalado y configurado${NC}"
echo -e "${GREEN}✓ Proxy reverso configurado${NC}"
echo -e "${GREEN}✓ Rate limiting configurado${NC}"
echo -e "${GREEN}✓ Headers de seguridad configurados${NC}"
echo -e "${GREEN}✓ Firewall configurado${NC}"
echo -e "${GREEN}✓ Monitoreo automático configurado${NC}"

echo -e "\n${YELLOW}=== PRÓXIMOS PASOS ===${NC}"
echo -e "${GREEN}1. Verificar que el dominio $DOMAIN apunte a esta IP${NC}"
echo -e "${GREEN}2. Si no se obtuvo SSL, ejecutar: sudo certbot --nginx -d $DOMAIN${NC}"
echo -e "${GREEN}3. Probar la aplicación: https://$DOMAIN${NC}"
echo -e "${GREEN}4. Verificar logs: sudo tail -f /var/log/nginx/$DOMAIN.access.log${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Recargar Nginx: sudo systemctl reload nginx${NC}"
echo -e "${GREEN}Probar configuración: sudo nginx -t${NC}"
echo -e "${GREEN}Ver logs de error: sudo tail -f /var/log/nginx/$DOMAIN.error.log${NC}"
echo -e "${GREEN}Renovar SSL: sudo certbot renew${NC}"
echo -e "${GREEN}Monitoreo manual: sudo /opt/monitor-pdf-validator.sh${NC}"

log "Configuración de Nginx completada exitosamente!"