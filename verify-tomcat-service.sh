#!/bin/bash

# Script para verificar específicamente el servicio Tomcat en CentOS/Rocky Linux
# Autor: Sistema de Despliegue PDF Signer

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}✗ $1${NC}"
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ $1${NC}"
}

echo "═══════════════════════════════════════════════════════════════════"
echo "                VERIFICACIÓN SERVICIO TOMCAT"
echo "                    CentOS/Rocky Linux"
echo "═══════════════════════════════════════════════════════════════════"
echo

# 1. Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# 2. Verificar sistema operativo
log_info "Verificando sistema operativo..."
if [[ -f /etc/os-release ]]; then
    OS_INFO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    log_success "Sistema: $OS_INFO"
else
    log_error "No se pudo determinar el sistema operativo"
fi

# 3. Verificar gestor de paquetes
log_info "Verificando gestor de paquetes..."
if command -v dnf >/dev/null 2>&1; then
    log_success "DNF disponible"
elif command -v yum >/dev/null 2>&1; then
    log_success "YUM disponible"
else
    log_error "No se encontró DNF ni YUM"
fi

# 4. Verificar Java
log_info "Verificando Java..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | head -1)
    log_success "Java encontrado: $JAVA_VERSION"
    
    # Verificar JAVA_HOME
    if [[ -n "$JAVA_HOME" ]]; then
        log_success "JAVA_HOME configurado: $JAVA_HOME"
    else
        log_error "JAVA_HOME no configurado"
        # Intentar detectar
        JAVA_PATH=$(which java)
        if [[ -n "$JAVA_PATH" ]]; then
            REAL_JAVA_PATH=$(readlink -f "$JAVA_PATH")
            DETECTED_JAVA_HOME=$(dirname "$(dirname "$REAL_JAVA_PATH")")
            log_info "JAVA_HOME detectado: $DETECTED_JAVA_HOME"
        fi
    fi
else
    log_error "Java no encontrado"
fi

# 5. Verificar usuario tomcat
log_info "Verificando usuario tomcat..."
if id "tomcat" &>/dev/null; then
    log_success "Usuario tomcat existe"
else
    log_error "Usuario tomcat no existe"
fi

# 6. Verificar directorio Tomcat
log_info "Verificando instalación de Tomcat..."
if [[ -d "/opt/tomcat" ]]; then
    log_success "Directorio /opt/tomcat existe"
    
    # Verificar archivos críticos
    if [[ -f "/opt/tomcat/bin/startup.sh" ]]; then
        log_success "startup.sh encontrado"
    else
        log_error "startup.sh NO encontrado"
    fi
    
    if [[ -f "/opt/tomcat/bin/shutdown.sh" ]]; then
        log_success "shutdown.sh encontrado"
    else
        log_error "shutdown.sh NO encontrado"
    fi
    
    # Verificar permisos
    TOMCAT_OWNER=$(stat -c '%U:%G' /opt/tomcat)
    if [[ "$TOMCAT_OWNER" == "tomcat:tomcat" ]]; then
        log_success "Permisos de propietario correctos: $TOMCAT_OWNER"
    else
        log_error "Permisos incorrectos: $TOMCAT_OWNER (debería ser tomcat:tomcat)"
    fi
else
    log_error "Directorio /opt/tomcat NO existe"
fi

# 7. Verificar archivo de servicio systemd
log_info "Verificando servicio systemd..."
SERVICE_FILE="/etc/systemd/system/tomcat.service"
if [[ -f "$SERVICE_FILE" ]]; then
    log_success "Archivo de servicio existe: $SERVICE_FILE"
    
    # Verificar contenido crítico
    if grep -q "ExecStart=/opt/tomcat/bin/startup.sh" "$SERVICE_FILE"; then
        log_success "ExecStart configurado correctamente"
    else
        log_error "ExecStart NO configurado correctamente"
    fi
    
    if grep -q "User=tomcat" "$SERVICE_FILE"; then
        log_success "Usuario del servicio configurado correctamente"
    else
        log_error "Usuario del servicio NO configurado"
    fi
    
    # Mostrar JAVA_HOME del servicio
    JAVA_HOME_SERVICE=$(grep "Environment=JAVA_HOME=" "$SERVICE_FILE" | cut -d'=' -f3)
    if [[ -n "$JAVA_HOME_SERVICE" ]]; then
        log_success "JAVA_HOME en servicio: $JAVA_HOME_SERVICE"
        if [[ -d "$JAVA_HOME_SERVICE" ]]; then
            log_success "Directorio JAVA_HOME existe"
        else
            log_error "Directorio JAVA_HOME NO existe: $JAVA_HOME_SERVICE"
        fi
    else
        log_error "JAVA_HOME no configurado en el servicio"
    fi
