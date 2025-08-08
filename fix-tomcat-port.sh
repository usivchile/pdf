#!/bin/bash

# Script integrado para limpiar Tomcat y configurar puerto 8080
# Autor: Asistente AI
# Fecha: $(date)

set -e

echo "=== LIMPIEZA Y CONFIGURACIÓN DE TOMCAT ==="
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

# Preguntar al usuario si quiere hacer limpieza completa
ask_clean_install() {
    echo "OPCIONES DISPONIBLES:"
    echo "1. Limpieza completa + instalación nueva (RECOMENDADO)"
    echo "2. Solo cambiar puerto en instalación actual"
    echo
    read -p "Selecciona una opción (1 o 2): " choice
    
    case $choice in
        1)
            log "Ejecutando limpieza completa..."
            return 0
            ;;
        2)
            log "Solo cambiando puerto..."
            return 1
            ;;
        *)
            log "Opción inválida. Ejecutando limpieza completa por defecto."
            return 0
            ;;
    esac
}

main() {
    check_root
    
    if ask_clean_install; then
        # Ejecutar limpieza completa
        if [[ -f "./clean-tomcat-install.sh" ]]; then
            log "Ejecutando limpieza completa de Tomcat..."
            chmod +x ./clean-tomcat-install.sh
            ./clean-tomcat-install.sh
            log "Limpieza e instalación completada"
        else
            log "ERROR: No se encuentra clean-tomcat-install.sh"
            log "Ejecutando solo cambio de puerto..."
            change_port_only
        fi
    else
        # Solo cambiar puerto
        change_port_only
    fi
}

