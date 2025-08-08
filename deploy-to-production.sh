#!/bin/bash

# =============================================================================
# SCRIPT DE DESPLIEGUE A PRODUCCIÓN - USIV PDF SERVICE
# =============================================================================

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
PROJECT_NAME="usiv-pdf-service"
WAR_NAME="pdf-signer-war-1.0.war"
VPS_USER="root"
VPS_HOST="validador.usiv.cl"
TOMCAT_WEBAPPS="/var/lib/tomcat/webapps"
TOMCAT_SERVICE="tomcat"
BACKUP_DIR="/opt/usiv/backups"
LOG_DIR="/opt/usiv/logs"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}           DESPLIEGUE A PRODUCCIÓN - USIV PDF SERVICE${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  --build-only    Solo construir el WAR localmente"
    echo "  --deploy-only   Solo desplegar (asume que el WAR ya existe)"
    echo "  --full          Construcción completa y despliegue (por defecto)"
    echo "  --help          Mostrar esta ayuda"
    echo ""
}

# Función para construir el proyecto
build_project() {
    echo -e "${YELLOW}📦 Construyendo el proyecto...${NC}"
    
    # Limpiar y construir
    echo "Limpiando proyecto anterior..."
    mvn clean
    
    echo "Construyendo WAR para producción..."
    mvn package -Pprod -DskipTests
    
    # Verificar que el WAR se creó correctamente
    if [ ! -f "target/$WAR_NAME" ]; then
        echo -e "${RED}❌ Error: No se pudo generar el archivo WAR${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ WAR generado exitosamente: target/$WAR_NAME${NC}"
}

# Función para desplegar en el VPS
deploy_to_vps() {
    echo -e "${YELLOW}🚀 Desplegando en el VPS...${NC}"
    
    # Verificar que el WAR existe
    if [ ! -f "target/$WAR_NAME" ]; then
        echo -e "${RED}❌ Error: No se encontró el archivo WAR. Ejecuta primero la construcción.${NC}"
        exit 1
    fi
    
    # Crear backup del WAR actual si existe
    echo "Creando backup del despliegue anterior..."
    ssh $VPS_USER@$VPS_HOST "mkdir -p $BACKUP_DIR && \
        if [ -f $TOMCAT_WEBAPPS/pdf-signer.war ]; then \
            cp $TOMCAT_WEBAPPS/pdf-signer.war $BACKUP_DIR/pdf-signer-\$(date +%Y%m%d_%H%M%S).war; \
        fi"
    
    # Detener Tomcat
    echo "Deteniendo Tomcat..."
    ssh $VPS_USER@$VPS_HOST "systemctl stop $TOMCAT_SERVICE"
    
    # Limpiar despliegue anterior
    echo "Limpiando despliegue anterior..."
    ssh $VPS_USER@$VPS_HOST "rm -rf $TOMCAT_WEBAPPS/pdf-signer $TOMCAT_WEBAPPS/pdf-signer.war"
    
    # Copiar nuevo WAR
    echo "Copiando nuevo WAR al servidor..."
    scp target/$WAR_NAME $VPS_USER@$VPS_HOST:$TOMCAT_WEBAPPS/pdf-signer.war
    
    # Crear directorios necesarios
    echo "Creando directorios necesarios..."
    ssh $VPS_USER@$VPS_HOST "mkdir -p /opt/usiv/storage/pdfs /opt/usiv/storage/temp /opt/usiv/certs $LOG_DIR"
    
    # Establecer permisos
    echo "Estableciendo permisos..."
    ssh $VPS_USER@$VPS_HOST "chown -R tomcat:tomcat /opt/usiv $TOMCAT_WEBAPPS/pdf-signer.war"
    
    # Iniciar Tomcat
    echo "Iniciando Tomcat..."
    ssh $VPS_USER@$VPS_HOST "systemctl start $TOMCAT_SERVICE"
    
    # Esperar a que Tomcat inicie
    echo "Esperando a que Tomcat inicie completamente..."
    sleep 30
    
    # Verificar el estado del servicio
    echo "Verificando estado del servicio..."
    ssh $VPS_USER@$VPS_HOST "systemctl status $TOMCAT_SERVICE --no-pager"
    
    echo -e "${GREEN}✅ Despliegue completado exitosamente${NC}"
    echo -e "${BLUE}🌐 URL: https://validador.usiv.cl/pdf-signer/${NC}"
    echo -e "${BLUE}📊 Health Check: https://validador.usiv.cl/pdf-signer/actuator/health${NC}"
}

# Función para verificar el despliegue
verify_deployment() {
    echo -e "${YELLOW}🔍 Verificando despliegue...${NC}"
    
    # Esperar un poco más para asegurar que la aplicación esté lista
    sleep 10
    
    # Verificar health endpoint
    echo "Verificando health endpoint..."
    if curl -f -s https://validador.usiv.cl/pdf-signer/actuator/health > /dev/null; then
        echo -e "${GREEN}✅ Health endpoint responde correctamente${NC}"
    else
        echo -e "${RED}❌ Health endpoint no responde${NC}"
        echo "Verificando logs..."
        ssh $VPS_USER@$VPS_HOST "tail -50 $LOG_DIR/usiv-pdf-service.log"
    fi
}

# Función principal
main() {
    local action="full"
    
    # Procesar argumentos
    case "${1:-}" in
        --build-only)
            action="build"
            ;;
        --deploy-only)
            action="deploy"
            ;;
        --full)
            action="full"
            ;;
        --help)
            show_help
            exit 0
            ;;
        "")
            action="full"
            ;;
        *)
            echo -e "${RED}❌ Opción desconocida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
    
    # Ejecutar acción
    case "$action" in
        "build")
            build_project
            ;;
        "deploy")
            deploy_to_vps
            verify_deployment
            ;;
        "full")
            build_project
            deploy_to_vps
            verify_deployment
            ;;
    esac
    
    echo -e "${GREEN}🎉 ¡Proceso completado exitosamente!${NC}"
}

# Ejecutar función principal con todos los argumentos
main "$@"