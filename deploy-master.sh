#!/bin/bash

# Script Maestro de Despliegue
# Ejecuta todo el proceso de despliegue de manera automatizada

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuración
PROJECT_DIR="/opt/pdf-signer/pdf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    PDF SIGNER DEPLOYMENT                    ║${NC}"
echo -e "${PURPLE}║                     Script Maestro v1.0                    ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Función para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verificar que estamos ejecutando como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root"
    exit 1
fi

# Verificar que el directorio del proyecto existe
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "El directorio del proyecto no existe: $PROJECT_DIR"
    log_info "Creando directorio del proyecto..."
    mkdir -p "$PROJECT_DIR"
    log_warn "Directorio creado. Necesitas clonar el repositorio primero:"
    echo "  cd $PROJECT_DIR"
    echo "  git clone <URL_DEL_REPOSITORIO> ."
    exit 1
fi

cd "$PROJECT_DIR"

# Mostrar información del sistema
echo -e "${BLUE}Información del sistema:${NC}"
echo "  - Fecha: $(date)"
echo "  - Usuario: $(whoami)"
echo "  - Directorio: $(pwd)"
echo "  - Rama actual: $(git branch --show-current 2>/dev/null || echo 'No disponible')"
echo "  - Último commit: $(git log -1 --oneline 2>/dev/null || echo 'No disponible')"
echo ""

# Confirmar antes de proceder
read -p "¿Continuar con el despliegue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Despliegue cancelado por el usuario"
    exit 0
fi

echo ""
log_step "PASO 1: Limpieza del servidor"
echo "────────────────────────────────────────"

# Ejecutar script de limpieza si existe
if [ -f "cleanup-production.sh" ]; then
    chmod +x cleanup-production.sh
    ./cleanup-production.sh
else
    log_warn "Script de limpieza no encontrado, continuando..."
fi

echo ""
log_step "PASO 2: Actualización del código"
echo "────────────────────────────────────────"

# Verificar estado de Git
if [ -d ".git" ]; then
    log_info "Verificando estado de Git..."
    
    # Mostrar cambios locales si los hay
    if ! git diff-index --quiet HEAD --; then
        log_warn "Hay cambios locales no confirmados:"
        git status --porcelain
        echo ""
        read -p "¿Descartar cambios locales y continuar? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git reset --hard HEAD
            git clean -fd
            log_info "Cambios locales descartados"
        else
            log_error "Despliegue cancelado. Confirma o descarta los cambios locales primero."
            exit 1
        fi
    fi
    
    # Hacer git pull
    log_info "Actualizando código desde Git..."
    git pull origin main || git pull origin master || {
        log_error "Error al hacer git pull"
        exit 1
    }
    
    log_info "Código actualizado exitosamente"
else
    log_error "No es un repositorio Git válido"
    exit 1
fi

echo ""
log_step "PASO 3: Configuración de permisos"
echo "────────────────────────────────────────"

# Otorgar permisos a scripts
log_info "Otorgando permisos de ejecución a scripts .sh..."
find . -name "*.sh" -type f -exec chmod +x {} \;
SCRIPT_COUNT=$(find . -name "*.sh" -type f | wc -l)
log_info "Permisos otorgados a $SCRIPT_COUNT archivos .sh"

echo ""
log_step "PASO 4: Despliegue de la aplicación"
echo "────────────────────────────────────────"

# Ejecutar script de despliegue
if [ -f "deploy-production.sh" ]; then
    chmod +x deploy-production.sh
    ./deploy-production.sh
else
    log_error "Script de despliegue no encontrado: deploy-production.sh"
    exit 1
fi

echo ""
log_step "PASO 5: Verificación final"
echo "────────────────────────────────────────"

# Verificaciones finales
log_info "Realizando verificaciones finales..."

# Verificar servicio
if systemctl is-active --quiet pdf-signer; then
    log_info "✓ Servicio pdf-signer está ejecutándose"
else
    log_error "✗ Servicio pdf-signer no está ejecutándose"
fi

# Verificar health check local
if curl -s http://localhost:8080/usiv-pdf-api/actuator/health | grep -q '"status":"UP"'; then
    log_info "✓ Health check local exitoso"
else
    log_warn "✗ Health check local falló"
fi

# Verificar acceso público
if curl -s -k https://validador.usiv.cl/pdf-signer/actuator/health | grep -q '"status":"UP"'; then
    log_info "✓ Acceso público verificado"
else
    log_warn "✗ Acceso público falló"
fi

# Verificar nginx
if systemctl is-active --quiet nginx; then
    log_info "✓ Nginx está ejecutándose"
else
    log_warn "✗ Nginx no está ejecutándose"
fi

echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    DESPLIEGUE COMPLETADO                    ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🎉 ¡Despliegue completado exitosamente!${NC}"
echo ""
echo -e "${BLUE}URLs de acceso:${NC}"
echo "  • Health Check: https://validador.usiv.cl/pdf-signer/actuator/health"
echo "  • API Principal: https://validador.usiv.cl/pdf-signer/api/sign"
echo "  • Documentación: https://validador.usiv.cl/pdf-signer/swagger-ui.html"
echo ""
echo -e "${YELLOW}Comandos útiles:${NC}"
echo "  • Ver logs: journalctl -u pdf-signer -f"
echo "  • Estado: systemctl status pdf-signer"
echo "  • Reiniciar: systemctl restart pdf-signer"
echo ""
echo -e "${BLUE}Información del despliegue:${NC}"
echo "  • Fecha: $(date)"
echo "  • Commit: $(git log -1 --oneline)"
echo "  • Rama: $(git branch --show-current)"
echo ""