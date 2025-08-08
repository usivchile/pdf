#!/bin/bash

# Script maestro para limpieza completa e instalación del sistema
# PDF Validator API - Instalación Completa Limpia
# Autor: Asistente AI
# Fecha: $(date)

# No usar set -e para evitar terminaciones abruptas
# set -e

# Función para manejo de errores
handle_error() {
    local exit_code=$?
    local line_number=$1
    warn "Error en línea $line_number (código: $exit_code), continuando..."
    return 0
}

# Trap para capturar errores pero continuar
trap 'handle_error $LINENO' ERR

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
    local tomcat_success=false
    local nginx_success=false
    local overall_success=true
    
    # Paso 1: Limpiar e instalar Tomcat
    step "1/4 - Limpiando e instalando Tomcat"
    log "Ejecutando clean-tomcat-install.sh..."
    
    if [[ -f "./clean-tomcat-install.sh" ]]; then
        chmod +x ./clean-tomcat-install.sh
        if ./clean-tomcat-install.sh; then
            log "✓ Tomcat instalado correctamente"
            tomcat_success=true
        else
            warn "⚠ Error en la instalación de Tomcat (código: $?)"
            log "Continuando con la instalación..."
            overall_success=false
        fi
    else
        warn "⚠ Script clean-tomcat-install.sh no encontrado"
        overall_success=false
    fi
    
    # Paso 2: Limpiar e instalar Nginx
    step "2/4 - Limpiando e instalando Nginx"
    log "Ejecutando clean-nginx-install.sh..."
    
    if [[ -f "./clean-nginx-install.sh" ]]; then
        chmod +x ./clean-nginx-install.sh
        if ./clean-nginx-install.sh; then
            log "✓ Nginx instalado correctamente"
            nginx_success=true
        else
            warn "⚠ Error en la instalación de Nginx (código: $?)"
            log "Continuando con la instalación..."
            overall_success=false
        fi
    else
        warn "⚠ Script clean-nginx-install.sh no encontrado"
        overall_success=false
    fi
    
    # Paso 3: Verificar conectividad HTTP
    step "3/4 - Verificando conectividad HTTP"
    log "Esperando que los servicios se inicialicen..."
    sleep 10
    
    log "Probando conectividad local..."
    
    # Verificar Tomcat
    if $tomcat_success; then
        local tomcat_attempts=0
        local tomcat_running=false
        while [[ $tomcat_attempts -lt 3 ]]; do
            if curl -s --connect-timeout 10 http://localhost:8080/ > /dev/null 2>&1; then
                log "✓ Tomcat responde en puerto 8080"
                tomcat_running=true
                break
            else
                ((tomcat_attempts++))
                log "Intento $tomcat_attempts/3 - Esperando respuesta de Tomcat..."
                sleep 5
            fi
        done
        
        if ! $tomcat_running; then
            warn "⚠ Tomcat no responde en puerto 8080 después de 3 intentos"
        fi
    else
        warn "⚠ Saltando verificación de Tomcat (instalación falló)"
    fi
    
    # Verificar Nginx
    if $nginx_success; then
        local nginx_attempts=0
        local nginx_running=false
        while [[ $nginx_attempts -lt 3 ]]; do
            if curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
                log "✓ Nginx responde en puerto 80"
                nginx_running=true
                break
            else
                ((nginx_attempts++))
                log "Intento $nginx_attempts/3 - Esperando respuesta de Nginx..."
                sleep 5
            fi
        done
        
        if ! $nginx_running; then
            warn "⚠ Nginx no responde en puerto 80 después de 3 intentos"
        fi
    else
        warn "⚠ Saltando verificación de Nginx (instalación falló)"
    fi
    
    # Paso 4: Configurar SSL (solo si ambos servicios están funcionando)
    step "4/4 - Configurando SSL"
    
    if $tomcat_success && $nginx_success; then
        echo -e "${YELLOW}"
        echo "¿Deseas configurar SSL ahora? (y/n)"
        echo "Nota: Requiere que el dominio validador.usiv.cl apunte a este servidor"
        echo -e "${NC}"
        read -p "Configurar SSL: " ssl_choice
        
        if [[ $ssl_choice =~ ^[Yy]$ ]]; then
            log "Configurando SSL..."
            if [[ -f "./setup-ssl-step-by-step.sh" ]]; then
                chmod +x ./setup-ssl-step-by-step.sh
                if ./setup-ssl-step-by-step.sh; then
                    log "✓ SSL configurado correctamente"
                else
                    warn "⚠ Error en la configuración de SSL (se puede configurar después)"
                    overall_success=false
                fi
            else
                warn "⚠ Script setup-ssl-step-by-step.sh no encontrado"
            fi
        else
            log "SSL no configurado (se puede configurar después con: sudo ./setup-ssl-step-by-step.sh)"
        fi
    else
        warn "⚠ Saltando configuración SSL - Tomcat o Nginx no están funcionando correctamente"
        log "Puedes configurar SSL después cuando ambos servicios estén funcionando"
    fi
    
    # Verificación final
    step "VERIFICACIÓN FINAL"
    if [[ -f "./check-deployment.sh" ]]; then
        chmod +x ./check-deployment.sh
        ./check-deployment.sh
    else
        warn "⚠ Script check-deployment.sh no encontrado"
    fi
    
    # Resumen final
    step "RESUMEN DE INSTALACIÓN"
    if $overall_success; then
        log "✅ Instalación completada exitosamente"
    else
        warn "⚠ Instalación completada con algunos errores"
    fi
    
    echo -e "${YELLOW}"
    echo "Estado de componentes:"
    echo "- Tomcat: $(if $tomcat_success; then echo '✓ Instalado'; else echo '✗ Error'; fi)"
    echo "- Nginx: $(if $nginx_success; then echo '✓ Instalado'; else echo '✗ Error'; fi)"
    echo -e "${NC}"
    
    if ! $overall_success; then
        echo -e "${YELLOW}"
        echo "Comandos útiles para diagnóstico:"
        echo "- sudo systemctl status tomcat9"
        echo "- sudo systemctl status nginx"
        echo "- sudo journalctl -u tomcat9 -f"
        echo "- sudo journalctl -u nginx -f"
        echo "- sudo ./troubleshoot.sh"
        echo -e "${NC}"
    fi
}

