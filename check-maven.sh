#!/bin/bash

# Script para verificar y configurar Maven
# Autor: Sistema de Despliegue PDF Signer
# Fecha: $(date '+%Y-%m-%d')

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}✗ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠ $1${NC}"
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ $1${NC}"
}

# Verificar si se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

# Verificar Maven
check_maven() {
    log_info "Verificando instalación de Maven..."
    
    if command -v mvn >/dev/null 2>&1; then
        MAVEN_VERSION=$(mvn -version | head -n 1)
        log_success "Maven está instalado: $MAVEN_VERSION"
        
        # Verificar JAVA_HOME para Maven
        if mvn -version | grep -q "Java home:"; then
            JAVA_HOME_MAVEN=$(mvn -version | grep "Java home:" | cut -d: -f2 | xargs)
            log_success "Java home para Maven: $JAVA_HOME_MAVEN"
        fi
        
        return 0
    else
        log_error "Maven no está instalado"
        return 1
    fi
}

# Instalar Maven
install_maven() {
    log_info "Instalando Maven..."
    
    # Detectar el gestor de paquetes
    if command -v dnf >/dev/null 2>&1; then
        log_info "Usando DNF para instalar Maven..."
        if dnf install maven -y; then
            log_success "Maven instalado exitosamente con DNF"
        else
            log_error "Error instalando Maven con DNF"
            return 1
        fi
    elif command -v yum >/dev/null 2>&1; then
        log_info "Usando YUM para instalar Maven..."
        if yum install maven -y; then
            log_success "Maven instalado exitosamente con YUM"
        else
            log_error "Error instalando Maven con YUM"
            return 1
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        log_info "Usando APT para instalar Maven..."
        if apt-get update && apt-get install maven -y; then
            log_success "Maven instalado exitosamente con APT"
        else
            log_error "Error instalando Maven con APT"
            return 1
        fi
    else
        log_error "No se pudo detectar un gestor de paquetes compatible"
        log_info "Gestores soportados: dnf, yum, apt-get"
        return 1
    fi
    
    return 0
}

# Verificar Java para Maven
check_java_for_maven() {
    log_info "Verificando Java para Maven..."
    
    if command -v java >/dev/null 2>&1; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        log_success "Java está disponible: $JAVA_VERSION"
        
        # Verificar JAVA_HOME
        if [[ -n "$JAVA_HOME" ]]; then
            log_success "JAVA_HOME está configurado: $JAVA_HOME"
        else
            log_warning "JAVA_HOME no está configurado"
            
            # Intentar detectar JAVA_HOME
            JAVA_PATH=$(which java)
            if [[ -n "$JAVA_PATH" ]]; then
                # Seguir enlaces simbólicos
                REAL_JAVA_PATH=$(readlink -f "$JAVA_PATH")
                # Obtener el directorio padre dos veces (bin -> jre/jdk)
                DETECTED_JAVA_HOME=$(dirname "$(dirname "$REAL_JAVA_PATH")")
                
                if [[ -d "$DETECTED_JAVA_HOME" ]]; then
                    log_info "JAVA_HOME detectado: $DETECTED_JAVA_HOME"
                    export JAVA_HOME="$DETECTED_JAVA_HOME"
                    log_success "JAVA_HOME configurado temporalmente"
                fi
            fi
        fi
        
        return 0
    else
        log_error "Java no está instalado"
        return 1
    fi
}

# Probar compilación
test_maven_compilation() {
    log_info "Probando compilación con Maven..."
    
    # Detectar directorio del proyecto
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [[ ! -f "$SCRIPT_DIR/pom.xml" ]]; then
        log_error "No se encontró pom.xml en $SCRIPT_DIR"
        log_info "Este script debe ejecutarse desde el directorio del proyecto"
        return 1
    fi
    
    # Cambiar al directorio del proyecto
    cd "$SCRIPT_DIR" || {
        log_error "No se pudo acceder al directorio del proyecto"
        return 1
    }
    
    log_info "Ejecutando: mvn clean compile -DskipTests"
    if mvn clean compile -DskipTests; then
        log_success "Compilación de prueba exitosa"
        return 0
    else
        log_error "Error en la compilación de prueba"
        return 1
    fi
}

# Función principal
main() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    VERIFICACIÓN DE MAVEN"
    echo "                   PDF Signer - Herramientas"
    echo "═══════════════════════════════════════════════════════════════════"
    echo
    
    check_root
    
    # Verificar Java primero
    if ! check_java_for_maven; then
        log_error "Java es requerido para Maven"
        log_info "Instalar Java primero: sudo apt-get install openjdk-11-jdk (Ubuntu/Debian)"
        log_info "                      sudo yum install java-11-openjdk-devel (CentOS/RHEL)"
        exit 1
    fi
    
    # Verificar Maven
    if ! check_maven; then
        log_warning "Maven no está instalado, procediendo con la instalación..."
        if ! install_maven; then
            log_error "No se pudo instalar Maven"
            exit 1
        fi
        
        # Verificar nuevamente después de la instalación
        if ! check_maven; then
            log_error "Maven no se instaló correctamente"
            exit 1
        fi
    fi
    
    # Probar compilación
    if test_maven_compilation; then
        log_success "Maven está configurado correctamente y puede compilar el proyecto"
    else
        log_warning "Maven está instalado pero hay problemas con la compilación"
        log_info "Verificar dependencias y configuración del proyecto"
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                        RESUMEN"
    echo "═══════════════════════════════════════════════════════════════════"
    
    # Mostrar información final
    if command -v mvn >/dev/null 2>&1; then
        echo "✓ Maven: $(mvn -version | head -n 1)"
    fi
    
    if command -v java >/dev/null 2>&1; then
        echo "✓ Java: $(java -version 2>&1 | head -n 1)"
    fi
    
    if [[ -n "$JAVA_HOME" ]]; then
        echo "✓ JAVA_HOME: $JAVA_HOME"
    fi
    
    echo
    echo "COMANDOS ÚTILES:"
    echo "• Verificar Maven: mvn -version"
    echo "• Compilar proyecto: mvn clean package"
    echo "• Compilar sin tests: mvn clean package -DskipTests"
    echo "• Limpiar proyecto: mvn clean"
    echo "• Ver dependencias: mvn dependency:tree"
    
    echo
    echo "SIGUIENTE PASO:"
    echo "Ejecutar: ./clean-tomcat-install.sh"
}

# Ejecutar función principal
main "$@"