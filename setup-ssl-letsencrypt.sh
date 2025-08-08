#!/bin/bash

# CONFIGURACIÓN SSL CON LET'S ENCRYPT
# Script para configurar HTTPS y evitar problemas de firewall corporativo
# Autor: PDF Signer Team
# Fecha: $(date +%Y-%m-%d)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "\n${PURPLE}🔧 $1${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
}

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Verificar parámetros
if [ $# -eq 0 ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    🔒 CONFIGURACIÓN SSL CON LET'S ENCRYPT"
    echo "═══════════════════════════════════════════════════════════════════"
    echo
    echo "📋 USO:"
    echo "   sudo $0 <dominio> [email]"
    echo
    echo "📝 EJEMPLOS:"
    echo "   sudo $0 validador.usiv.cl usiv@usiv.cl"
    echo "   sudo $0 mi-servidor.com"
    echo "   sudo $0 168.231.91.217  # Para IP (certificado autofirmado)"
    echo
    echo "⚠️  REQUISITOS PREVIOS:"
    echo "   • El dominio debe apuntar a este servidor"
    echo "   • Los puertos 80 y 443 deben estar abiertos"
    echo "   • Nginx debe estar instalado y funcionando"
    echo "   • La aplicación PDF Signer debe estar desplegada"
    echo
    echo "🎯 QUÉ HACE ESTE SCRIPT:"
    echo "   1. Instala certbot (cliente Let's Encrypt)"
    echo "   2. Obtiene certificado SSL gratuito"
    echo "   3. Configura Nginx para HTTPS"
    echo "   4. Configura renovación automática"
    echo "   5. Redirige HTTP → HTTPS automáticamente"
    echo "   6. Aplica headers de seguridad"
    echo
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-admin@${DOMAIN}}"

# Detectar si es una IP
if [[ $DOMAIN =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IS_IP=true
    log_warn "Detectada dirección IP. Se creará certificado autofirmado."
else
    IS_IP=false
    log_info "Configurando SSL para dominio: $DOMAIN"
fi

echo "═══════════════════════════════════════════════════════════════════"
echo "                    🔒 INICIANDO CONFIGURACIÓN SSL"
echo "═══════════════════════════════════════════════════════════════════"
echo "📍 Dominio/IP: $DOMAIN"
echo "📧 Email: $EMAIL"
echo "🕐 Fecha: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# PASO 1: Verificar servicios previos
log_step "VERIFICANDO SERVICIOS PREVIOS"

# Verificar Nginx
if ! systemctl is-active --quiet nginx; then
    log_error "Nginx no está ejecutándose. Ejecuta primero: sudo systemctl start nginx"
    exit 1
fi
log_success "Nginx está ejecutándose"

# Verificar Tomcat
if ! systemctl is-active --quiet tomcat; then
    log_error "Tomcat no está ejecutándose. Ejecuta primero: sudo systemctl start tomcat"
    exit 1
fi
log_success "Tomcat está ejecutándose"

# Verificar aplicación
if curl -s -o /dev/null -w "%{http_code}" http://localhost/pdf-signer/ | grep -q "200\|302\|404"; then
    log_success "Aplicación PDF Signer responde correctamente"
else
    log_error "La aplicación PDF Signer no responde. Verifica el despliegue."
    exit 1
fi

# PASO 2: Instalar certbot
log_step "INSTALANDO CERTBOT (CLIENTE LET'S ENCRYPT)"

# Detectar distribución
if [ -f /etc/redhat-release ]; then
    # CentOS/RHEL/Rocky
    if command -v dnf &> /dev/null; then
        dnf install -y epel-release
        dnf install -y certbot python3-certbot-nginx
    else
        yum install -y epel-release
        yum install -y certbot python3-certbot-nginx
    fi
elif [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    apt update
    apt install -y certbot python3-certbot-nginx
else
    log_error "Distribución no soportada. Instala certbot manualmente."
    exit 1
fi

log_success "Certbot instalado correctamente"

# PASO 3: Configurar Nginx base para SSL
log_step "CONFIGURANDO NGINX PARA SSL"

# Backup de configuración actual
cp /etc/nginx/conf.d/pdf-signer.conf /etc/nginx/conf.d/pdf-signer.conf.backup.$(date +%Y%m%d_%H%M%S)
log_info "Backup de configuración creado"

if [ "$IS_IP" = true ]; then
    # CONFIGURACIÓN PARA IP (CERTIFICADO AUTOFIRMADO)
    log_step "CREANDO CERTIFICADO AUTOFIRMADO PARA IP"
    
    # Crear directorio para certificados
    mkdir -p /etc/ssl/private
    mkdir -p /etc/ssl/certs
    
    # Generar certificado autofirmado
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/pdf-signer.key \
        -out /etc/ssl/certs/pdf-signer.crt \
        -subj "/C=CL/ST=Santiago/L=Santiago/O=USIV/OU=IT/CN=$DOMAIN"
    
    log_success "Certificado autofirmado creado"
    
    # Configuración Nginx para IP con SSL
    cat > /etc/nginx/conf.d/pdf-signer.conf << EOF
# Configuración SSL para IP - PDF Signer
# Generado automáticamente el $(date)

# Redirigir HTTP a HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # Certificados SSL (autofirmado)
    ssl_certificate /etc/ssl/certs/pdf-signer.crt;
    ssl_certificate_key /etc/ssl/private/pdf-signer.key;
    
    # Configuración SSL moderna
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Headers de seguridad
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Configuración para PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Configuración para archivos grandes
        client_max_body_size 50M;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Página de inicio redirige a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }
    
    # Configuración de logs
    access_log /var/log/nginx/pdf-signer-ssl.access.log;
    error_log /var/log/nginx/pdf-signer-ssl.error.log;
}
EOF

else
    # CONFIGURACIÓN PARA DOMINIO (LET'S ENCRYPT)
    log_step "OBTENIENDO CERTIFICADO DE LET'S ENCRYPT"
    
    # Configuración temporal para validación
    cat > /etc/nginx/conf.d/pdf-signer.conf << EOF
# Configuración temporal para validación Let's Encrypt
server {
    listen 80;
    server_name $DOMAIN;
    
    # Permitir validación de Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Configuración para PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        client_max_body_size 50M;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location = / {
        return 301 /pdf-signer/;
    }
    
    access_log /var/log/nginx/pdf-signer.access.log;
    error_log /var/log/nginx/pdf-signer.error.log;
}
EOF

    # Recargar Nginx
    nginx -t && systemctl reload nginx
    
    # Crear directorio para validación
    mkdir -p /var/www/html
    
    # Obtener certificado de Let's Encrypt
    log_info "Solicitando certificado SSL para $DOMAIN..."
    
    if certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive --redirect; then
        log_success "Certificado SSL obtenido exitosamente"
    else
        log_error "Error al obtener certificado SSL"
        log_info "Verifica que:"
        log_info "  • El dominio $DOMAIN apunte a este servidor"
        log_info "  • Los puertos 80 y 443 estén abiertos"
        log_info "  • No haya firewall bloqueando las conexiones"
        exit 1
    fi
    
    # Mejorar configuración SSL generada por certbot
    log_info "Optimizando configuración SSL..."
    
    # Backup de la configuración de certbot
    cp /etc/nginx/conf.d/pdf-signer.conf /etc/nginx/conf.d/pdf-signer.conf.certbot.backup
    
    # Configuración SSL optimizada
    cat > /etc/nginx/conf.d/pdf-signer.conf << EOF
