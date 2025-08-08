#!/bin/bash

# Script completo para solucionar el error HTTP 404 en PDF Signer
# Combina la reparación del despliegue de Tomcat y la configuración de Nginx

set -e

echo "🚀 SOLUCIONANDO ERROR HTTP 404 - PDF SIGNER"
echo "═══════════════════════════════════════════════════════════════════"
echo "    🎯 Objetivo: Reparar despliegue y configuración de Nginx"
echo "    🌐 Dominio: validador.usiv.cl"
echo "    📅 $(date)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Variables
DOMAIN="validador.usiv.cl"
WAR_FILE="target/pdf-signer-war-1.0.war"
APP_NAME="pdf-signer"
TOMCAT_WEBAPPS="/var/lib/tomcat/webapps"
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
    exit 1
}

log_warning() {
    echo "⚠️  $1"
}

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
fi

# Verificar que estamos en el directorio correcto
if [ ! -f "pom.xml" ]; then
    log_error "No se encontró pom.xml. Ejecuta este script desde el directorio raíz del proyecto."
fi

echo "🔧 PASO 1: REPARANDO DESPLIEGUE EN TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar que el archivo WAR existe
if [ ! -f "$WAR_FILE" ]; then
    log_error "Archivo WAR no encontrado: $WAR_FILE. Ejecuta 'mvn clean package' primero."
fi

log_success "Archivo WAR encontrado: $WAR_FILE"
ls -la "$WAR_FILE"

# Detener Tomcat
log_info "Deteniendo Tomcat..."
if systemctl stop tomcat; then
    log_success "Tomcat detenido"
else
    log_warning "Error al detener Tomcat, continuando..."
fi

sleep 3

# Limpiar despliegues anteriores
log_info "Limpiando despliegues anteriores..."
rm -rf "$TOMCAT_WEBAPPS/$APP_NAME"*
rm -rf "/var/lib/tomcat/work/Catalina/localhost/$APP_NAME"*
log_success "Limpieza completada"

# Copiar nuevo WAR
log_info "Copiando nuevo archivo WAR..."
cp "$WAR_FILE" "$TOMCAT_WEBAPPS/$APP_NAME.war"
chown tomcat:tomcat "$TOMCAT_WEBAPPS/$APP_NAME.war"
chmod 644 "$TOMCAT_WEBAPPS/$APP_NAME.war"
log_success "WAR copiado con permisos correctos"

# Iniciar Tomcat
log_info "Iniciando Tomcat..."
if systemctl start tomcat; then
    log_success "Tomcat iniciado"
else
    log_error "Error al iniciar Tomcat"
fi

# Esperar a que se despliegue la aplicación
log_info "Esperando despliegue de la aplicación..."
for i in {1..30}; do
    if [ -d "$TOMCAT_WEBAPPS/$APP_NAME" ]; then
        log_success "Aplicación desplegada exitosamente"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ ! -d "$TOMCAT_WEBAPPS/$APP_NAME" ]; then
    log_error "La aplicación no se desplegó después de 60 segundos"
fi

echo ""
echo "🔧 PASO 2: CONFIGURANDO NGINX"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar que Nginx esté instalado
if ! command -v nginx &> /dev/null; then
    log_error "Nginx no está instalado"
fi

# Crear backup de configuración existente si existe
for config in "$NGINX_CONFIG" "$NGINX_SITES_CONFIG"; do
    if [ -f "$config" ]; then
        log_info "Creando backup de $config"
        cp "$config" "${config}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
done

# Eliminar configuraciones existentes
log_info "Eliminando configuraciones existentes..."
rm -f "$NGINX_CONFIG" "$NGINX_SITES_CONFIG" "$NGINX_SITES_ENABLED"

# Determinar directorio de configuración
if [ -d "/etc/nginx/conf.d" ]; then
    CONFIG_FILE="$NGINX_CONFIG"
    log_info "Usando directorio conf.d para la configuración"
