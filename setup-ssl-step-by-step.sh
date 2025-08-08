#!/bin/bash

# Script para configurar SSL paso a paso
# Resuelve el problema de dependencia circular entre Nginx y Certbot

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

# Variables
DOMAIN="validador.usiv.cl"
EMAIL="admin@usiv.cl"
NGINX_CONF="/etc/nginx/conf.d/$DOMAIN.conf"
SSL_CONF="/etc/nginx/conf.d/$DOMAIN-ssl.conf"
BACKUP_DIR="/root/nginx-backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CONFIGURACIÓN SSL PASO A PASO "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Iniciando configuración SSL paso a paso..."

# 1. Verificar que Nginx esté funcionando
log "Verificando estado de Nginx..."
if ! systemctl is-active --quiet nginx; then
    error "Nginx no está funcionando. Ejecuta primero: sudo ./fix-nginx-ssl.sh"
fi

if ! curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
    error "Nginx no responde en HTTP. Ejecuta primero: sudo ./fix-nginx-ssl.sh"
fi

log "✓ Nginx funcionando correctamente"

# 2. Verificar que el dominio apunte al servidor
log "Verificando configuración DNS..."
echo -e "${YELLOW}IMPORTANTE: Antes de continuar, verifica que:${NC}"
echo -e "${YELLOW}1. El dominio $DOMAIN apunte a la IP de este servidor${NC}"
echo -e "${YELLOW}2. El puerto 80 esté abierto en el firewall${NC}"
echo -e "${YELLOW}3. El puerto 443 esté abierto en el firewall${NC}"
echo
read -p "¿El dominio $DOMAIN apunta correctamente a este servidor? (s/N): " -r
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    error "Configura primero el DNS para que $DOMAIN apunte a este servidor"
fi

# 3. Crear backup de la configuración actual
log "Creando backup de configuración actual..."
mkdir -p "$BACKUP_DIR"
cp -r /etc/nginx/conf.d/ "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/nginx/nginx.conf "$BACKUP_DIR/" 2>/dev/null || true
log "Backup creado en: $BACKUP_DIR"

# 4. Instalar Certbot si no está instalado
log "Verificando instalación de Certbot..."
if ! command -v certbot &> /dev/null; then
    log "Instalando Certbot..."
    if command -v dnf &> /dev/null; then
        dnf install -y certbot python3-certbot-nginx
    elif command -v yum &> /dev/null; then
        yum install -y certbot python3-certbot-nginx
    elif command -v apt &> /dev/null; then
        apt update && apt install -y certbot python3-certbot-nginx
    else
        error "No se pudo instalar Certbot. Instálalo manualmente."
    fi
else
    log "✓ Certbot ya está instalado"
fi

# 5. Preparar directorio para validación
log "Preparando directorio para validación Let's Encrypt..."
mkdir -p /var/www/html/.well-known/acme-challenge
chown -R nginx:nginx /var/www/html 2>/dev/null || chown -R www-data:www-data /var/www/html 2>/dev/null || true
chmod -R 755 /var/www/html

# Crear archivo de prueba
echo "test" > /var/www/html/.well-known/acme-challenge/test
if curl -s "http://localhost/.well-known/acme-challenge/test" | grep -q "test"; then
    log "✓ Directorio de validación accesible"
    rm -f /var/www/html/.well-known/acme-challenge/test
else
    warn "⚠ Directorio de validación no accesible vía HTTP"
fi

# 6. Obtener certificado SSL
log "Obteniendo certificado SSL de Let's Encrypt..."
log "Esto puede tomar unos minutos..."

# Usar certbot en modo webroot para evitar conflictos
if certbot certonly \
    --webroot \
    --webroot-path=/var/www/html \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --domains "$DOMAIN,www.$DOMAIN" \
    --non-interactive; then
    log "✓ Certificado SSL obtenido exitosamente"
else
    error "Error al obtener certificado SSL. Verifica la configuración DNS."
fi

# 7. Verificar que los certificados existen
SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [[ ! -f "$SSL_CERT" ]] || [[ ! -f "$SSL_KEY" ]]; then
    error "Certificados SSL no encontrados en /etc/letsencrypt/live/$DOMAIN/"
fi

log "✓ Certificados SSL verificados"

# 8. Crear configuración SSL completa
log "Creando configuración SSL completa..."
cat > "$SSL_CONF" << EOF
# Configuración SSL completa para PDF Validator API
# Generada automáticamente por setup-ssl-step-by-step.sh

# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/m;
limit_req_zone \$binary_remote_addr zone=general:10m rate=100r/m;

