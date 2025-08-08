#!/bin/bash

# Script para gestionar instancias de Tomcat
# PDF Validator API - Gestión de Tomcat

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para mostrar ayuda
show_help() {
    echo -e "${PURPLE}=== GESTOR DE INSTANCIAS DE TOMCAT ===${NC}"
    echo -e "${BLUE}Uso: $0 [OPCIÓN]${NC}"
    echo ""
    echo -e "${YELLOW}Opciones:${NC}"
    echo -e "  ${GREEN}status${NC}     - Mostrar estado de todas las instancias de Tomcat"
    echo -e "  ${GREEN}list${NC}       - Listar todos los procesos Java/Tomcat"
    echo -e "  ${GREEN}stop-all${NC}   - Detener todas las instancias de Tomcat"
    echo -e "  ${GREEN}stop-others${NC} - Detener instancias que no sean la principal"
    echo -e "  ${GREEN}start${NC}      - Iniciar la instancia principal de Tomcat"
    echo -e "  ${GREEN}restart${NC}    - Reiniciar la instancia principal"
    echo -e "  ${GREEN}clean${NC}      - Limpiar instancias duplicadas y reiniciar"
    echo -e "  ${GREEN}ports${NC}      - Verificar puertos en uso"
    echo -e "  ${GREEN}help${NC}       - Mostrar esta ayuda"
    echo ""
    echo -e "${BLUE}Ejemplos:${NC}"
    echo -e "  ${YELLOW}$0 status${NC}      # Ver estado actual"
    echo -e "  ${YELLOW}$0 clean${NC}       # Limpiar y reiniciar"
    echo -e "  ${YELLOW}$0 stop-others${NC} # Detener solo instancias duplicadas"
}

# Función para verificar permisos
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

# Función para obtener información de procesos Tomcat
get_tomcat_processes() {
    ps aux | grep -E '[t]omcat|[j]ava.*catalina' | grep -v grep
}

# Función para contar procesos Tomcat
count_tomcat_processes() {
    get_tomcat_processes | wc -l
}

# Función para mostrar estado
show_status() {
    log_info "Verificando estado de Tomcat..."
    
    TOMCAT_PROCESSES=$(get_tomcat_processes)
    TOMCAT_COUNT=$(count_tomcat_processes)
    
    echo -e "\n${PURPLE}=== ESTADO DE INSTANCIAS DE TOMCAT ===${NC}"
    
    if [ "$TOMCAT_COUNT" -eq 0 ]; then
        log_warn "No se encontraron procesos de Tomcat ejecutándose"
        
        # Verificar si el servicio está configurado
        if systemctl list-unit-files | grep -q tomcat; then
            SERVICE_STATUS=$(systemctl is-active tomcat 2>/dev/null || echo "inactive")
            log_info "Estado del servicio tomcat: $SERVICE_STATUS"
            
            if [ "$SERVICE_STATUS" = "inactive" ]; then
                log_info "Puedes iniciar Tomcat con: sudo systemctl start tomcat"
            fi
        else
            log_info "Servicio tomcat no está configurado"
        fi
        
    elif [ "$TOMCAT_COUNT" -eq 1 ]; then
        log_success "Solo una instancia de Tomcat ejecutándose (correcto)"
        echo -e "${GREEN}Proceso:${NC}"
        echo "$TOMCAT_PROCESSES" | while read line; do
            PID=$(echo "$line" | awk '{print $2}')
            USER=$(echo "$line" | awk '{print $1}')
            CPU=$(echo "$line" | awk '{print $3}')
            MEM=$(echo "$line" | awk '{print $4}')
            COMMAND=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
            
            echo -e "  ${BLUE}PID:${NC} $PID | ${BLUE}Usuario:${NC} $USER | ${BLUE}CPU:${NC} $CPU% | ${BLUE}Memoria:${NC} $MEM%"
            echo -e "  ${BLUE}Comando:${NC} $(echo "$COMMAND" | cut -c1-80)..."
        done
        
    else
        log_warn "Se encontraron múltiples instancias de Tomcat ($TOMCAT_COUNT)"
        echo -e "${YELLOW}Procesos:${NC}"
        echo "$TOMCAT_PROCESSES" | nl -w2 -s'. ' | while read line; do
            echo -e "  ${YELLOW}$line${NC}"
        done
        
        log_warn "Múltiples instancias pueden causar:"
        echo -e "  ${RED}• Conflictos de puerto${NC}"
        echo -e "  ${RED}• Consumo excesivo de memoria${NC}"
        echo -e "  ${RED}• Comportamiento impredecible${NC}"
        echo ""
        log_info "Usa '$0 clean' para resolver automáticamente"
    fi
    
    # Verificar puertos
    echo -e "\n${PURPLE}=== PUERTOS EN USO ===${NC}"
    check_ports
}

