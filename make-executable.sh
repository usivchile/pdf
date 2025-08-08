#!/bin/bash

# Script para hacer ejecutables todos los scripts del proyecto
# PDF Validator API - Configuración de permisos

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Función de logging
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

echo -e "${PURPLE}=== CONFIGURADOR DE PERMISOS DE SCRIPTS ===${NC}"
echo -e "${BLUE}Este script hará ejecutables todos los scripts .sh del proyecto${NC}"
echo ""

# Lista de scripts del proyecto
SCRIPTS=(
    "deploy-local.sh"
    "update-local.sh"
    "deploy-from-git.sh"
    "update-from-git.sh"
    "configure-git-repo.sh"
    "configure-nginx.sh"
    "check-deployment.sh"
    "troubleshoot.sh"
    "help.sh"
    "manage-tomcat.sh"
    "fix-deployment-error.sh"
    "make-executable.sh"
    "install-vps.sh"
    "deploy-complete.sh"
    "security-hardening.sh"
)

log_info "Verificando y configurando permisos de scripts..."
echo ""

# Contador de archivos procesados
PROCESSED=0
MADE_EXECUTABLE=0
NOT_FOUND=0

# Procesar cada script
for SCRIPT in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT" ]; then
        # Verificar permisos actuales
        CURRENT_PERMS=$(stat -c "%a" "$SCRIPT" 2>/dev/null || echo "000")
        
        # Hacer ejecutable
        chmod +x "$SCRIPT"
        
        if [ $? -eq 0 ]; then
            NEW_PERMS=$(stat -c "%a" "$SCRIPT" 2>/dev/null || echo "000")
            
            if [ "$CURRENT_PERMS" != "$NEW_PERMS" ]; then
                log_success "$SCRIPT - Permisos cambiados: $CURRENT_PERMS → $NEW_PERMS"
                ((MADE_EXECUTABLE++))
            else
                log_info "$SCRIPT - Ya era ejecutable ($CURRENT_PERMS)"
            fi
        else
            log_error "$SCRIPT - Error al cambiar permisos"
        fi
        
        ((PROCESSED++))
    else
        log_warn "$SCRIPT - Archivo no encontrado"
        ((NOT_FOUND++))
    fi
done

echo ""
echo -e "${PURPLE}=== RESUMEN ===${NC}"
echo -e "${GREEN}Archivos procesados: $PROCESSED${NC}"
echo -e "${GREEN}Hechos ejecutables: $MADE_EXECUTABLE${NC}"
echo -e "${YELLOW}No encontrados: $NOT_FOUND${NC}"

# Verificar permisos finales
echo ""
log_info "Verificando permisos finales..."
echo -e "${BLUE}Archivo${NC}\t\t\t${BLUE}Permisos${NC}\t${BLUE}Estado${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"

for SCRIPT in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT" ]; then
        PERMS=$(stat -c "%a" "$SCRIPT" 2>/dev/null || echo "000")
        if [ -x "$SCRIPT" ]; then
            STATUS="${GREEN}✓ Ejecutable${NC}"
        else
            STATUS="${RED}✗ No ejecutable${NC}"
        fi
        printf "%-25s\t%s\t%s\n" "$SCRIPT" "$PERMS" "$STATUS"
    fi
done

echo ""
echo -e "${GREEN}=== CONFIGURACIÓN COMPLETADA ===${NC}"
echo -e "${BLUE}Ahora puedes ejecutar cualquier script con:${NC}"
echo -e "${YELLOW}  ./nombre-del-script.sh${NC}"
echo ""
echo -e "${BLUE}Ejemplos:${NC}"
echo -e "${YELLOW}  ./deploy-local.sh${NC}      # Despliegue local"
echo -e "${YELLOW}  ./update-local.sh${NC}      # Actualización local"
echo -e "${YELLOW}  ./check-deployment.sh${NC}  # Verificar estado"
echo -e "${YELLOW}  ./help.sh${NC}              # Ayuda interactiva"

log_success "Todos los scripts están listos para usar!"