# Función para cambiar solo el puerto (código original)
change_port_only() {

# Script para corregir el puerto de Tomcat de 8081 a 8080
# PDF Validator API - Corrección de Puerto

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
TOMCAT_HOME="/opt/tomcat"
SERVER_XML="$TOMCAT_HOME/conf/server.xml"
BACKUP_DIR="/root/tomcat-backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CORRECTOR DE PUERTO DE TOMCAT "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Iniciando corrección del puerto de Tomcat..."

# 1. Verificar que Tomcat esté instalado
log "Verificando instalación de Tomcat..."
if [ ! -d "$TOMCAT_HOME" ]; then
    error "Directorio de Tomcat no encontrado: $TOMCAT_HOME"
fi

if [ ! -f "$SERVER_XML" ]; then
    error "Archivo server.xml no encontrado: $SERVER_XML"
fi

log "✓ Tomcat encontrado en $TOMCAT_HOME"

# 2. Crear backup
log "Creando backup de configuración..."
mkdir -p "$BACKUP_DIR"
cp -r "$TOMCAT_HOME/conf" "$BACKUP_DIR/"
log "Backup creado en: $BACKUP_DIR"

# 3. Verificar puerto actual
log "Verificando configuración actual..."
CURRENT_PORT=$(grep -o 'port="[0-9]*"' "$SERVER_XML" | grep -E 'port="80[0-9][0-9]"' | head -1 | grep -o '[0-9]*' || echo "")
if [ -n "$CURRENT_PORT" ]; then
    log "Puerto actual encontrado: $CURRENT_PORT"
else
    warn "No se pudo determinar el puerto actual"
fi

# 4. Detener Tomcat
log "Deteniendo Tomcat..."
systemctl stop tomcat || true
sleep 3

# Verificar que se detuvo
if pgrep -f "catalina" > /dev/null; then
    warn "Tomcat aún ejecutándose, forzando detención..."
    pkill -f "catalina" || true
    sleep 2
fi

log "✓ Tomcat detenido"

# 5. Modificar server.xml
log "Modificando configuración del puerto..."

# Backup del archivo original
cp "$SERVER_XML" "$SERVER_XML.backup-$(date +%Y%m%d-%H%M%S)"

# Cambiar puerto 8081 a 8080
sed -i 's/port="8081"/port="8080"/g' "$SERVER_XML"

# Verificar que el cambio se aplicó
if grep -q 'port="8080"' "$SERVER_XML"; then
    log "✓ Puerto cambiado a 8080 en server.xml"
else
    error "Error al cambiar el puerto en server.xml"
fi

# 6. Verificar configuración
log "Verificando configuración modificada..."
log "Puertos configurados en server.xml:"
grep -n 'port="[0-9]*"' "$SERVER_XML" | while read line; do
    echo -e "${YELLOW}  $line${NC}"
done

# 7. Iniciar Tomcat
log "Iniciando Tomcat con nueva configuración..."
systemctl start tomcat

# Esperar a que inicie
log "Esperando a que Tomcat inicie..."
sleep 10

# 8. Verificar que Tomcat esté ejecutándose
log "Verificando estado de Tomcat..."
if systemctl is-active --quiet tomcat; then
    log "✓ Tomcat iniciado correctamente"
else
    error "Error al iniciar Tomcat"
fi

# 9. Verificar puerto 8080
log "Verificando que Tomcat esté escuchando en puerto 8080..."
sleep 5

if netstat -tlnp | grep -q ":8080.*java"; then
    log "✓ Tomcat escuchando en puerto 8080"
else
    warn "⚠ Tomcat no está escuchando en puerto 8080 aún"
    log "Esperando 10 segundos más..."
    sleep 10
    
    if netstat -tlnp | grep -q ":8080.*java"; then
        log "✓ Tomcat ahora escuchando en puerto 8080"
    else
        error "Tomcat no está escuchando en puerto 8080"
    fi
fi

# 10. Probar conectividad
log "Probando conectividad local..."
if curl -s --connect-timeout 10 http://localhost:8080/ > /dev/null 2>&1; then
    log "✓ Tomcat responde en puerto 8080"
else
    warn "⚠ Tomcat no responde en puerto 8080 aún"
    log "Esto puede ser normal si la aplicación aún se está desplegando"
fi

# 11. Verificar aplicación
log "Verificando despliegue de aplicación..."
APP_DIR="$TOMCAT_HOME/webapps/pdf-signer-war-1.0"
if [ -d "$APP_DIR" ]; then
    log "✓ Aplicación encontrada en $APP_DIR"
    
    # Probar endpoint de la aplicación
    sleep 5
    API_RESPONSE=$(curl -s --connect-timeout 10 http://localhost:8080/pdf-signer-war-1.0/api/health 2>/dev/null || echo "")
    if [ -n "$API_RESPONSE" ]; then
        log "✓ API responde correctamente"
    else
        warn "⚠ API no responde aún (puede estar iniciando)"
    fi
else
    warn "⚠ Aplicación no encontrada en $APP_DIR"
fi

echo -e "\n${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            CORRECCIÓN COMPLETADA "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

log "Resumen de acciones realizadas:"
echo -e "${GREEN}  ✓ Backup de configuración creado${NC}"
echo -e "${GREEN}  ✓ Puerto cambiado de 8081 a 8080${NC}"
echo -e "${GREEN}  ✓ Tomcat reiniciado${NC}"
echo -e "${GREEN}  ✓ Tomcat escuchando en puerto 8080${NC}"

echo -e "\n${YELLOW}=== ESTADO ACTUAL ===${NC}"
echo -e "${GREEN}✓ Tomcat ejecutándose en puerto 8080${NC}"
echo -e "${GREEN}✓ Configuración corregida${NC}"
echo -e "${GREEN}✓ Backup disponible en: $BACKUP_DIR${NC}"

echo -e "\n${YELLOW}=== PRÓXIMOS PASOS ===${NC}"
echo -e "${GREEN}1. Verificar aplicación: curl http://localhost:8080/${NC}"
echo -e "${GREEN}2. Probar API: curl http://localhost:8080/pdf-signer-war-1.0/api/health${NC}"
echo -e "${GREEN}3. Verificar Nginx: curl http://validador.usiv.cl${NC}"
echo -e "${GREEN}4. Ejecutar verificación: sudo ./check-deployment.sh${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Estado de Tomcat: sudo systemctl status tomcat${NC}"
echo -e "${GREEN}Logs de Tomcat: sudo tail -f $TOMCAT_HOME/logs/catalina.out${NC}"
echo -e "${GREEN}Puertos en uso: sudo netstat -tlnp | grep java${NC}"
echo -e "${GREEN}Procesos Java: sudo ps aux | grep java${NC}"

log "Puerto de Tomcat corregido exitosamente"
log "Tomcat ahora debería estar disponible en puerto 8080"
log "Backup de configuración anterior en: $BACKUP_DIR"
}

# Ejecutar función principal
main "$@"