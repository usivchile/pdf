#!/bin/bash

# Script para recrear la configuración de Nginx para PDF Signer
# Soluciona el error HTTP 404 configurando correctamente el proxy reverso

set -e

echo "🔧 REPARANDO CONFIGURACIÓN DE NGINX"
echo "═══════════════════════════════════════════════════════════════════"

# Variables
DOMAIN="validador.usiv.cl"
NGINX_CONFIG="/etc/nginx/conf.d/pdf-signer.conf"
NGINX_SITES_CONFIG="/etc/nginx/sites-available/pdf-signer"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled/pdf-signer"

# Función para logging
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1"
}

log_warning() {
    echo "⚠️  $1"
}

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Verificar que Nginx esté instalado
if ! command -v nginx &> /dev/null; then
    log_error "Nginx no está instalado"
    exit 1
fi

# Verificar que Tomcat esté ejecutándose
if ! systemctl is-active --quiet tomcat; then
    log_warning "Tomcat no está ejecutándose. Iniciando..."
    systemctl start tomcat
    sleep 5
fi

# Verificar que la aplicación esté desplegada en Tomcat
if [ ! -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    log_error "La aplicación pdf-signer no está desplegada en Tomcat"
    log_info "Ejecuta primero: ./fix-deployment.sh"
    exit 1
fi

# Crear backup de configuración existente si existe
if [ -f "$NGINX_CONFIG" ]; then
    log_info "Creando backup de configuración existente..."
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Eliminar configuraciones existentes
log_info "Eliminando configuraciones existentes..."
rm -f "$NGINX_CONFIG"
rm -f "$NGINX_SITES_CONFIG"
rm -f "$NGINX_SITES_ENABLED"

# Determinar si usar conf.d o sites-available
if [ -d "/etc/nginx/conf.d" ]; then
    CONFIG_FILE="$NGINX_CONFIG"
    log_info "Usando directorio conf.d para la configuración"
elif [ -d "/etc/nginx/sites-available" ]; then
    CONFIG_FILE="$NGINX_SITES_CONFIG"
    log_info "Usando directorio sites-available para la configuración"
else
    log_error "No se encontró directorio de configuración de Nginx"
    exit 1
fi

# Verificar si hay certificados SSL de Let's Encrypt
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    log_success "Certificados SSL de Let's Encrypt encontrados"
    SSL_ENABLED=true
else
    log_warning "No se encontraron certificados SSL de Let's Encrypt"
    SSL_ENABLED=false
fi

# Crear configuración de Nginx
log_info "Creando nueva configuración de Nginx..."

if [ "$SSL_ENABLED" = true ]; then
    # Configuración con SSL
    cat > "$CONFIG_FILE" << 'EOF'
# Configuración SSL para PDF Signer
# Redirigir HTTP a HTTPS
server {
    listen 80;
    server_name validador.usiv.cl;
    return 301 https://$server_name$request_uri;
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name validador.usiv.cl;

    # Certificados SSL (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/validador.usiv.cl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/validador.usiv.cl/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Headers de seguridad
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Configuración del proxy para la aplicación PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Redirigir raíz a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }

    # Logs
    access_log /var/log/nginx/pdf-signer-ssl.access.log;
    error_log /var/log/nginx/pdf-signer-ssl.error.log;
}
EOF
else
    # Configuración sin SSL (solo HTTP)
    cat > "$CONFIG_FILE" << 'EOF'
# Configuración HTTP para PDF Signer
server {
    listen 80;
    server_name validador.usiv.cl;

    # Configuración del proxy para la aplicación PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Redirigir raíz a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }

    # Logs
    access_log /var/log/nginx/pdf-signer.access.log;
    error_log /var/log/nginx/pdf-signer.error.log;
}
EOF
fi

# Si usamos sites-available, crear enlace simbólico
if [ "$CONFIG_FILE" = "$NGINX_SITES_CONFIG" ]; then
    log_info "Creando enlace simbólico en sites-enabled..."
    ln -sf "$NGINX_SITES_CONFIG" "$NGINX_SITES_ENABLED"
fi

# Verificar sintaxis de Nginx
log_info "Verificando sintaxis de configuración de Nginx..."
if nginx -t; then
    log_success "Sintaxis de configuración correcta"
else
    log_error "Error en la sintaxis de configuración de Nginx"
    exit 1