# Función para listar procesos Java
list_java_processes() {
    log_info "Listando todos los procesos Java..."
    
    JAVA_PROCESSES=$(ps aux | grep '[j]ava' | grep -v grep)
    
    if [ -z "$JAVA_PROCESSES" ]; then
        log_warn "No se encontraron procesos Java ejecutándose"
    else
        echo -e "\n${PURPLE}=== PROCESOS JAVA ===${NC}"
        echo "$JAVA_PROCESSES" | nl -w2 -s'. ' | while read line; do
            echo -e "  ${BLUE}$line${NC}"
        done
    fi
}

# Función para verificar puertos
check_ports() {
    PORTS=("8080" "8443" "8005" "8009")
    
    for PORT in "${PORTS[@]}"; do
        PORT_INFO=$(netstat -tlnp 2>/dev/null | grep ":$PORT " || echo "")
        if [ -n "$PORT_INFO" ]; then
            PID=$(echo "$PORT_INFO" | awk '{print $7}' | cut -d'/' -f1)
            PROCESS=$(echo "$PORT_INFO" | awk '{print $7}' | cut -d'/' -f2)
            log_success "Puerto $PORT en uso por PID $PID ($PROCESS)"
        else
            log_warn "Puerto $PORT libre"
        fi
    done
}

# Función para detener todas las instancias
stop_all_tomcat() {
    log_info "Deteniendo todas las instancias de Tomcat..."
    
    # Detener servicio si existe
    if systemctl list-unit-files | grep -q tomcat; then
        log_info "Deteniendo servicio tomcat..."
        systemctl stop tomcat 2>/dev/null || true
    fi
    
    # Obtener PIDs de procesos Tomcat
    TOMCAT_PIDS=$(get_tomcat_processes | awk '{print $2}')
    
    if [ -z "$TOMCAT_PIDS" ]; then
        log_success "No hay instancias de Tomcat ejecutándose"
        return 0
    fi
    
    # Intentar detener gracefully
    log_info "Enviando señal TERM a procesos Tomcat..."
    for PID in $TOMCAT_PIDS; do
        if kill -TERM "$PID" 2>/dev/null; then
            log_info "Señal TERM enviada a PID $PID"
        fi
    done
    
    # Esperar un momento
    sleep 5
    
    # Verificar si siguen ejecutándose
    REMAINING_PIDS=$(get_tomcat_processes | awk '{print $2}')
    
    if [ -n "$REMAINING_PIDS" ]; then
        log_warn "Algunos procesos siguen ejecutándose. Forzando terminación..."
        for PID in $REMAINING_PIDS; do
            if kill -KILL "$PID" 2>/dev/null; then
                log_info "Proceso $PID terminado forzosamente"
            fi
        done
        sleep 2
    fi
    
    # Verificación final
    FINAL_COUNT=$(count_tomcat_processes)
    if [ "$FINAL_COUNT" -eq 0 ]; then
        log_success "Todas las instancias de Tomcat han sido detenidas"
    else
        log_error "Aún quedan $FINAL_COUNT instancias ejecutándose"
        get_tomcat_processes
    fi
}

