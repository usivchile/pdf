#!/bin/bash

# Script para corregir problemas de SSL en Nginx
# Configuración simple sin rate limiting para evitar conflictos

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
NGINX_CONF="/etc/nginx/conf.d/$DOMAIN.conf"

echo -e "${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CORRECTOR DE PROBLEMAS SSL DE NGINX "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Iniciando corrección de problemas SSL..."

# 1. Detener Nginx para limpiar configuración
log "Deteniendo Nginx..."
systemctl stop nginx || true

# 2. Limpiar configuraciones conflictivas
log "Limpiando configuraciones conflictivas..."
rm -f /etc/nginx/conf.d/*.conf
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# 3. Crear configuración simple sin SSL
log "Creando configuración simple sin SSL..."
cat > "$NGINX_CONF" << 'EOF'
# Configuración simple de Nginx para PDF Validator API
# Sin SSL, sin rate limiting para evitar conflictos

server {
    listen 80;
    server_name validador.usiv.cl www.validador.usiv.cl;
    
    # Logs
    access_log /var/log/nginx/validador.usiv.cl.access.log;
    error_log /var/log/nginx/validador.usiv.cl.error.log;
    
    # Headers básicos de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
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
    
    # API endpoints
    location /api/ {
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
}
EOF

log "Configuración simple creada"

# 4. Crear directorio para Let's Encrypt
log "Preparando directorio para validación..."
mkdir -p /var/www/html/.well-known/acme-challenge
chown -R nginx:nginx /var/www/html 2>/dev/null || chown -R www-data:www-data /var/www/html 2>/dev/null || true
chmod -R 755 /var/www/html

# 5. Verificar configuración de Nginx
log "Verificando configuración de Nginx..."
if nginx -t; then
    log "Configuración de Nginx válida"
else
    error "Configuración de Nginx inválida"
fi

# 6. Iniciar Nginx
log "Iniciando Nginx..."
systemctl start nginx

if systemctl is-active --quiet nginx; then
    log "Nginx iniciado correctamente"
else
    error "Error al iniciar Nginx"
fi

# 7. Verificar que Nginx esté escuchando
log "Verificando puertos..."
sleep 2
if netstat -tlnp | grep -q ":80.*nginx"; then
    log "✓ Nginx escuchando en puerto 80"
else
    warn "⚠ Nginx no está escuchando en puerto 80"
fi

# 8. Probar conectividad
log "Probando conectividad..."
if curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
    log "✓ Conexión HTTP funcionando"
else
    warn "⚠ Conexión HTTP no responde"
fi

# 9. Verificar proxy a Tomcat
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
echo -e "${GREEN}  ✓ Configuraciones conflictivas eliminadas${NC}"
echo -e "${GREEN}  ✓ Configuración simple de Nginx creada${NC}"
echo -e "${GREEN}  ✓ Nginx reiniciado y funcionando${NC}"
echo -e "${GREEN}  ✓ Directorio para Let's Encrypt preparado${NC}"

echo -e "\n${YELLOW}=== ESTADO ACTUAL ===${NC}"
echo -e "${GREEN}✓ Nginx funcionando en HTTP (puerto 80)${NC}"
echo -e "${GREEN}✓ Proxy reverso a Tomcat configurado${NC}"
echo -e "${YELLOW}⚠ SSL no configurado (usar setup-ssl-step-by-step.sh)${NC}"

echo -e "\n${YELLOW}=== PRÓXIMOS PASOS ===${NC}"
echo -e "${GREEN}1. Verificar aplicación: http://$DOMAIN${NC}"
echo -e "${GREEN}2. Para configurar SSL: sudo ./setup-ssl-step-by-step.sh${NC}"
echo -e "${GREEN}3. Verificar logs: sudo tail -f /var/log/nginx/$DOMAIN.access.log${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Estado de Nginx: sudo systemctl status nginx${NC}"
echo -e "${GREEN}Logs de error: sudo tail -f /var/log/nginx/$DOMAIN.error.log${NC}"
echo -e "${GREEN}Probar configuración: sudo nginx -t${NC}"

log "Nginx configurado correctamente para funcionar sin SSL"
log "La aplicación debería estar accesible en: http://$DOMAIN"
log "Para configurar SSL, ejecuta: sudo ./setup-ssl-step-by-step.sh"