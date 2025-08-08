#!/bin/bash

# Script de Despliegue Automatizado para PDF Signer
# Autor: Sistema de Despliegue Automatizado
# Fecha: $(date)

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
PROJECT_DIR="/opt/pdf-signer/pdf"
SERVICE_NAME="pdf-signer"
WAR_NAME="pdf-signer-war-1.0-boot.war"
DEPLOY_DIR="/tmp"

echo -e "${BLUE}=== INICIANDO DESPLIEGUE AUTOMATIZADO ===${NC}"
echo -e "${YELLOW}Proyecto: $PROJECT_DIR${NC}"
echo -e "${YELLOW}Servicio: $SERVICE_NAME${NC}"
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

# Verificar que el directorio del proyecto existe
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "El directorio del proyecto no existe: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

# 1. Actualizar código desde Git
log_info "Actualizando código desde Git..."
git pull origin main || {
    log_error "Error al hacer git pull"
    exit 1
}

# 2. Otorgar permisos de ejecución a todos los scripts .sh
log_info "Otorgando permisos de ejecución a scripts .sh..."
find . -name "*.sh" -type f -exec chmod +x {} \;
log_info "Permisos otorgados a $(find . -name "*.sh" -type f | wc -l) archivos .sh"

# 3. Limpiar compilaciones anteriores
log_info "Limpiando compilaciones anteriores..."
mvn clean -q

# 4. Compilar proyecto
log_info "Compilando proyecto con Maven..."
mvn package -DskipTests -q || {
    log_error "Error en la compilación con Maven"
    exit 1
}

# 5. Verificar que el WAR se generó correctamente
if [ ! -f "target/$WAR_NAME" ]; then
    log_error "El archivo WAR no se generó: target/$WAR_NAME"
    exit 1
fi

log_info "WAR generado exitosamente: target/$WAR_NAME"

# 6. Detener servicio actual si está ejecutándose
log_info "Deteniendo servicio actual..."
systemctl stop $SERVICE_NAME 2>/dev/null || log_warn "El servicio no estaba ejecutándose"

# 7. Hacer backup del WAR anterior si existe
if [ -f "$DEPLOY_DIR/pdf-signer-boot-fixed.war" ]; then
    log_info "Creando backup del WAR anterior..."
    mv "$DEPLOY_DIR/pdf-signer-boot-fixed.war" "$DEPLOY_DIR/pdf-signer-boot-fixed.war.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 8. Copiar nuevo WAR al directorio de despliegue
log_info "Desplegando nuevo WAR..."
cp "target/$WAR_NAME" "$DEPLOY_DIR/pdf-signer-boot-fixed.war"
chown root:root "$DEPLOY_DIR/pdf-signer-boot-fixed.war"
chmod 755 "$DEPLOY_DIR/pdf-signer-boot-fixed.war"

# 9. Iniciar servicio
log_info "Iniciando servicio..."
systemctl start $SERVICE_NAME

# 10. Esperar a que el servicio inicie
log_info "Esperando a que el servicio inicie..."
sleep 10

# 11. Verificar estado del servicio
if systemctl is-active --quiet $SERVICE_NAME; then
    log_info "Servicio iniciado correctamente"
else
    log_error "Error: El servicio no se inició correctamente"
    systemctl status $SERVICE_NAME
    exit 1
fi

# 12. Verificar health check
log_info "Verificando health check..."
for i in {1..5}; do
    if curl -s http://localhost:8080/usiv-pdf-api/actuator/health | grep -q '"status":"UP"'; then
        log_info "Health check exitoso"
        break
    else
        log_warn "Intento $i/5: Health check falló, reintentando en 5 segundos..."
        sleep 5
    fi
    
    if [ $i -eq 5 ]; then
        log_error "Health check falló después de 5 intentos"
        exit 1
    fi
done

# 13. Verificar acceso público
log_info "Verificando acceso público..."
if curl -s -k https://validador.usiv.cl/pdf-signer/actuator/health | grep -q '"status":"UP"'; then
    log_info "Acceso público verificado exitosamente"
else
    log_warn "Advertencia: El acceso público podría tener problemas"
fi

# 14. Mostrar información del despliegue
echo ""
echo -e "${GREEN}=== DESPLIEGUE COMPLETADO EXITOSAMENTE ===${NC}"
echo -e "${BLUE}Información del despliegue:${NC}"
echo "  - Fecha: $(date)"
echo "  - WAR: $WAR_NAME"
echo "  - Ubicación: $DEPLOY_DIR/pdf-signer-boot-fixed.war"
echo "  - Servicio: $SERVICE_NAME ($(systemctl is-active $SERVICE_NAME))"
echo "  - Health Check: http://localhost:8080/usiv-pdf-api/actuator/health"
echo "  - URL Pública: https://validador.usiv.cl/pdf-signer/"
echo ""
echo -e "${YELLOW}Comandos útiles:${NC}"
echo "  - Ver logs: journalctl -u $SERVICE_NAME -f"
echo "  - Estado: systemctl status $SERVICE_NAME"
echo "  - Reiniciar: systemctl restart $SERVICE_NAME"
echo ""

log_info "¡Despliegue completado exitosamente!"