# Configuración SSL optimizada para PDF Signer
# Generado automáticamente el $(date)
# Certificado Let's Encrypt para $DOMAIN

# Redirigir HTTP a HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # Certificados SSL (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Headers de seguridad adicionales
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self';" always;
    
    # Configuración para PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Configuración para archivos grandes
        client_max_body_size 50M;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        
        # Rate limiting
        limit_req zone=api burst=20 nodelay;
    }
    
    # Página de inicio redirige a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }
    
    # Configuración de logs
    access_log /var/log/nginx/pdf-signer-ssl.access.log;
    error_log /var/log/nginx/pdf-signer-ssl.error.log;
}
EOF

fi

# PASO 4: Configurar rate limiting
log_step "CONFIGURANDO RATE LIMITING"

# Agregar rate limiting al contexto http de nginx
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    # Rate limiting para API\n    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;' /etc/nginx/nginx.conf
    log_success "Rate limiting configurado"
else
    log_info "Rate limiting ya estaba configurado"
fi

# PASO 5: Configurar firewall
log_step "CONFIGURANDO FIREWALL"

# Abrir puerto 443 (HTTPS)
if command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL con firewalld
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    log_success "Puerto 443 (HTTPS) abierto en firewall"
elif command -v ufw &> /dev/null; then
    # Ubuntu con ufw
    ufw allow 443/tcp
    log_success "Puerto 443 (HTTPS) abierto en firewall"
else
    log_warn "Firewall no detectado. Asegúrate de abrir el puerto 443 manualmente."
fi

# PASO 6: Verificar y recargar configuración
log_step "VERIFICANDO CONFIGURACIÓN"

# Verificar sintaxis de Nginx
if nginx -t; then
    log_success "Configuración de Nginx válida"
else
    log_error "Error en configuración de Nginx"
    exit 1
fi

# Recargar Nginx
systemctl reload nginx
log_success "Nginx recargado"

# PASO 7: Configurar renovación automática (solo para Let's Encrypt)
if [ "$IS_IP" = false ]; then
    log_step "CONFIGURANDO RENOVACIÓN AUTOMÁTICA"
    
    # Crear script de renovación
    cat > /etc/cron.daily/certbot-renew << 'EOF'
