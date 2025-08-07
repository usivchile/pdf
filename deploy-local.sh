#!/bin/bash

# Script de despliegue desde directorio local para PDF Validator API
# Para VPS Hostinger (CentOS 9)
# Este script usa el código ya clonado localmente

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
echo "           PDF VALIDATOR API - DESPLIEGUE DESDE DIRECTORIO LOCAL    "
echo "                        VPS Hostinger (CentOS 9)                   "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

# Variables de configuración
DOMAIN="validador.usiv.cl"
EMAIL="admin@usiv.cl"
WAR_FILE="pdf-signer-war-1.0.war"
CURRENT_DIR="$(pwd)"
DEPLOY_DIR="/opt/pdf-validator-deploy"
LOG_FILE="/var/log/pdf-validator-deploy.log"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar conectividad
check_connectivity() {
    info "Verificando conectividad a internet..."
    if ping -c 1 google.com &> /dev/null; then
        success "Conectividad a internet OK"
    else
        error "Sin conectividad a internet"
    fi
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    info "Verificando requisitos del sistema..."
    
    # Verificar OS
    if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
        success "Sistema operativo compatible detectado"
    else
        error "Este script está diseñado para CentOS/RHEL"
    fi
    
    # Verificar memoria
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ $MEMORY_GB -ge 2 ]; then
        success "Memoria suficiente: ${MEMORY_GB}GB"
    else
        warn "Memoria limitada: ${MEMORY_GB}GB (recomendado: 2GB+)"
    fi
    
    # Verificar espacio en disco
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
    if [ $DISK_SPACE_GB -ge 10 ]; then
        success "Espacio en disco suficiente: ${DISK_SPACE_GB}GB"
    else
        error "Espacio en disco insuficiente: ${DISK_SPACE_GB}GB (requerido: 10GB+)"
    fi
}

# Función para verificar directorio del proyecto
check_project_directory() {
    info "Verificando directorio del proyecto..."
    
    # Verificar que estamos en el directorio correcto
    if [ ! -f "pom.xml" ]; then
        error "No se encontró pom.xml. Ejecuta este script desde el directorio del proyecto."
    fi
    
    if [ ! -f "install-vps.sh" ]; then
        error "No se encontraron los scripts de instalación. Verifica que estés en el directorio correcto."
    fi
    
    success "Directorio del proyecto verificado: $CURRENT_DIR"
}

# Función para solicitar confirmación
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Función para solicitar configuración
get_configuration() {
    echo -e "\n${YELLOW}Configuración del Despliegue${NC}"
    
    read -p "Ingresa tu dominio (default: $DOMAIN): " input_domain
    if [ -n "$input_domain" ]; then
        DOMAIN="$input_domain"
    fi
    
    read -p "Ingresa tu email para SSL (default: $EMAIL): " input_email
    if [ -n "$input_email" ]; then
        EMAIL="$input_email"
    fi
    
    success "Dominio configurado: $DOMAIN"
    success "Email configurado: $EMAIL"
}

# Función principal de despliegue
main_deployment() {
    log "Iniciando despliegue desde directorio local..."
    
    # 1. Verificaciones iniciales
    check_connectivity
    check_system_requirements
    check_project_directory
    
    # 2. Configuración
    get_configuration
    
    # 3. Solicitar confirmación para continuar
    echo -e "\n${YELLOW}Este script realizará las siguientes acciones:${NC}"
    echo -e "${GREEN}  ✓ Usará el código del directorio actual: $CURRENT_DIR${NC}"
    echo -e "${GREEN}  ✓ Compilará la aplicación con Maven${NC}"
    echo -e "${GREEN}  ✓ Instalará Java 17 y Tomcat 10${NC}"
    echo -e "${GREEN}  ✓ Configurará Nginx como proxy reverso${NC}"
    echo -e "${GREEN}  ✓ Instalará certificados SSL con Let's Encrypt${NC}"
    echo -e "${GREEN}  ✓ Aplicará configuraciones de seguridad${NC}"
    echo -e "${GREEN}  ✓ Configurará monitoreo y backups automáticos${NC}"
    echo -e "${GREEN}  ✓ Desplegará la aplicación PDF Validator${NC}"
    
    if ! confirm "\n¿Deseas continuar con el despliegue?"; then
        info "Despliegue cancelado por el usuario"
        exit 0
    fi
    
    # 4. Crear directorio de despliegue
    log "Creando directorio de despliegue..."
    mkdir -p $DEPLOY_DIR
    
    # 5. Instalar dependencias necesarias
    log "Instalando dependencias del sistema..."
    dnf update -y
    
    # Instalar Maven si no está disponible
    if ! command_exists mvn; then
        log "Instalando Maven..."
        dnf install maven -y
    fi
    
    # Instalar Java 17 si no está disponible
    if ! command_exists java; then
        log "Instalando Java 17..."
        dnf install java-17-openjdk java-17-openjdk-devel -y
    fi
    
    # 6. Actualizar desde Git si es posible
    if [ -d ".git" ]; then
        log "Actualizando código desde Git..."
        if git remote get-url origin >/dev/null 2>&1; then
            git fetch origin
            git pull origin main || warn "No se pudo actualizar desde remoto, usando código local"
        fi
    fi
    
    # 7. Compilar proyecto
    log "Compilando proyecto con Maven..."
    
    # Compilar y generar WAR
    mvn clean package -DskipTests
    
    if [ $? -ne 0 ]; then
        error "Error al compilar el proyecto"
    fi
    
    # Verificar que se generó el WAR
    if [ ! -f "target/$WAR_FILE" ]; then
        error "No se generó el archivo WAR: target/$WAR_FILE"
    fi
    
    success "Proyecto compilado exitosamente"
    
    # 8. Copiar archivos necesarios
    log "Preparando archivos para despliegue..."
    
    # Copiar WAR al directorio de despliegue
    cp "target/$WAR_FILE" $DEPLOY_DIR/
    
    # Copiar scripts de despliegue
    cp install-vps.sh $DEPLOY_DIR/
    cp configure-nginx.sh $DEPLOY_DIR/
    cp security-hardening.sh $DEPLOY_DIR/
    cp deploy-complete.sh $DEPLOY_DIR/
    
    # Copiar cliente de pruebas
    if [ -f "test-client.html" ]; then
        cp test-client.html $DEPLOY_DIR/
    fi
    
    cd $DEPLOY_DIR
    
    # Hacer ejecutables todos los scripts
    chmod +x *.sh
    
    success "Archivos preparados para despliegue"
    
    # 9. Actualizar configuraciones en los scripts
    log "Configurando scripts con parámetros personalizados..."
    
    # Actualizar dominio y email en los scripts
    sed -i "s|DOMAIN=\".*\"|DOMAIN=\"$DOMAIN\"|" install-vps.sh
    sed -i "s|EMAIL=\".*\"|EMAIL=\"$EMAIL\"|" configure-nginx.sh
    sed -i "s|DOMAIN=\".*\"|DOMAIN=\"$DOMAIN\"|" configure-nginx.sh
    
    # 10. Ejecutar instalación base
    log "Ejecutando instalación base..."
    ./install-vps.sh
    
    # 11. Configurar Nginx
    log "Configurando Nginx..."
    ./configure-nginx.sh
    
    # 12. Aplicar configuraciones de seguridad
    log "Aplicando configuraciones de seguridad..."
    ./security-hardening.sh
    
    success "Despliegue completado exitosamente"
}

