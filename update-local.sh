#!/bin/bash

# Script para actualizar PDF Validator API desde directorio local
# Para aplicaciones ya desplegadas
# Solo actualiza el código sin reinstalar servicios

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Banner
echo -e "${CYAN}"
echo "═══════════════════════════════════════════════════════════════════"
echo "           PDF VALIDATOR API - ACTUALIZACIÓN DESDE DIRECTORIO LOCAL "
echo "                        Actualización Rápida                       "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

# Variables de configuración
WAR_FILE="pdf-signer-war-1.0.war"
TOMCAT_HOME="/opt/tomcat"
WEBAPPS_DIR="$TOMCAT_HOME/webapps"
CURRENT_DIR="$(pwd)"
BACKUP_DIR="/opt/pdf-validator-backups"
LOG_FILE="/var/log/pdf-validator-update.log"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar que Tomcat está instalado
check_tomcat_installation() {
    info "Verificando instalación de Tomcat..."
    
    if [ ! -d "$TOMCAT_HOME" ]; then
        error "Tomcat no está instalado en $TOMCAT_HOME. Ejecuta primero deploy-local.sh"
    fi
    
    if ! systemctl is-active --quiet tomcat; then
        warn "Tomcat no está ejecutándose. Intentando iniciar..."
        systemctl start tomcat
        sleep 5
        
        if ! systemctl is-active --quiet tomcat; then
            error "No se pudo iniciar Tomcat"
        fi
    fi
    
    success "Tomcat está ejecutándose correctamente"
}

# Función para verificar directorio del proyecto
check_project_directory() {
    info "Verificando directorio del proyecto..."
    
    if [ ! -f "pom.xml" ]; then
        error "No se encontró pom.xml. Ejecuta este script desde el directorio del proyecto."
    fi
    
    success "Directorio del proyecto verificado: $CURRENT_DIR"
}

# Función para solicitar confirmación
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Función para crear backup
create_backup() {
    log "Creando backup de la aplicación actual..."
    
    # Crear directorio de backup
    mkdir -p $BACKUP_DIR
    
    # Crear backup con timestamp
    BACKUP_NAME="pdf-validator-backup-$(date +%Y%m%d-%H%M%S)"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    mkdir -p $BACKUP_PATH
    
    # Backup del WAR actual
    if [ -f "$WEBAPPS_DIR/pdf-signer-war-1.0.war" ]; then
        cp "$WEBAPPS_DIR/pdf-signer-war-1.0.war" "$BACKUP_PATH/"
        success "WAR actual respaldado"
    fi
    
    # Backup de la carpeta desplegada
    if [ -d "$WEBAPPS_DIR/pdf-signer-war-1.0" ]; then
        cp -r "$WEBAPPS_DIR/pdf-signer-war-1.0" "$BACKUP_PATH/"
        success "Aplicación desplegada respaldada"
    fi
    
    # Backup de configuraciones
    if [ -f "/opt/pdf-validator-credentials.txt" ]; then
        cp "/opt/pdf-validator-credentials.txt" "$BACKUP_PATH/"
    fi
    
    echo "$BACKUP_PATH" > /tmp/last-backup-path
    success "Backup creado en: $BACKUP_PATH"
}

# Función para actualizar desde Git
update_from_git() {
    log "Actualizando código desde Git..."
    
    if [ -d ".git" ]; then
        # Verificar estado del repositorio
        if git status --porcelain | grep -q .; then
            warn "Hay cambios locales sin confirmar:"
            git status --short
            
            if confirm "¿Deseas descartar los cambios locales y actualizar?"; then
                git reset --hard HEAD
                git clean -fd
            else
                info "Conservando cambios locales..."
            fi
        fi
        
        # Actualizar desde remoto
        if git remote get-url origin >/dev/null 2>&1; then
            git fetch origin
            git pull origin main || warn "No se pudo actualizar desde remoto"
            success "Código actualizado desde Git"
        else
            warn "No hay repositorio remoto configurado"
        fi
    else
        warn "No es un repositorio Git. Usando código local actual."
    fi
}