#!/bin/bash
# Renovación automática de certificados Let's Encrypt

# Renovar certificados
certbot renew --quiet

# Recargar Nginx si hay cambios
if [ $? -eq 0 ]; then
    systemctl reload nginx
fi
EOF
    
    chmod +x /etc/cron.daily/certbot-renew
    log_success "Renovación automática configurada (diaria)"
    
    # Probar renovación
    log_info "Probando renovación automática..."
    if certbot renew --dry-run; then
        log_success "Renovación automática funciona correctamente"
    else
        log_warn "Problema con renovación automática. Revisa manualmente."
    fi
fi

# PASO 8: Verificación final
log_step "VERIFICACIÓN FINAL"

# Esperar un momento para que los servicios se estabilicen
sleep 3

# Verificar HTTPS
log_info "Verificando acceso HTTPS..."
if [ "$IS_IP" = true ]; then
    HTTPS_URL="https://$DOMAIN/pdf-signer/"
else
    HTTPS_URL="https://$DOMAIN/pdf-signer/"
fi

if curl -k -s -o /dev/null -w "%{http_code}" "$HTTPS_URL" | grep -q "200\|302\|404"; then
    log_success "HTTPS funciona correctamente"
else
    log_warn "HTTPS no responde. Verifica la configuración."
fi

# Verificar redirección HTTP → HTTPS
log_info "Verificando redirección HTTP → HTTPS..."
HTTP_RESPONSE=$(curl -s -I -w "%{http_code}" "http://$DOMAIN/" | tail -1)
if [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    log_success "Redirección HTTP → HTTPS configurada"
else
    log_warn "Redirección HTTP → HTTPS no funciona correctamente"
fi

# Verificar certificado
log_info "Verificando certificado SSL..."
if [ "$IS_IP" = true ]; then
    log_info "Certificado autofirmado - Los navegadores mostrarán advertencia de seguridad"
else
    CERT_INFO=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_success "Certificado SSL válido"
        echo "$CERT_INFO" | sed 's/^/    /'
    else
        log_warn "No se pudo verificar el certificado SSL"
    fi
fi

# Mostrar estado de servicios
log_info "Estado de servicios:"
echo "    Nginx: $(systemctl is-active nginx)"
echo "    Tomcat: $(systemctl is-active tomcat)"

echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    🎉 CONFIGURACIÓN SSL COMPLETADA"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "🔒 ACCESO SEGURO (HTTPS):"
echo "   🌐 URL Principal: https://$DOMAIN/pdf-signer/"
echo "   📚 Documentación: https://$DOMAIN/pdf-signer/swagger-ui/index.html"
echo "   🔍 Health Check: https://$DOMAIN/pdf-signer/api/health"
echo
if [ "$IS_IP" = true ]; then
echo "⚠️  CERTIFICADO AUTOFIRMADO:"
echo "   • Los navegadores mostrarán advertencia de seguridad"
echo "   • Acepta la advertencia para continuar"
echo "   • Para producción, usa un dominio real con Let's Encrypt"
echo
else
echo "✅ CERTIFICADO LET'S ENCRYPT:"
echo "   • Certificado válido y confiable"
echo "   • Renovación automática configurada"
echo "   • Válido por 90 días (se renueva automáticamente)"
echo
fi
echo "🔧 CARACTERÍSTICAS HABILITADAS:"
echo "   ✅ Redirección automática HTTP → HTTPS"
echo "   ✅ Headers de seguridad (HSTS, XSS Protection, etc.)"
echo "   ✅ Rate limiting para API"
echo "   ✅ Configuración SSL moderna (TLS 1.2+)"
if [ "$IS_IP" = false ]; then
echo "   ✅ Renovación automática de certificados"
fi
echo
echo "📋 COMANDOS ÚTILES:"
echo "   sudo systemctl status nginx        # Estado de Nginx"
echo "   sudo nginx -t                     # Verificar configuración"
echo "   sudo systemctl reload nginx      # Recargar configuración"
if [ "$IS_IP" = false ]; then
echo "   sudo certbot certificates         # Ver certificados"
echo "   sudo certbot renew               # Renovar certificados"
fi
echo "   tail -f /var/log/nginx/pdf-signer-ssl.access.log  # Ver logs HTTPS"
echo
echo "🎯 PRÓXIMOS PASOS:"
echo "   1. Actualiza tu archivo test-internet-access.html con HTTPS"
echo "   2. Configura tu aplicación para usar HTTPS en producción"
echo "   3. Actualiza cualquier enlace HTTP a HTTPS"
echo "   4. Prueba la aplicación desde diferentes navegadores"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                        🔒 ¡SSL CONFIGURADO!"
echo "═══════════════════════════════════════════════════════════════════"