# Función para instalar solo Tomcat
install_tomcat_only() {
    step "INSTALANDO SOLO TOMCAT"
    
    if [[ -f "./clean-tomcat-install.sh" ]]; then
        chmod +x ./clean-tomcat-install.sh
        if ./clean-tomcat-install.sh; then
            log "✓ Tomcat instalado correctamente"
            
            # Verificar que Tomcat esté funcionando
            log "Verificando Tomcat..."
            sleep 10
            
            local attempts=0
            while [[ $attempts -lt 3 ]]; do
                if curl -s --connect-timeout 10 http://localhost:8080/ > /dev/null 2>&1; then
                    log "✓ Tomcat responde en puerto 8080"
                    break
                else
                    ((attempts++))
                    log "Intento $attempts/3 - Esperando respuesta de Tomcat..."
                    sleep 5
                fi
            done
        else
            warn "⚠ Error en la instalación de Tomcat (código: $?)"
            log "Revisa los logs para más detalles"
        fi
    else
        error "Script clean-tomcat-install.sh no encontrado"
    fi
}

# Función para instalar solo Nginx
install_nginx_only() {
    step "INSTALANDO SOLO NGINX"
    
    if [[ -f "./clean-nginx-install.sh" ]]; then
        chmod +x ./clean-nginx-install.sh
        if ./clean-nginx-install.sh; then
            log "✓ Nginx instalado correctamente"
            
            # Verificar que Nginx esté funcionando
            log "Verificando Nginx..."
            sleep 5
            
            local attempts=0
            while [[ $attempts -lt 3 ]]; do
                if curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
                    log "✓ Nginx responde en puerto 80"
                    break
                else
                    ((attempts++))
                    log "Intento $attempts/3 - Esperando respuesta de Nginx..."
                    sleep 5
                fi
            done
        else
            warn "⚠ Error en la instalación de Nginx (código: $?)"
            log "Revisa los logs para más detalles"
        fi
    else
        error "Script clean-nginx-install.sh no encontrado"
    fi
}

# Función para configurar solo SSL
setup_ssl_only() {
    step "CONFIGURANDO SOLO SSL"
    
    # Verificar que Tomcat y Nginx estén funcionando
    log "Verificando servicios antes de configurar SSL..."
    
    local tomcat_ok=false
    local nginx_ok=false
    
    if curl -s --connect-timeout 10 http://localhost:8080/ > /dev/null 2>&1; then
        log "✓ Tomcat está funcionando"
        tomcat_ok=true
    else
        warn "⚠ Tomcat no responde en puerto 8080"
    fi
    
    if curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
        log "✓ Nginx está funcionando"
        nginx_ok=true
    else
        warn "⚠ Nginx no responde en puerto 80"
    fi
    
    if $tomcat_ok && $nginx_ok; then
        if [[ -f "./setup-ssl-step-by-step.sh" ]]; then
            chmod +x ./setup-ssl-step-by-step.sh
            if ./setup-ssl-step-by-step.sh; then
                log "✓ SSL configurado correctamente"
            else
                warn "⚠ Error en la configuración de SSL (código: $?)"
                log "Revisa los logs para más detalles"
            fi
        else
            error "Script setup-ssl-step-by-step.sh no encontrado"
        fi
    else
        error "No se puede configurar SSL - Tomcat y/o Nginx no están funcionando"
        log "Asegúrate de que ambos servicios estén instalados y funcionando antes de configurar SSL"
    fi
}

# Función para verificación completa
full_verification() {
    step "VERIFICACIÓN COMPLETA DEL SISTEMA"
    
    if [[ -f "./check-deployment.sh" ]]; then
        chmod +x ./check-deployment.sh
        if ./check-deployment.sh; then
            log "✓ Verificación completada"
        else
            warn "⚠ La verificación encontró algunos problemas"
            log "Revisa la salida anterior para más detalles"
        fi
    else
        warn "⚠ Script check-deployment.sh no encontrado"
        log "Realizando verificación básica..."
        
        # Verificación básica manual
        echo -e "${YELLOW}Estado de servicios:${NC}"
        
        if systemctl is-active --quiet tomcat9; then
            echo "✓ Tomcat9 está activo"
        else
            echo "✗ Tomcat9 no está activo"
        fi
        
        if systemctl is-active --quiet nginx; then
            echo "✓ Nginx está activo"
        else
            echo "✗ Nginx no está activo"
        fi
        
        echo -e "${YELLOW}Conectividad:${NC}"
        
        if curl -s --connect-timeout 10 http://localhost:8080/ > /dev/null 2>&1; then
            echo "✓ Tomcat responde en puerto 8080"
        else
            echo "✗ Tomcat no responde en puerto 8080"
        fi
        
        if curl -s --connect-timeout 10 http://localhost/ > /dev/null 2>&1; then
            echo "✓ Nginx responde en puerto 80"
        else
            echo "✗ Nginx no responde en puerto 80"
        fi
    fi
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