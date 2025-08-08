#!/bin/bash

# Script para corregir problemas de SSL en Nginx
# Genera certificados autofirmados temporales y configura Nginx

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
SSL_DIR="/etc/nginx/ssl"
NGINX_CONF="/etc/nginx/conf.d/$DOMAIN.conf"

echo -e "${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CORRECTOR DE PROBLEMAS SSL DE NGINX "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Iniciando corrección de problemas SSL..."

# 1. Crear directorio SSL si no existe
log "Creando directorio SSL..."
mkdir -p "$SSL_DIR"
chmod 755 "$SSL_DIR"

# 2. Generar certificados autofirmados temporales
log "Generando certificados autofirmados temporales..."
if [ ! -f "$SSL_DIR/nginx-selfsigned.crt" ] || [ ! -f "$SSL_DIR/nginx-selfsigned.key" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/nginx-selfsigned.key" \
        -out "$SSL_DIR/nginx-selfsigned.crt" \
        -subj "/C=CL/ST=Santiago/L=Santiago/O=USIV/OU=IT/CN=$DOMAIN"
    
    chmod 600 "$SSL_DIR/nginx-selfsigned.key"
    chmod 644 "$SSL_DIR/nginx-selfsigned.crt"
    log "Certificados autofirmados creados"
else
    log "Certificados autofirmados ya existen"
fi

# 3. Crear configuración de Nginx temporal (sin SSL)
log "Creando configuración temporal de Nginx..."
cat > "$NGINX_CONF" << 'EOF'
# Configuración temporal de Nginx para PDF Validator API
# Redirección HTTP a HTTPS deshabilitada temporalmente

server {
    listen 80;
    server_name validador.usiv.cl www.validador.usiv.cl;
    
    # Logs
    access_log /var/log/nginx/validador.usiv.cl.access.log;
    error_log /var/log/nginx/validador.usiv.cl.error.log;
    
    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    limit_req zone=general burst=50 nodelay;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Proxy to Tomcat
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
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
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
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
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

log "Configuración temporal creada"

# 4. Verificar configuración de Nginx
log "Verificando configuración de Nginx..."
if nginx -t; then
    log "Configuración de Nginx válida"
else
    error "Configuración de Nginx inválida"
fi

# 5. Reiniciar Nginx
log "Reiniciando Nginx..."
systemctl restart nginx

if systemctl is-active --quiet nginx; then
    log "Nginx reiniciado correctamente"
else
    error "Error al reiniciar Nginx"
fi

# 6. Verificar que Nginx esté escuchando
log "Verificando puertos..."
if netstat -tlnp | grep -q ":80.*nginx"; then
    log "✓ Nginx escuchando en puerto 80"
else
    warn "⚠ Nginx no está escuchando en puerto 80"
fi

# 7. Probar conectividad
log "Probando conectividad..."
if curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
    log "✓ Conexión HTTP funcionando"
else
    warn "⚠ Conexión HTTP no responde"
fi

# 8. Verificar proxy a Tomcat
log "Verificando proxy a Tomcat..."
if netstat -tlnp | grep -q ":8080.*java"; then
    log "✓ Tomcat escuchando en puerto 8080"
    
    # Probar endpoint de API
    API_RESPONSE=$(curl -s --connect-timeout 10 http://localhost/api/health 2>/dev/null || echo "")
    if [ -n "$API_RESPONSE" ]; then
        log "✓ Endpoint de API accesible vía HTTP"
    else
        warn "⚠ Endpoint de API no accesible"
    fi
else
    warn "⚠ Tomcat no está escuchando en puerto 8080"
fi

echo -e "\n${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CORRECCIÓN COMPLETADA "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Resumen de acciones realizadas:"
echo -e "${GREEN}  ✓ Directorio SSL creado: $SSL_DIR${NC}"
echo -e "${GREEN}  ✓ Certificados autofirmados generados${NC}"
echo -e "${GREEN}  ✓ Configuración temporal de Nginx creada${NC}"
echo -e "${GREEN}  ✓ Nginx reiniciado y funcionando${NC}"

echo -e "\n${YELLOW}=== ESTADO ACTUAL ===${NC}"
echo -e "${GREEN}✓ Nginx funcionando en HTTP (puerto 80)${NC}"
echo -e "${GREEN}✓ Proxy reverso a Tomcat configurado${NC}"
echo -e "${YELLOW}⚠ SSL deshabilitado temporalmente${NC}"

echo -e "\n${YELLOW}=== PRÓXIMOS PASOS ===${NC}"
echo -e "${GREEN}1. Verificar aplicación: http://$DOMAIN${NC}"
echo -e "${GREEN}2. Para habilitar SSL: sudo certbot --nginx -d $DOMAIN${NC}"
echo -e "${GREEN}3. Verificar logs: sudo tail -f /var/log/nginx/$DOMAIN.access.log${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Estado de Nginx: sudo systemctl status nginx${NC}"
echo -e "${GREEN}Logs de error: sudo tail -f /var/log/nginx/$DOMAIN.error.log${NC}"
echo -e "${GREEN}Probar configuración: sudo nginx -t${NC}"

log "Nginx configurado correctamente para funcionar sin SSL"
log "La aplicación debería estar accesible en: http://$DOMAIN"