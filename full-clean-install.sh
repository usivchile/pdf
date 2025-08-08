#!/bin/bash

# Script maestro para limpieza completa e instalación del sistema
# PDF Validator API - Instalación Completa Limpia
# Autor: Asistente AI
# Fecha: $(date)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}"
echo " ═══════════════════════════════════════════════════════════════════ "
echo "            INSTALACIÓN COMPLETA LIMPIA - PDF VALIDATOR "
echo " ═══════════════════════════════════════════════════════════════════ "
echo -e "${NC}"

# Función para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

step() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] PASO: $1${NC}"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

# Verificar que los scripts necesarios existen
check_scripts() {
    log "Verificando scripts necesarios..."
    
    REQUIRED_SCRIPTS=(
        "clean-tomcat-install.sh"
        "clean-nginx-install.sh"
        "setup-ssl-step-by-step.sh"
        "check-deployment.sh"
    )
    
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if [[ ! -f "$script" ]]; then
            error "Script requerido no encontrado: $script"
        fi
        chmod +x "$script"
    done
    
    log "✓ Todos los scripts necesarios están disponibles"
}

# Función para mostrar menú de opciones
show_menu() {
    echo -e "${YELLOW}"
    echo "OPCIONES DE INSTALACIÓN:"
    echo "1. Instalación completa limpia (Tomcat + Nginx + SSL)"
    echo "2. Solo limpiar e instalar Tomcat"
    echo "3. Solo limpiar e instalar Nginx"
    echo "4. Solo configurar SSL (requiere Tomcat y Nginx funcionando)"
    echo "5. Verificación completa del sistema"
    echo "6. Salir"
    echo -e "${NC}"
}

# Función para instalación completa
full_installation() {
    step "INICIANDO INSTALACIÓN COMPLETA LIMPIA"
    
    # Paso 1: Limpiar e instalar Tomcat
    step "1/4 - Limpiando e instalando Tomcat"
    log "Ejecutando clean-tomcat-install.sh..."
    ./clean-tomcat-install.sh
    
    if [[ $? -eq 0 ]]; then
        log "✓ Tomcat instalado correctamente"
    else
        error "Error en la instalación de Tomcat"
    fi
    
    # Paso 2: Limpiar e instalar Nginx
    step "2/4 - Limpiando e instalando Nginx"
    log "Ejecutando clean-nginx-install.sh..."
    ./clean-nginx-install.sh
    
    if [[ $? -eq 0 ]]; then
        log "✓ Nginx instalado correctamente"
    else
        error "Error en la instalación de Nginx"
    fi
    
    # Paso 3: Verificar conectividad HTTP
    step "3/4 - Verificando conectividad HTTP"
    sleep 5
    
    log "Probando conectividad local..."
    if curl -s --connect-timeout 10 http://localhost:8080/ > /dev/null; then
        log "✓ Tomcat responde en puerto 8080"
    else
        warn "Tomcat no responde aún en puerto 8080"
    fi
    
    if curl -s --connect-timeout 10 http://localhost/ > /dev/null; then
        log "✓ Nginx responde en puerto 80"
    else
        warn "Nginx no responde aún en puerto 80"
    fi
    
    # Paso 4: Configurar SSL
    step "4/4 - Configurando SSL"
    echo -e "${YELLOW}"
    echo "¿Deseas configurar SSL ahora? (y/n)"
    echo "Nota: Requiere que el dominio validador.usiv.cl apunte a este servidor"
    echo -e "${NC}"
    read -p "Configurar SSL: " ssl_choice
    
    if [[ $ssl_choice =~ ^[Yy]$ ]]; then
        log "Configurando SSL..."
        ./setup-ssl-step-by-step.sh
        
        if [[ $? -eq 0 ]]; then
            log "✓ SSL configurado correctamente"
        else
            warn "Error en la configuración de SSL (se puede configurar después)"
        fi
    else
        log "SSL no configurado (se puede configurar después con: sudo ./setup-ssl-step-by-step.sh)"
    fi
    
    # Verificación final
    step "VERIFICACIÓN FINAL"
    ./check-deployment.sh
}

# Función para instalar solo Tomcat
install_tomcat_only() {
    step "INSTALANDO SOLO TOMCAT"
    ./clean-tomcat-install.sh
}

# Función para instalar solo Nginx
install_nginx_only() {
    step "INSTALANDO SOLO NGINX"
    ./clean-nginx-install.sh
}

# Función para configurar solo SSL
setup_ssl_only() {
    step "CONFIGURANDO SOLO SSL"
    ./setup-ssl-step-by-step.sh
}

# Función para verificación completa
full_verification() {
    step "VERIFICACIÓN COMPLETA DEL SISTEMA"
    ./check-deployment.sh
}

# Función principal con menú interactivo
main() {
    log "Iniciando script maestro de instalación..."
    
    check_scripts
    
    while true; do
        echo
        show_menu
        read -p "Selecciona una opción (1-6): " choice
        
        case $choice in
            1)
                full_installation
                break
                ;;
            2)
                install_tomcat_only
                break
                ;;
            3)
                install_nginx_only
                break
                ;;
            4)
                setup_ssl_only
                break
                ;;
            5)
                full_verification
                break
                ;;
            6)
                log "Saliendo..."
                exit 0
                ;;
            *)
                warn "Opción inválida. Por favor selecciona 1-6."
                ;;
        esac
    done
    
    echo -e "\n${BLUE}"
    echo " ═══════════════════════════════════════════════════════════════════ "
    echo "            PROCESO COMPLETADO "
    echo " ═══════════════════════════════════════════════════════════════════ "
    echo -e "${NC}"
    
    echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
    echo -e "${GREEN}Estado Tomcat: sudo systemctl status tomcat${NC}"
    echo -e "${GREEN}Estado Nginx: sudo systemctl status nginx${NC}"
    echo -e "${GREEN}Logs Tomcat: sudo tail -f /opt/tomcat/logs/catalina.out${NC}"
    echo -e "${GREEN}Logs Nginx: sudo tail -f /var/log/nginx/error.log${NC}"
    echo -e "${GREEN}Verificación: sudo ./check-deployment.sh${NC}"
    echo -e "${GREEN}Configurar SSL: sudo ./setup-ssl-step-by-step.sh${NC}"
    
    echo -e "\n${YELLOW}=== ACCESO A LA APLICACIÓN ===${NC}"
    echo -e "${GREEN}HTTP: http://validador.usiv.cl${NC}"
    echo -e "${GREEN}HTTPS: https://validador.usiv.cl (si SSL está configurado)${NC}"
    
    log "Script maestro completado exitosamente"
}

# Ejecutar función principal
main "$@"