# Función para compilar nueva versión
compile_new_version() {
    log "Compilando nueva versión..."
    
    # Compilar y generar WAR
    mvn clean package -DskipTests -Dmaven.compiler.source=17 -Dmaven.compiler.target=17
    
    if [ $? -ne 0 ]; then
        error "Error al compilar el proyecto"
        error "Verifica que todas las dependencias estén disponibles"
    fi
    
    # Verificar que se generó el WAR
    if [ ! -f "target/$WAR_FILE" ]; then
        error "No se generó el archivo WAR: target/$WAR_FILE"
    fi
    
    success "Nueva versión compilada exitosamente"
}

# Función para desplegar nueva versión
deploy_new_version() {
    log "Desplegando nueva versión..."
    
    # Detener Tomcat
    log "Deteniendo Tomcat..."
    systemctl stop tomcat
    sleep 3
    
    # Limpiar despliegue anterior
    if [ -d "$WEBAPPS_DIR/pdf-signer-war-1.0" ]; then
        rm -rf "$WEBAPPS_DIR/pdf-signer-war-1.0"
    fi
    
    # Copiar nuevo WAR
    cp "target/$WAR_FILE" "$WEBAPPS_DIR/"
    
    # Establecer permisos correctos
    chown tomcat:tomcat "$WEBAPPS_DIR/$WAR_FILE"
    chmod 644 "$WEBAPPS_DIR/$WAR_FILE"
    
    # Actualizar cliente de pruebas si existe
    if [ -f "test-client.html" ]; then
        cp "test-client.html" "/var/www/html/"
        success "Cliente de pruebas actualizado"
    fi
    
    # Iniciar Tomcat
    log "Iniciando Tomcat..."
    systemctl start tomcat
    
    # Esperar a que Tomcat inicie
    log "Esperando a que Tomcat inicie completamente..."
    sleep 10
    
    # Verificar que la aplicación se desplegó correctamente
    for i in {1..30}; do
        if [ -d "$WEBAPPS_DIR/pdf-signer-war-1.0" ]; then
            success "Aplicación desplegada exitosamente"
            return 0
        fi
        sleep 2
    done
    
    error "La aplicación no se desplegó correctamente"
}

# Función para verificar el despliegue
verify_deployment() {
    log "Verificando el despliegue..."
    
    # Verificar que Tomcat está ejecutándose
    if ! systemctl is-active --quiet tomcat; then
        error "Tomcat no está ejecutándose"
    fi
    
    # Verificar que la aplicación responde
    sleep 5
    
    if curl -f -s http://localhost:8080/pdf-signer-war-1.0/health > /dev/null; then
        success "Aplicación responde correctamente"
    else
        warn "La aplicación puede estar iniciando aún. Verifica manualmente en unos minutos."
    fi
    
    # Mostrar logs recientes
    info "Últimas líneas del log de Tomcat:"
    tail -n 10 $TOMCAT_HOME/logs/catalina.out
}

# Función para rollback en caso de error
rollback() {
    error "Error durante la actualización. Iniciando rollback..."
    
    if [ -f "/tmp/last-backup-path" ]; then
        BACKUP_PATH=$(cat /tmp/last-backup-path)
        
        if [ -d "$BACKUP_PATH" ]; then
            log "Restaurando desde backup: $BACKUP_PATH"
            
            # Detener Tomcat
            systemctl stop tomcat
            
            # Restaurar WAR
            if [ -f "$BACKUP_PATH/$WAR_FILE" ]; then
                cp "$BACKUP_PATH/$WAR_FILE" "$WEBAPPS_DIR/"
            fi
            
            # Limpiar despliegue fallido
            if [ -d "$WEBAPPS_DIR/pdf-signer-war-1.0" ]; then
                rm -rf "$WEBAPPS_DIR/pdf-signer-war-1.0"
            fi
            
            # Iniciar Tomcat
            systemctl start tomcat
            
            success "Rollback completado"
        fi
    fi
    
    exit 1
}