fi

# Recargar Nginx
log_info "Recargando configuración de Nginx..."
if systemctl reload nginx; then
    log_success "Nginx recargado exitosamente"
else
    log_error "Error al recargar Nginx"
    exit 1
fi

# Verificar estado de servicios
echo ""
echo "🔍 VERIFICANDO SERVICIOS"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar Tomcat
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat está ejecutándose"
else
    log_error "Tomcat no está ejecutándose"
fi

# Verificar Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ejecutándose"
else
    log_error "Nginx no está ejecutándose"
fi

# Verificar puertos
echo ""
echo "🔍 VERIFICANDO PUERTOS"
echo "═══════════════════════════════════════════════════════════════════"

if netstat -tlnp | grep -q ":80 "; then
    log_success "Puerto 80 (HTTP) está abierto"
else
    log_warning "Puerto 80 (HTTP) no está abierto"
fi

if netstat -tlnp | grep -q ":443 "; then
    log_success "Puerto 443 (HTTPS) está abierto"
else
    log_warning "Puerto 443 (HTTPS) no está abierto"
fi

if netstat -tlnp | grep -q ":8080 "; then
    log_success "Puerto 8080 (Tomcat) está abierto"
else
    log_error "Puerto 8080 (Tomcat) no está abierto"
fi

# Pruebas de conectividad
echo ""
echo "🔍 PRUEBAS DE CONECTIVIDAD"
echo "═══════════════════════════════════════════════════════════════════"

# Probar Tomcat directo
log_info "Probando conexión directa a Tomcat..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/pdf-signer/" | grep -q "200\|302\|404"; then
    log_success "Tomcat responde correctamente"
else
    log_error "Tomcat no responde"
fi

# Probar Nginx HTTP
log_info "Probando conexión a través de Nginx HTTP..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
    log_success "Nginx HTTP responde correctamente"
else
    log_warning "Nginx HTTP no responde como se esperaba"
fi

# Probar Nginx HTTPS (si SSL está habilitado)
if [ "$SSL_ENABLED" = true ]; then
    log_info "Probando conexión a través de Nginx HTTPS..."
    if curl -s -k -o /dev/null -w "%{http_code}" "https://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
        log_success "Nginx HTTPS responde correctamente"
    else
        log_warning "Nginx HTTPS no responde como se esperaba"
    fi
fi

# Resumen final
echo ""
echo "📋 RESUMEN DE CONFIGURACIÓN"
echo "═══════════════════════════════════════════════════════════════════"
echo "    🌐 Dominio: $DOMAIN"
echo "    📁 Configuración: $CONFIG_FILE"
echo "    🔒 SSL: $([ "$SSL_ENABLED" = true ] && echo 'Habilitado' || echo 'Deshabilitado')"
echo "    📂 Aplicación: /var/lib/tomcat/webapps/pdf-signer/"
echo ""
echo "📱 URLs DE ACCESO:"
if [ "$SSL_ENABLED" = true ]; then
    echo "    🔒 Aplicación: https://$DOMAIN/pdf-signer/"
    echo "    🔍 Health Check: https://$DOMAIN/pdf-signer/api/health"
    echo "    📚 Swagger UI: https://$DOMAIN/pdf-signer/swagger-ui/"
else
    echo "    🌐 Aplicación: http://$DOMAIN/pdf-signer/"
    echo "    🔍 Health Check: http://$DOMAIN/pdf-signer/api/health"
    echo "    📚 Swagger UI: http://$DOMAIN/pdf-signer/swagger-ui/"
fi
echo "    🐱 Tomcat directo: http://$DOMAIN:8080/pdf-signer/"
echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "    systemctl status nginx tomcat    # Ver estado de servicios"
echo "    nginx -t                         # Verificar configuración"
echo "    tail -f /var/log/nginx/pdf-signer*.log  # Ver logs"
echo "    curl -I http://localhost:8080/pdf-signer/  # Probar Tomcat"
if [ "$SSL_ENABLED" = true ]; then
    echo "    curl -I https://$DOMAIN/pdf-signer/        # Probar HTTPS"
else
    echo "    curl -I http://$DOMAIN/pdf-signer/         # Probar HTTP"
fi
echo ""
log_success "Configuración de Nginx completada"
echo "═══════════════════════════════════════════════════════════════════"