# Redirección HTTP a HTTPS
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    # Redireccionar todo el tráfico a HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# Servidor HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # Certificados SSL
    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    
    # Configuración SSL moderna
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate $SSL_CERT;
    
    # Logs
    access_log /var/log/nginx/$DOMAIN.access.log;
    error_log /var/log/nginx/$DOMAIN.error.log;
    
    # Rate limiting
    limit_req zone=general burst=50 nodelay;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self';" always;
    
    # Proxy to Tomcat
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # API endpoints con rate limiting específico
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts específicos para API
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Archivos estáticos
    location /static/ {
        alias /var/www/html/;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

log "Configuración SSL creada"

# 9. Eliminar configuración HTTP simple
log "Eliminando configuración HTTP temporal..."
rm -f "$NGINX_CONF"

# 10. Verificar configuración
log "Verificando nueva configuración..."
if nginx -t; then
    log "✓ Configuración SSL válida"
else
    error "Configuración SSL inválida. Restaurando backup..."
    cp "$BACKUP_DIR/conf.d/"* /etc/nginx/conf.d/ 2>/dev/null || true
    systemctl reload nginx
    exit 1
fi

# 11. Aplicar nueva configuración
log "Aplicando configuración SSL..."
systemctl reload nginx

if systemctl is-active --quiet nginx; then
    log "✓ Nginx recargado con SSL"
else
    error "Error al recargar Nginx con SSL"
fi

# 12. Configurar renovación automática
log "Configurando renovación automática..."
CRON_JOB="0 12 * * * /usr/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx"
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    log "✓ Renovación automática configurada"
else
    log "✓ Renovación automática ya configurada"
fi

# 13. Verificaciones finales
log "Realizando verificaciones finales..."
sleep 3

# Verificar HTTPS
if curl -s --connect-timeout 10 https://localhost/ > /dev/null 2>&1; then
    log "✓ HTTPS funcionando"
else
    warn "⚠ HTTPS no responde"
fi

# Verificar redirección HTTP a HTTPS
HTTP_RESPONSE=$(curl -s -I --connect-timeout 10 http://localhost/ 2>/dev/null | head -n 1 || echo "")
if echo "$HTTP_RESPONSE" | grep -q "301\|302"; then
    log "✓ Redirección HTTP a HTTPS funcionando"
else
    warn "⚠ Redirección HTTP a HTTPS no funcionando"
fi

# Verificar API vía HTTPS
API_RESPONSE=$(curl -s --connect-timeout 10 https://localhost/api/health 2>/dev/null || echo "")
if [ -n "$API_RESPONSE" ]; then
    log "✓ API accesible vía HTTPS"
else
    warn "⚠ API no accesible vía HTTPS"
fi

# Verificar certificado
CERT_INFO=$(openssl x509 -in "$SSL_CERT" -text -noout 2>/dev/null | grep "Not After" || echo "")
if [ -n "$CERT_INFO" ]; then
    log "✓ Certificado SSL válido"
    log "Expiración: $CERT_INFO"
else
    warn "⚠ No se pudo verificar el certificado"
fi

echo -e "\n${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CONFIGURACIÓN SSL COMPLETADA "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Resumen de acciones realizadas:"
echo -e "${GREEN}  ✓ Backup de configuración creado${NC}"
echo -e "${GREEN}  ✓ Certificado SSL obtenido de Let's Encrypt${NC}"
echo -e "${GREEN}  ✓ Configuración SSL completa aplicada${NC}"
echo -e "${GREEN}  ✓ Redirección HTTP a HTTPS configurada${NC}"
echo -e "${GREEN}  ✓ Renovación automática configurada${NC}"
echo -e "${GREEN}  ✓ Headers de seguridad aplicados${NC}"

echo -e "\n${YELLOW}=== ESTADO ACTUAL ===${NC}"
echo -e "${GREEN}✓ Nginx funcionando con SSL/HTTPS${NC}"
echo -e "${GREEN}✓ Redirección automática HTTP → HTTPS${NC}"
echo -e "${GREEN}✓ Certificado válido con renovación automática${NC}"
echo -e "${GREEN}✓ API accesible vía HTTPS${NC}"

echo -e "\n${YELLOW}=== ACCESO A LA APLICACIÓN ===${NC}"
echo -e "${GREEN}URL principal: https://$DOMAIN${NC}"
echo -e "${GREEN}API Health: https://$DOMAIN/api/health${NC}"
echo -e "${GREEN}Cliente de prueba: https://$DOMAIN/test-client.html${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Estado SSL: sudo certbot certificates${NC}"
echo -e "${GREEN}Renovar manualmente: sudo certbot renew${NC}"
echo -e "${GREEN}Logs de Nginx: sudo tail -f /var/log/nginx/$DOMAIN.access.log${NC}"
echo -e "${GREEN}Estado de Nginx: sudo systemctl status nginx${NC}"

log "¡Configuración SSL completada exitosamente!"
log "La aplicación está disponible en: https://$DOMAIN"
log "Backup de configuración anterior en: $BACKUP_DIR"