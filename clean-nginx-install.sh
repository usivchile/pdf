#!/bin/bash

# Script para limpiar instalaciones previas de Nginx y hacer una instalación limpia
# Autor: Asistente AI
# Fecha: $(date)

set -e

echo "=== LIMPIEZA E INSTALACIÓN LIMPIA DE NGINX ==="
echo "Fecha: $(date)"
echo

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para verificar si el usuario es root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

# Función para detener Nginx
stop_nginx() {
    log "Deteniendo Nginx..."
    
    # Detener servicio
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    
    # Matar procesos que puedan estar ejecutándose
    pkill -f nginx 2>/dev/null || true
    
    # Esperar un momento
    sleep 2
    
    # Verificar que no hay procesos de Nginx
    if pgrep -f nginx > /dev/null; then
        log "Forzando terminación de procesos Nginx..."
        pkill -9 -f nginx 2>/dev/null || true
    fi
    
    log "Nginx detenido"
}

# Función para hacer backup de configuraciones importantes
backup_configs() {
    log "Creando backup de configuraciones..."
    
    BACKUP_DIR="/root/nginx-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup de configuraciones si existen
    if [[ -d "/etc/nginx" ]]; then
        cp -r /etc/nginx "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    if [[ -d "/var/www" ]]; then
        cp -r /var/www "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    # Backup de certificados SSL si existen
    if [[ -d "/etc/letsencrypt" ]]; then
        cp -r /etc/letsencrypt "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    log "Backup creado en: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /tmp/nginx-backup-location
}

# Función para eliminar instalaciones de Nginx
remove_nginx() {
    log "Eliminando instalaciones previas de Nginx..."
    
    # Detener y deshabilitar servicio
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    
    # Eliminar paquetes de Nginx
    apt remove --purge -y nginx nginx-common nginx-core nginx-full 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
    
    # Eliminar directorios de configuración
    rm -rf /etc/nginx
    rm -rf /var/log/nginx
    rm -rf /var/cache/nginx
    rm -rf /usr/share/nginx
    
    # Eliminar archivos de servicio personalizados
    rm -f /etc/systemd/system/nginx.service
    rm -f /lib/systemd/system/nginx.service
    
    # Recargar systemd
    systemctl daemon-reload
    
    log "Instalaciones previas de Nginx eliminadas"
}

# Función para instalar Nginx limpio
install_clean_nginx() {
    log "Instalando Nginx limpio..."
    
    # Actualizar repositorios
    apt update
    
    # Instalar Nginx
    apt install -y nginx
    
    # Verificar instalación
    if ! command -v nginx &> /dev/null; then
        log "ERROR: Nginx no se instaló correctamente"
        return 1
    fi
    
    log "Nginx instalado correctamente"
}

# Función para configurar Nginx básico
configure_basic_nginx() {
    log "Configurando Nginx básico..."
    
    # Eliminar configuración por defecto
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/default
    
    # Limpiar conf.d
    rm -f /etc/nginx/conf.d/*
    
    # Crear configuración básica para validador.usiv.cl
    cat > /etc/nginx/conf.d/validador.usiv.cl.conf << 'EOF'
server {
    listen 80;
    server_name validador.usiv.cl;
    
    # Logs
    access_log /var/log/nginx/validador.usiv.cl.access.log;
    error_log /var/log/nginx/validador.usiv.cl.error.log;
    
    # Configuración de proxy
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
    }
    
    # Directorio para validación de Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files $uri =404;
    }
    
    # Security headers básicos
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
    
    # Crear directorio para Let's Encrypt
    mkdir -p /var/www/html/.well-known/acme-challenge
    chown -R www-data:www-data /var/www/html
    
    log "Configuración básica creada"
}

# Función para verificar configuración
verify_nginx_config() {
    log "Verificando configuración de Nginx..."
    
    if nginx -t; then
        log "✓ Configuración de Nginx válida"
    else
        log "✗ ERROR: Configuración de Nginx inválida"
        return 1
    fi
}

# Función para iniciar y verificar Nginx
start_and_verify_nginx() {
    log "Iniciando Nginx..."
    
    # Habilitar e iniciar servicio
    systemctl enable nginx
    systemctl start nginx
    
    # Verificar estado
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx iniciado correctamente"
    else
        log "✗ ERROR: Nginx no se inició correctamente"
        systemctl status nginx
        return 1
    fi
    
    # Verificar puerto 80
    sleep 2
    if netstat -tlnp | grep -q ":80.*nginx"; then
        log "✓ Nginx escuchando en puerto 80"
    else
        log "✗ ERROR: Nginx no está escuchando en puerto 80"
        return 1
    fi
    
    # Verificar conectividad
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200\|502\|404"; then
        log "✓ Nginx responde correctamente"
    else
        log "✗ WARNING: Nginx no responde como se esperaba"
    fi
}

# Función principal
main() {
    log "Iniciando limpieza e instalación de Nginx..."
    
    check_root
    
    backup_configs
    stop_nginx
    remove_nginx
    install_clean_nginx
    configure_basic_nginx
    verify_nginx_config
    start_and_verify_nginx
    
    BACKUP_LOCATION=$(cat /tmp/nginx-backup-location 2>/dev/null || echo "No disponible")
    
    log "=== INSTALACIÓN DE NGINX COMPLETADA ==="
    echo
    echo "RESUMEN:"
    echo "- Nginx instalado limpio"
    echo "- Configuración básica para validador.usiv.cl"
    echo "- Proxy a Tomcat en puerto 8080"
    echo "- Preparado para SSL con Let's Encrypt"
    echo "- Backup anterior en: $BACKUP_LOCATION"
    echo
    echo "VERIFICACIONES:"
    echo "- Estado: systemctl status nginx"
    echo "- Configuración: nginx -t"
    echo "- Puerto: netstat -tlnp | grep :80"
    echo "- Logs: tail -f /var/log/nginx/error.log"
    echo "- Acceso: curl http://validador.usiv.cl"
    echo
    echo "SIGUIENTE PASO:"
    echo "1. Verificar que Tomcat esté en puerto 8080"
    echo "2. Probar: curl http://validador.usiv.cl"
    echo "3. Para SSL: sudo ./setup-ssl-step-by-step.sh"
}

# Ejecutar función principal
main "$@"