else
    log_error "Archivo de servicio NO existe: $SERVICE_FILE"
fi

# 8. Verificar estado del servicio
log_info "Verificando estado del servicio..."
if systemctl list-unit-files | grep -q "tomcat.service"; then
    log_success "Servicio tomcat.service registrado en systemd"
    
    # Estado del servicio
    SERVICE_STATUS=$(systemctl is-active tomcat 2>/dev/null || echo "inactive")
    if [[ "$SERVICE_STATUS" == "active" ]]; then
        log_success "Servicio está ACTIVO"
    else
        log_error "Servicio está INACTIVO: $SERVICE_STATUS"
    fi
    
    # ¿Está habilitado?
    if systemctl is-enabled tomcat >/dev/null 2>&1; then
        log_success "Servicio está HABILITADO para inicio automático"
    else
        log_error "Servicio NO está habilitado para inicio automático"
    fi
else
    log_error "Servicio tomcat.service NO está registrado en systemd"
fi

# 9. Verificar procesos
log_info "Verificando procesos de Tomcat..."
TOMCAT_PROCESSES=$(ps aux | grep -E '[t]omcat|[j]ava.*catalina' | grep -v grep)
if [[ -n "$TOMCAT_PROCESSES" ]]; then
    log_success "Procesos de Tomcat encontrados:"
    echo "$TOMCAT_PROCESSES"
else
    log_error "No se encontraron procesos de Tomcat ejecutándose"
fi

# 10. Verificar puerto 8080
log_info "Verificando puerto 8080..."
if command -v ss >/dev/null 2>&1; then
    PORT_CHECK=$(ss -tlnp | grep ":8080")
else
    PORT_CHECK=$(netstat -tlnp | grep ":8080")
fi

if [[ -n "$PORT_CHECK" ]]; then
    log_success "Puerto 8080 en uso:"
    echo "$PORT_CHECK"
else
    log_error "Puerto 8080 NO está en uso"
fi

# 11. Verificar logs recientes
log_info "Verificando logs recientes..."
if journalctl -u tomcat --no-pager -n 5 >/dev/null 2>&1; then
    log_success "Logs del servicio disponibles:"
    journalctl -u tomcat --no-pager -n 5
else
    log_error "No se pudieron obtener logs del servicio"
fi

echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                        RESUMEN"
echo "═══════════════════════════════════════════════════════════════════"

# Determinar estado general
ERROR_COUNT=0

# Verificaciones críticas
if ! command -v java >/dev/null 2>&1; then
    ((ERROR_COUNT++))
fi

if ! id "tomcat" &>/dev/null; then
    ((ERROR_COUNT++))
fi

if [[ ! -d "/opt/tomcat" ]]; then
    ((ERROR_COUNT++))
fi

if [[ ! -f "/etc/systemd/system/tomcat.service" ]]; then
    ((ERROR_COUNT++))
fi

if ! systemctl list-unit-files | grep -q "tomcat.service"; then
    ((ERROR_COUNT++))
fi

if [[ $ERROR_COUNT -eq 0 ]]; then
    log_success "CONFIGURACIÓN BÁSICA CORRECTA"
    
    SERVICE_STATUS=$(systemctl is-active tomcat 2>/dev/null || echo "inactive")
    if [[ "$SERVICE_STATUS" == "active" ]]; then
        log_success "TOMCAT FUNCIONANDO CORRECTAMENTE"
    else
        log_error "TOMCAT CONFIGURADO PERO NO EJECUTÁNDOSE"
        echo
        echo "COMANDOS PARA INICIAR:"
        echo "sudo systemctl start tomcat"
        echo "sudo systemctl status tomcat"
    fi
else
    log_error "ENCONTRADOS $ERROR_COUNT PROBLEMAS CRÍTICOS"
    echo
    echo "EJECUTAR PARA CORREGIR:"
    echo "sudo ./clean-tomcat-install.sh"
fi

echo
echo "COMANDOS ÚTILES:"
echo "sudo systemctl status tomcat -l    # Estado detallado"
echo "sudo journalctl -u tomcat -f       # Logs en tiempo real"
echo "sudo systemctl restart tomcat      # Reiniciar servicio"
echo "ps aux | grep tomcat               # Ver procesos"
echo "ss -tlnp | grep 8080               # Verificar puerto"

echo
echo "═══════════════════════════════════════════════════════════════════"