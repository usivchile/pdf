#!/bin/bash

# Script de Limpieza del Servidor de Producción
# Elimina archivos innecesarios y organiza el entorno

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
PROJECT_DIR="/opt/pdf-signer/pdf"
TMP_DIR="/tmp"
TOMCAT_DIR="/var/lib/tomcat"

echo -e "${BLUE}=== LIMPIEZA DEL SERVIDOR DE PRODUCCIÓN ===${NC}"
echo ""

# Función para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que estamos ejecutando como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root"
    exit 1
fi

# 1. Detener servicios innecesarios
log_info "Deteniendo Tomcat (ya no lo usamos)..."
systemctl stop tomcat 2>/dev/null || log_warn "Tomcat no estaba ejecutándose"
systemctl disable tomcat 2>/dev/null || log_warn "Tomcat no estaba habilitado"

# 2. Limpiar archivos de Tomcat
log_info "Limpiando archivos de Tomcat..."
if [ -d "$TOMCAT_DIR/webapps" ]; then
    rm -rf "$TOMCAT_DIR/webapps/pdf-signer"* 2>/dev/null || true
    log_info "Archivos de Tomcat eliminados"
fi

# 3. Limpiar archivos temporales antiguos
log_info "Limpiando archivos temporales antiguos..."
find "$TMP_DIR" -name "*pdf-signer*" -type f -mtime +7 -delete 2>/dev/null || true
find "$TMP_DIR" -name "*.war.backup.*" -type f -mtime +30 -delete 2>/dev/null || true

# 4. Limpiar logs antiguos
log_info "Limpiando logs antiguos..."
find /var/log -name "*pdf-signer*" -type f -mtime +30 -delete 2>/dev/null || true
journalctl --vacuum-time=30d 2>/dev/null || true

# 5. Verificar y crear estructura de directorios necesaria
log_info "Verificando estructura de directorios..."
if [ ! -d "$PROJECT_DIR" ]; then
    log_warn "Creando directorio del proyecto: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    chown root:root "$PROJECT_DIR"
fi

# 6. Limpiar archivos de compilación en el proyecto
if [ -d "$PROJECT_DIR" ]; then
    log_info "Limpiando archivos de compilación..."
    cd "$PROJECT_DIR"
    
    # Limpiar target si existe
    if [ -d "target" ]; then
        rm -rf target/*
        log_info "Directorio target limpiado"
    fi
    
    # Limpiar archivos temporales
    find . -name "*.tmp" -delete 2>/dev/null || true
    find . -name "*.log" -delete 2>/dev/null || true
    find . -name ".DS_Store" -delete 2>/dev/null || true
    
    # Limpiar archivos de IDE
    rm -rf .idea/ .vscode/ *.iml 2>/dev/null || true
fi

# 7. Verificar servicios necesarios
log_info "Verificando servicios necesarios..."

# Verificar que nginx esté ejecutándose
if ! systemctl is-active --quiet nginx; then
    log_warn "Nginx no está ejecutándose, iniciando..."
    systemctl start nginx
fi

# Verificar que pdf-signer esté habilitado
if ! systemctl is-enabled --quiet pdf-signer; then
    log_warn "Servicio pdf-signer no está habilitado, habilitando..."
    systemctl enable pdf-signer
fi

# 8. Mostrar espacio en disco
log_info "Espacio en disco después de la limpieza:"
df -h / | tail -1

# 9. Mostrar archivos importantes
echo ""
log_info "Archivos importantes en el sistema:"
echo "  - Proyecto: $PROJECT_DIR"
echo "  - WAR actual: $TMP_DIR/pdf-signer-boot-fixed.war"
echo "  - Servicio: /etc/systemd/system/pdf-signer.service"
echo "  - Nginx config: /etc/nginx/conf.d/pdf-signer.conf"
echo "  - SSL certs: /etc/letsencrypt/live/validador.usiv.cl/"

# 10. Verificar estado de servicios
echo ""
log_info "Estado de servicios:"
echo "  - nginx: $(systemctl is-active nginx)"
echo "  - pdf-signer: $(systemctl is-active pdf-signer)"
echo "  - tomcat: $(systemctl is-active tomcat 2>/dev/null || echo 'disabled')"

# 11. Mostrar procesos Java
echo ""
log_info "Procesos Java ejecutándose:"
ps aux | grep java | grep -v grep || echo "  Ningún proceso Java encontrado"

echo ""
echo -e "${GREEN}=== LIMPIEZA COMPLETADA ===${NC}"
log_info "El servidor está limpio y listo para el despliegue"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo "  1. cd $PROJECT_DIR"
echo "  2. git pull"
echo "  3. ./deploy-production.sh"
echo ""