# Función para detener solo instancias adicionales
stop_other_instances() {
    log_info "Deteniendo instancias adicionales de Tomcat..."
    
    TOMCAT_PROCESSES=$(get_tomcat_processes)
    TOMCAT_COUNT=$(count_tomcat_processes)
    
    if [ "$TOMCAT_COUNT" -le 1 ]; then
        log_success "Solo hay una instancia o ninguna ejecutándose"
        return 0
    fi
    
    # Identificar la instancia principal (la del servicio systemd)
    MAIN_PID=""
    if systemctl list-unit-files | grep -q tomcat; then
        MAIN_PID=$(systemctl show tomcat --property=MainPID 2>/dev/null | cut -d'=' -f2)
        if [ "$MAIN_PID" = "0" ] || [ -z "$MAIN_PID" ]; then
            MAIN_PID=""
        fi
    fi
    
    # Si no hay PID principal, mantener el primer proceso
    if [ -z "$MAIN_PID" ]; then
        MAIN_PID=$(echo "$TOMCAT_PROCESSES" | head -1 | awk '{print $2}')
        log_info "No se encontró PID del servicio. Manteniendo PID $MAIN_PID"
    else
        log_info "PID principal del servicio: $MAIN_PID"
    fi
    
    # Detener otros procesos
    echo "$TOMCAT_PROCESSES" | while read line; do
        PID=$(echo "$line" | awk '{print $2}')
        if [ "$PID" != "$MAIN_PID" ]; then
            log_info "Deteniendo instancia adicional PID $PID..."
            if kill -TERM "$PID" 2>/dev/null; then
                sleep 2
                if kill -0 "$PID" 2>/dev/null; then
                    log_warn "Forzando terminación de PID $PID"
                    kill -KILL "$PID" 2>/dev/null || true
                fi
                log_success "Instancia PID $PID detenida"
            else
                log_warn "No se pudo detener PID $PID"
            fi
        fi
    done
}

# Función para iniciar Tomcat
start_tomcat() {
    log_info "Iniciando Tomcat..."
    
    # Verificar que no haya instancias ejecutándose
    CURRENT_COUNT=$(count_tomcat_processes)
    if [ "$CURRENT_COUNT" -gt 0 ]; then
        log_warn "Ya hay $CURRENT_COUNT instancia(s) ejecutándose"
        show_status
        return 1
    fi
    
    # Iniciar servicio si está configurado
    if systemctl list-unit-files | grep -q tomcat; then
        log_info "Iniciando servicio tomcat..."
        if systemctl start tomcat; then
            log_success "Servicio tomcat iniciado"
            sleep 3
            show_status
        else
            log_error "Error al iniciar servicio tomcat"
            return 1
        fi
    else
        log_error "Servicio tomcat no está configurado"
        log_info "Configura el servicio o inicia Tomcat manualmente"
        return 1
    fi
}

# Función para reiniciar Tomcat
restart_tomcat() {
    log_info "Reiniciando Tomcat..."
    
    stop_all_tomcat
    sleep 2
    start_tomcat
}

# Función para limpiar y reiniciar
clean_and_restart() {
    log_info "Limpiando instancias duplicadas y reiniciando..."
    
    echo -e "${YELLOW}Esta operación:${NC}"
    echo -e "  ${BLUE}1. Detendrá todas las instancias de Tomcat${NC}"
    echo -e "  ${BLUE}2. Limpiará archivos temporales${NC}"
    echo -e "  ${BLUE}3. Iniciará una sola instancia limpia${NC}"
    echo ""
    
    read -p "¿Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operación cancelada"
        return 0
    fi
    
    # Detener todas las instancias
    stop_all_tomcat
    
    # Limpiar archivos temporales
    log_info "Limpiando archivos temporales..."
    if [ -d "/opt/tomcat/temp" ]; then
        rm -rf /opt/tomcat/temp/*
        log_success "Directorio temp limpiado"
    fi
    
    if [ -d "/opt/tomcat/work" ]; then
        rm -rf /opt/tomcat/work/*
        log_success "Directorio work limpiado"
    fi
    
    # Verificar puertos libres
    sleep 2
    log_info "Verificando que los puertos estén libres..."
    check_ports
    
    # Iniciar Tomcat
    sleep 1
    start_tomcat
}

# Función principal
main() {
    case "${1:-help}" in
        "status")
            show_status
            ;;
        "list")
            list_java_processes
            ;;
        "stop-all")
            check_permissions
            stop_all_tomcat
            ;;
        "stop-others")
            check_permissions
            stop_other_instances
            ;;
        "start")
            check_permissions
            start_tomcat
            ;;
        "restart")
            check_permissions
            restart_tomcat
            ;;
        "clean")
            check_permissions
            clean_and_restart
            ;;
        "ports")
            check_ports
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Opción no válida: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"