# Función para mostrar resumen final
show_final_summary() {
    echo -e "\n${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    DESPLIEGUE LOCAL COMPLETADO                    "
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎉 ¡PDF Validator API ha sido desplegado exitosamente!${NC}\n"
    
    echo -e "${BLUE}📋 INFORMACIÓN DEL DESPLIEGUE:${NC}"
    echo -e "${GREEN}   Directorio fuente: $CURRENT_DIR${NC}"
    echo -e "${GREEN}   URL Principal: https://$DOMAIN${NC}"
    echo -e "${GREEN}   Cliente de Pruebas: https://$DOMAIN/test-client.html${NC}"
    echo -e "${GREEN}   Credenciales: /opt/pdf-validator-credentials.txt${NC}\n"
    
    echo -e "${BLUE}🔧 SERVICIOS CONFIGURADOS:${NC}"
    echo -e "${GREEN}   ✓ Java 17 + Tomcat 10${NC}"
    echo -e "${GREEN}   ✓ Nginx con SSL (Let's Encrypt)${NC}"
    echo -e "${GREEN}   ✓ fail2ban para protección${NC}"
    echo -e "${GREEN}   ✓ Monitoreo automático${NC}"
    echo -e "${GREEN}   ✓ Backups automáticos${NC}"
    echo -e "${GREEN}   ✓ Actualizaciones de seguridad${NC}\n"
    
    echo -e "${YELLOW}⚠️  PRÓXIMOS PASOS:${NC}"
    echo -e "${GREEN}   1. Verificar que $DOMAIN apunte a esta IP${NC}"
    echo -e "${GREEN}   2. Probar la aplicación en https://$DOMAIN${NC}"
    echo -e "${GREEN}   3. Revisar las credenciales en /opt/pdf-validator-credentials.txt${NC}"
    echo -e "${GREEN}   4. Configurar monitoreo adicional si es necesario${NC}\n"
    
    echo -e "${BLUE}🔄 PARA FUTURAS ACTUALIZACIONES:${NC}"
    echo -e "${GREEN}   # Desde el directorio del proyecto${NC}"
    echo -e "${GREEN}   cd $CURRENT_DIR${NC}"
    echo -e "${GREEN}   git pull${NC}"
    echo -e "${GREEN}   sudo ./update-from-git.sh${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
}

# Función para manejar errores
handle_error() {
    error "Error durante el despliegue en la línea $1"
    echo "Revisa los logs en: $LOG_FILE"
    echo "Para obtener ayuda, revisa la documentación o contacta al soporte."
    exit 1
}

# Configurar manejo de errores
trap 'handle_error $LINENO' ERR

# Redirigir output a log file
exec > >(tee -a $LOG_FILE)
exec 2>&1

# Ejecutar despliegue principal
main_deployment

# Mostrar resumen final
show_final_summary

# Guardar información del despliegue
echo "Despliegue local completado exitosamente en $(date)" >> /opt/deployment-history.log
echo "Directorio fuente: $CURRENT_DIR" >> /opt/deployment-history.log
echo "Dominio: $DOMAIN" >> /opt/deployment-history.log
echo "---" >> /opt/deployment-history.log

success "¡Despliegue local completado exitosamente!"
exit 0