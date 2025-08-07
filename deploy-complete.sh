#!/bin/bash

# Script de despliegue completo para PDF Validator API
# Para VPS Hostinger (CentOS 9)
# Este script ejecuta todo el proceso de instalación y configuración

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
echo "                    PDF VALIDATOR API DEPLOYMENT                   "
echo "                        VPS Hostinger (CentOS 9)                   "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

# Variables de configuración
DOMAIN="validador.usiv.cl"
EMAIL="admin@usiv.cl"  # Cambiar por email real
WAR_FILE="pdf-signer-war-1.0.war"
DEPLOY_DIR="/opt/pdf-validator-deploy"
LOG_FILE="/var/log/pdf-validator-deploy.log"
GIT_REPO="https://github.com/tu-usuario/pdf-validator-api.git"  # Cambiar por tu repositorio
GIT_BRANCH="main"

# Crear directorio de despliegue
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

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

# Función para solicitar confirmación
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Función para generar contraseñas seguras
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Función principal de despliegue
main_deployment() {
    log "Iniciando despliegue completo de PDF Validator API..."
    
    # 1. Verificaciones iniciales
    check_connectivity
    check_system_requirements
    
    # 2. Solicitar confirmación para continuar
    echo -e "\n${YELLOW}Este script realizará las siguientes acciones:${NC}"
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
    
    # 3. Descargar proyecto desde Git y compilar
    log "Descargando proyecto desde Git..."
    
    # Instalar Git si no está disponible
    if ! command_exists git; then
        log "Instalando Git..."
        dnf install git -y
    fi
    
    # Instalar Maven si no está disponible
    if ! command_exists mvn; then
        log "Instalando Maven..."
        dnf install maven -y
    fi
    
    # Clonar o actualizar repositorio
    if [ -d "pdf-validator-source" ]; then
        log "Actualizando repositorio existente..."
        cd pdf-validator-source
        git pull origin $GIT_BRANCH
        cd ..
    else
        log "Clonando repositorio..."
        git clone -b $GIT_BRANCH $GIT_REPO pdf-validator-source
    fi
    
    # Compilar proyecto
    log "Compilando proyecto con Maven..."
    cd pdf-validator-source
    
    # Verificar que existe pom.xml
    if [ ! -f "pom.xml" ]; then
        error "No se encontró pom.xml en el repositorio"
    fi
    
    # Compilar y generar WAR
    mvn clean package -DskipTests
    
    if [ $? -ne 0 ]; then
        error "Error al compilar el proyecto"
    fi
    
    # Verificar que se generó el WAR
    if [ ! -f "target/$WAR_FILE" ]; then
        error "No se generó el archivo WAR: target/$WAR_FILE"
    fi
    
    # Copiar WAR al directorio de despliegue
    cp target/$WAR_FILE $DEPLOY_DIR/
    
    # Copiar cliente de pruebas
    if [ -f "test-client.html" ]; then
        cp test-client.html $DEPLOY_DIR/
    fi
    
    cd $DEPLOY_DIR
    success "Proyecto compilado y WAR generado: $WAR_FILE"
    
    # 4. Copiar scripts desde el repositorio y ejecutar instalación VPS
    log "Copiando scripts de despliegue desde el repositorio..."
    
    # Copiar scripts necesarios desde el repositorio
    cp pdf-validator-source/install-vps.sh .
    cp pdf-validator-source/configure-nginx.sh .
    cp pdf-validator-source/security-hardening.sh .
    cp pdf-validator-source/deploy-complete.sh .
    cp pdf-validator-source/deploy-from-git.sh .
    cp pdf-validator-source/update-from-git.sh .
    
    # Hacer ejecutables todos los scripts
    chmod +x install-vps.sh configure-nginx.sh security-hardening.sh
    
    log "Paso 1/4: Instalando componentes base (Java, Tomcat)..."
    if [ -f "install-vps.sh" ]; then
        ./install-vps.sh
        success "Instalación base completada"
    else
        error "Script install-vps.sh no encontrado"
    fi
    
    # 5. Desplegar aplicación
    log "Paso 2/4: Desplegando aplicación..."
    
    # Detener Tomcat
    systemctl stop tomcat
    
    # Limpiar despliegue anterior
    rm -rf /opt/tomcat/webapps/ROOT*
    
    # Copiar nuevo WAR
    cp $WAR_FILE /opt/tomcat/webapps/ROOT.war
    chown tomcat:tomcat /opt/tomcat/webapps/ROOT.war
    
    # Crear directorio de almacenamiento
    mkdir -p /opt/tomcat/webapps/storage/pdfs
    chown -R tomcat:tomcat /opt/tomcat/webapps/storage
    chmod -R 755 /opt/tomcat/webapps/storage
    
    # Iniciar Tomcat
    systemctl start tomcat
    
    # Esperar a que la aplicación se despliegue
    info "Esperando despliegue de la aplicación..."
    sleep 30
    
    # Verificar que la aplicación esté funcionando
    for i in {1..10}; do
        if curl -s http://localhost:8080/api/auth/validate > /dev/null; then
            success "Aplicación desplegada correctamente"
            break
        else
            info "Intento $i/10: Esperando que la aplicación esté lista..."
            sleep 10
        fi
        
        if [ $i -eq 10 ]; then
            error "La aplicación no responde después de 10 intentos"
        fi
    done
    
    # 6. Configurar Nginx
    log "Paso 3/4: Configurando Nginx y SSL..."
    ./configure-nginx.sh
    success "Nginx configurado"
    
    # 7. Aplicar endurecimiento de seguridad
    log "Paso 4/4: Aplicando configuraciones de seguridad..."
    ./security-hardening.sh
    success "Seguridad configurada"
    
    # 8. Verificaciones finales
    log "Realizando verificaciones finales..."
    
    # Verificar servicios
    for service in nginx tomcat fail2ban; do
        if systemctl is-active --quiet $service; then
            success "Servicio $service está ejecutándose"
        else
            error "Servicio $service NO está ejecutándose"
        fi
    done
    
    # Verificar conectividad local
    if curl -s http://localhost:8080/api/auth/validate > /dev/null; then
        success "API responde correctamente en puerto 8080"
    else
        error "API no responde en puerto 8080"
    fi
    
    if curl -s http://localhost/api/auth/validate > /dev/null; then
        success "Nginx proxy funciona correctamente"
    else
        warn "Nginx proxy puede tener problemas"
    fi
    
    # 9. Generar credenciales y mostrar información
    log "Generando información de acceso..."
    
    # Leer credenciales del archivo de propiedades
    PROPS_FILE="/opt/tomcat/webapps/ROOT/WEB-INF/classes/application.properties"
    if [ -f "$PROPS_FILE" ]; then
        ADMIN_USER=$(grep "api.admin.username" $PROPS_FILE | cut -d'=' -f2)
        ADMIN_PASS=$(grep "api.admin.password" $PROPS_FILE | cut -d'=' -f2)
        USER_USER=$(grep "api.user.username" $PROPS_FILE | cut -d'=' -f2)
        USER_PASS=$(grep "api.user.password" $PROPS_FILE | cut -d'=' -f2)
    else
        warn "No se pudo leer el archivo de propiedades"
        ADMIN_USER="admin"
        ADMIN_PASS="admin123"
        USER_USER="user"
        USER_PASS="user123"
    fi
    
    # Crear archivo de credenciales
    cat > /opt/pdf-validator-credentials.txt << EOF
# PDF Validator API - Credenciales de Acceso
# Generado: $(date)
# Dominio: $DOMAIN

=== CREDENCIALES DE API ===
Admin User: $ADMIN_USER
Admin Password: $ADMIN_PASS

Regular User: $USER_USER
Regular Password: $USER_PASS

=== URLs DE ACCESO ===
URL Principal: https://$DOMAIN
API Base URL: https://$DOMAIN/api
Cliente de Pruebas: https://$DOMAIN/test-client.html

=== ENDPOINTS PRINCIPALES ===
Login: POST https://$DOMAIN/api/auth/login
Validar Token: GET https://$DOMAIN/api/auth/validate
Subir PDF: POST https://$DOMAIN/api/pdf/upload (público)
Listar Archivos: GET https://$DOMAIN/api/files (requiere JWT)
Estadísticas: GET https://$DOMAIN/api/files/stats (requiere JWT)

=== ARCHIVOS IMPORTANTES ===
Logs de aplicación: /opt/tomcat/logs/
Logs de Nginx: /var/log/nginx/
Almacenamiento de PDFs: /opt/tomcat/webapps/storage/pdfs/
Configuraciones: /opt/tomcat/conf/

=== COMANDOS ÚTILES ===
Reiniciar Tomcat: sudo systemctl restart tomcat
Reiniciar Nginx: sudo systemctl restart nginx
Ver logs de aplicación: sudo tail -f /opt/tomcat/logs/catalina.out
Ver logs de Nginx: sudo tail -f /var/log/nginx/$DOMAIN.access.log
Verificar seguridad: sudo /opt/security-check.sh
Monitoreo: sudo /opt/monitor-pdf-validator.sh

=== CAMBIAR CREDENCIALES ===
Para cambiar las credenciales de API:
1. Editar: /opt/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
2. Modificar: api.admin.password y api.user.password
3. Reiniciar: sudo systemctl restart tomcat

=== SOPORTE ===
Documentación: Ver README.md en el proyecto
Logs de despliegue: $LOG_FILE
Verificación de seguridad: /var/log/security-check.log
EOF
    
    chmod 600 /opt/pdf-validator-credentials.txt
    
    success "Archivo de credenciales creado: /opt/pdf-validator-credentials.txt"
}