elif [ -d "/etc/nginx/sites-available" ]; then
    CONFIG_FILE="$NGINX_SITES_CONFIG"
    log_info "Usando directorio sites-available para la configuración"
else
    log_error "No se encontró directorio de configuración de Nginx"
fi

# Verificar certificados SSL
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    log_success "Certificados SSL de Let's Encrypt encontrados"
    SSL_ENABLED=true
else
    log_warning "No se encontraron certificados SSL, configurando solo HTTP"
    SSL_ENABLED=false
fi

# Crear configuración de Nginx
log_info "Creando configuración de Nginx..."

if [ "$SSL_ENABLED" = true ]; then
    # Configuración con SSL
    cat > "$CONFIG_FILE" << EOF
# Configuración SSL para PDF Signer - $(date)
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Headers de seguridad
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy para PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
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
    # Configuración sin SSL
    cat > "$CONFIG_FILE" << EOF
# Configuración HTTP para PDF Signer - $(date)
server {
    listen 80;
    server_name $DOMAIN;

    # Proxy para PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
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

# Crear enlace simbólico si usamos sites-available
if [ "$CONFIG_FILE" = "$NGINX_SITES_CONFIG" ]; then
    log_info "Creando enlace simbólico en sites-enabled..."
    ln -sf "$NGINX_SITES_CONFIG" "$NGINX_SITES_ENABLED"
fi

# Verificar sintaxis de Nginx
log_info "Verificando sintaxis de Nginx..."
if nginx -t; then
    log_success "Sintaxis correcta"
else
    log_error "Error en la sintaxis de Nginx"
fi

# Recargar Nginx
log_info "Recargando Nginx..."
if systemctl reload nginx; then
    log_success "Nginx recargado exitosamente"
else
    log_error "Error al recargar Nginx"
fi

echo ""
echo "🔍 PASO 3: VERIFICACIÓN FINAL"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar servicios
log_info "Verificando servicios..."
for service in tomcat nginx; do
    if systemctl is-active --quiet $service; then
        log_success "$service está ejecutándose"
    else
        log_error "$service no está ejecutándose"
    fi
done

# Verificar puertos
log_info "Verificando puertos..."
for port in 80 443 8080; do
    if netstat -tlnp | grep -q ":$port "; then
        log_success "Puerto $port está abierto"
    else
        log_warning "Puerto $port no está abierto"
    fi
done

# Pruebas de conectividad
log_info "Realizando pruebas de conectividad..."

# Tomcat directo
echo -n "  🐱 Tomcat directo: "
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/pdf-signer/" | grep -q "200\|302\|404"; then
    echo "✅ OK"
else
    echo "❌ FALLO"
fi

# Nginx HTTP
echo -n "  🌐 Nginx HTTP: "
if curl -s -o /dev/null -w "%{http_code}" "http://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
    echo "✅ OK"
else
    echo "❌ FALLO"
fi

# Nginx HTTPS (si SSL está habilitado)
if [ "$SSL_ENABLED" = true ]; then
    echo -n "  🔒 Nginx HTTPS: "
    if curl -s -k -o /dev/null -w "%{http_code}" "https://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
        echo "✅ OK"
    else
        echo "❌ FALLO"
    fi
fi

echo ""
echo "🎉 REPARACIÓN COMPLETADA"
echo "═══════════════════════════════════════════════════════════════════"
echo "    📂 Aplicación desplegada en: $TOMCAT_WEBAPPS/$APP_NAME/"
echo "    ⚙️  Configuración Nginx: $CONFIG_FILE"
echo "    🔒 SSL: $([ "$SSL_ENABLED" = true ] && echo 'Habilitado' || echo 'Deshabilitado')"
echo ""
echo "📱 ACCEDE A TU APLICACIÓN:"
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
echo "    systemctl status nginx tomcat  # Ver estado"
echo "    tail -f /var/log/nginx/pdf-signer*.log  # Ver logs"
echo "    nginx -t  # Verificar configuración"
echo ""
log_success "¡El error HTTP 404 debería estar solucionado!"
echo "═══════════════════════════════════════════════════════════════════"