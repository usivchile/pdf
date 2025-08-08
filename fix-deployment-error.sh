#!/bin/bash

# Script para verificar y corregir errores de despliegue
# Autor: Sistema de Despliegue PDF Validator
# Fecha: $(date)

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           VERIFICADOR Y CORRECTOR DE ERRORES DE DESPLIEGUE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"

# Verificar si somos root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

log_info "Verificando y corrigiendo problemas comunes de despliegue..."

# 1. Verificar y crear directorio /var/www/html
log_info "Verificando directorio /var/www/html..."
if [ ! -d "/var/www/html" ]; then
    log_warn "Directorio /var/www/html no existe. Creándolo..."
    mkdir -p "/var/www/html"
    chown nginx:nginx "/var/www/html" 2>/dev/null || chown apache:apache "/var/www/html" 2>/dev/null || true
    chmod 755 "/var/www/html"
    log_success "Directorio /var/www/html creado exitosamente"
else
    log_success "Directorio /var/www/html existe"
fi

# 2. Verificar permisos del directorio
log_info "Verificando permisos de /var/www/html..."
PERMS=$(stat -c "%a" "/var/www/html" 2>/dev/null || echo "unknown")
if [ "$PERMS" != "755" ] && [ "$PERMS" != "unknown" ]; then
    log_warn "Permisos incorrectos en /var/www/html ($PERMS). Corrigiendo..."
    chmod 755 "/var/www/html"
    log_success "Permisos corregidos a 755"
else
    log_success "Permisos de /var/www/html son correctos"
fi

# 3. Verificar directorio webapps de Tomcat
log_info "Verificando directorio webapps de Tomcat..."
WEBAPPS_DIR="/opt/tomcat/webapps"
if [ ! -d "$WEBAPPS_DIR" ]; then
    log_error "Directorio $WEBAPPS_DIR no existe. Verifica la instalación de Tomcat."
else
    log_success "Directorio webapps de Tomcat existe"
    
    # Verificar permisos
    OWNER=$(ls -ld "$WEBAPPS_DIR" | awk '{print $3}')
    if [ "$OWNER" != "tomcat" ]; then
        log_warn "Propietario incorrecto de $WEBAPPS_DIR ($OWNER). Corrigiendo..."
        chown -R tomcat:tomcat "$WEBAPPS_DIR"
        log_success "Propietario corregido a tomcat:tomcat"
    else
        log_success "Propietario de webapps es correcto (tomcat)"
    fi
fi

# 4. Verificar que test-client.html existe en el proyecto
log_info "Verificando archivo test-client.html..."
if [ -f "test-client.html" ]; then
    log_success "Archivo test-client.html encontrado en el directorio actual"
    
    # Copiar a /var/www/html si no existe
    if [ ! -f "/var/www/html/test-client.html" ]; then
        log_info "Copiando test-client.html a /var/www/html..."
        cp "test-client.html" "/var/www/html/"
        chmod 644 "/var/www/html/test-client.html"
        log_success "test-client.html copiado exitosamente"
    else
        log_success "test-client.html ya existe en /var/www/html"
    fi
else
    log_warn "Archivo test-client.html no encontrado en el directorio actual"
fi

# 5. Verificar estado de servicios
log_info "Verificando estado de servicios..."

# Tomcat
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat está ejecutándose"
else
    log_warn "Tomcat no está ejecutándose"
    log_info "Para iniciar Tomcat: systemctl start tomcat"
fi

# Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ejecutándose"
else
    log_warn "Nginx no está ejecutándose"
    log_info "Para iniciar Nginx: systemctl start nginx"
fi

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           VERIFICACIÓN Y CORRECCIÓN COMPLETADA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"

log_info "Resumen de acciones realizadas:"
echo -e "${YELLOW}  ✓ Verificación y creación de /var/www/html${NC}"
echo -e "${YELLOW}  ✓ Corrección de permisos${NC}"
echo -e "${YELLOW}  ✓ Verificación de directorios de Tomcat${NC}"
echo -e "${YELLOW}  ✓ Verificación de servicios${NC}"

echo -e "\n${GREEN}Ahora puedes ejecutar nuevamente el script de actualización:${NC}"
echo -e "${BLUE}  sudo ./update-local.sh${NC}"

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"