# Función para mostrar resumen final
show_final_summary() {
    echo -e "\n${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    DESPLIEGUE COMPLETADO EXITOSAMENTE             "
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎉 ¡PDF Validator API ha sido desplegado exitosamente!${NC}\n"
    
    echo -e "${BLUE}📋 INFORMACIÓN DE ACCESO:${NC}"
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
    
    echo -e "${BLUE}📁 ARCHIVOS IMPORTANTES:${NC}"
    echo -e "${GREEN}   • Credenciales: /opt/pdf-validator-credentials.txt${NC}"
    echo -e "${GREEN}   • Logs de aplicación: /opt/tomcat/logs/catalina.out${NC}"
    echo -e "${GREEN}   • Logs de Nginx: /var/log/nginx/$DOMAIN.access.log${NC}"
    echo -e "${GREEN}   • Configuración: /opt/tomcat/conf/server.xml${NC}\n"
    
    echo -e "${BLUE}🛠️ COMANDOS ÚTILES:${NC}"
    echo -e "${GREEN}   sudo systemctl status tomcat nginx${NC}"
    echo -e "${GREEN}   sudo /opt/security-check.sh${NC}"
    echo -e "${GREEN}   sudo tail -f /opt/tomcat/logs/catalina.out${NC}"
    echo -e "${GREEN}   sudo fail2ban-client status${NC}\n"
    
    echo -e "${YELLOW}⚠️  PRÓXIMOS PASOS:${NC}"
    echo -e "${GREEN}   1. Verificar que $DOMAIN apunte a esta IP${NC}"
    echo -e "${GREEN}   2. Probar la aplicación en https://$DOMAIN${NC}"
    echo -e "${GREEN}   3. Revisar las credenciales en /opt/pdf-validator-credentials.txt${NC}"
    echo -e "${GREEN}   4. Configurar monitoreo adicional si es necesario${NC}\n"
    
    echo -e "${BLUE}📞 SOPORTE:${NC}"
    echo -e "${GREEN}   • Documentación completa en README.md${NC}"
    echo -e "${GREEN}   • Logs de despliegue: $LOG_FILE${NC}"
    echo -e "${GREEN}   • IP del servidor: $(curl -s ifconfig.me)${NC}\n"
    
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
echo "Despliegue completado exitosamente en $(date)" >> /opt/deployment-history.log
echo "Dominio: $DOMAIN" >> /opt/deployment-history.log
echo "WAR: $WAR_FILE" >> /opt/deployment-history.log
echo "---" >> /opt/deployment-history.log

success "¡Despliegue completado exitosamente!"
exit 0