# Función principal de actualización
main_update() {
    log "Iniciando actualización desde directorio local..."
    
    # Verificaciones iniciales
    check_tomcat_installation
    check_project_directory
    
    # Solicitar confirmación
    echo -e "\n${YELLOW}Esta actualización realizará las siguientes acciones:${NC}"
    echo -e "${GREEN}  ✓ Creará un backup de la versión actual${NC}"
    echo -e "${GREEN}  ✓ Actualizará el código desde Git (si está disponible)${NC}"
    echo -e "${GREEN}  ✓ Compilará la nueva versión${NC}"
    echo -e "${GREEN}  ✓ Desplegará la nueva versión${NC}"
    echo -e "${GREEN}  ✓ Verificará que todo funcione correctamente${NC}"
    
    if ! confirm "\n¿Deseas continuar con la actualización?"; then
        info "Actualización cancelada por el usuario"
        exit 0
    fi
    
    # Crear backup
    create_backup
    
    # Actualizar desde Git
    update_from_git
    
    # Compilar nueva versión
    compile_new_version
    
    # Desplegar nueva versión
    deploy_new_version
    
    # Verificar despliegue
    verify_deployment
    
    success "Actualización completada exitosamente"
}

# Función para mostrar resumen final
show_final_summary() {
    echo -e "\n${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    ACTUALIZACIÓN COMPLETADA                       "
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎉 ¡PDF Validator API ha sido actualizado exitosamente!${NC}\n"
    
    echo -e "${BLUE}📋 INFORMACIÓN DE LA ACTUALIZACIÓN:${NC}"
    echo -e "${GREEN}   Directorio fuente: $CURRENT_DIR${NC}"
    echo -e "${GREEN}   Backup creado en: $(cat /tmp/last-backup-path 2>/dev/null || echo 'No disponible')${NC}\n"
    
    echo -e "${BLUE}🔧 VERIFICACIONES RECOMENDADAS:${NC}"
    echo -e "${GREEN}   ✓ Probar la aplicación en tu dominio${NC}"
    echo -e "${GREEN}   ✓ Verificar que todas las funciones trabajen correctamente${NC}"
    echo -e "${GREEN}   ✓ Revisar los logs si hay algún problema${NC}\n"
    
    echo -e "${BLUE}📁 UBICACIONES IMPORTANTES:${NC}"
    echo -e "${GREEN}   Aplicación: $WEBAPPS_DIR/$WAR_FILE${NC}"
    echo -e "${GREEN}   Logs: $TOMCAT_HOME/logs/catalina.out${NC}"
    echo -e "${GREEN}   Backups: $BACKUP_DIR${NC}\n"
    
    echo -e "${YELLOW}⚠️  EN CASO DE PROBLEMAS:${NC}"
    echo -e "${GREEN}   # Revisar logs de Tomcat${NC}"
    echo -e "${GREEN}   tail -f $TOMCAT_HOME/logs/catalina.out${NC}"
    echo -e "${GREEN}   # Restaurar backup si es necesario${NC}"
    echo -e "${GREEN}   systemctl stop tomcat${NC}"
    echo -e "${GREEN}   cp $BACKUP_DIR/[ultimo-backup]/$WAR_FILE $WEBAPPS_DIR/${NC}"
    echo -e "${GREEN}   systemctl start tomcat${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
}

# Configurar manejo de errores
trap rollback ERR

# Redirigir output a log file
exec > >(tee -a $LOG_FILE)
exec 2>&1

# Ejecutar actualización principal
main_update

# Mostrar resumen final
show_final_summary

# Guardar información de la actualización
echo "Actualización local completada exitosamente en $(date)" >> /opt/deployment-history.log
echo "Directorio fuente: $CURRENT_DIR" >> /opt/deployment-history.log
echo "---" >> /opt/deployment-history.log

success "¡Actualización local completada exitosamente!"
exit 0