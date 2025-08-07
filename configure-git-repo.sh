#!/bin/bash

# Script para configurar la URL del repositorio Git en todos los scripts de despliegue
# Facilita la personalización antes del primer despliegue

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
echo "           CONFIGURADOR DE REPOSITORIO GIT - PDF VALIDATOR         "
echo "                    Personalización de Scripts                     "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Variables por defecto
DEFAULT_REPO="https://github.com/tu-usuario/pdf-validator-api.git"
DEFAULT_BRANCH="main"
DEFAULT_DOMAIN="validador.usiv.cl"
DEFAULT_EMAIL="admin@usiv.cl"

# Scripts a modificar
SCRIPTS=(
    "deploy-from-git.sh"
    "deploy-complete.sh"
    "update-from-git.sh"
)

# Función para solicitar información
get_configuration() {
    echo -e "\n${YELLOW}📋 CONFIGURACIÓN DEL REPOSITORIO GIT${NC}"
    echo -e "${GREEN}Por favor, proporciona la información de tu repositorio:${NC}\n"
    
    # URL del repositorio
    echo -e "${BLUE}1. URL del Repositorio Git${NC}"
    echo -e "${GREEN}Ejemplos válidos:${NC}"
    echo -e "${GREEN}  - https://github.com/usuario/repositorio.git${NC}"
    echo -e "${GREEN}  - git@github.com:usuario/repositorio.git${NC}"
    echo -e "${GREEN}  - https://gitlab.com/usuario/repositorio.git${NC}"
    echo -e "${GREEN}  - https://bitbucket.org/usuario/repositorio.git${NC}"
    
    read -p "\nIngresa la URL de tu repositorio Git: " GIT_REPO
    
    if [ -z "$GIT_REPO" ]; then
        error "La URL del repositorio es obligatoria"
    fi
    
    # Validar formato básico de URL
    if [[ ! "$GIT_REPO" =~ ^(https?://|git@) ]]; then
        error "URL de repositorio inválida. Debe comenzar con https:// o git@"
    fi
    
    success "Repositorio configurado: $GIT_REPO"
    
    # Rama
    echo -e "\n${BLUE}2. Rama del Repositorio${NC}"
    read -p "Ingresa la rama a usar (default: main): " GIT_BRANCH
    
    if [ -z "$GIT_BRANCH" ]; then
        GIT_BRANCH="$DEFAULT_BRANCH"
    fi
    
    success "Rama configurada: $GIT_BRANCH"
    
    # Dominio
    echo -e "\n${BLUE}3. Dominio de la Aplicación${NC}"
    echo -e "${GREEN}Ejemplo: midominio.com, api.miempresa.com${NC}"
    read -p "Ingresa tu dominio: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        DOMAIN="$DEFAULT_DOMAIN"
        warn "Usando dominio por defecto: $DOMAIN"
    fi
    
    success "Dominio configurado: $DOMAIN"
    
    # Email para SSL
    echo -e "\n${BLUE}4. Email para Certificados SSL${NC}"
    echo -e "${GREEN}Se usará para registrar certificados Let's Encrypt${NC}"
    read -p "Ingresa tu email: " EMAIL
    
    if [ -z "$EMAIL" ]; then
        EMAIL="$DEFAULT_EMAIL"
        warn "Usando email por defecto: $EMAIL"
    fi
    
    success "Email configurado: $EMAIL"
}

# Función para mostrar resumen
show_summary() {
    echo -e "\n${YELLOW}📋 RESUMEN DE CONFIGURACIÓN${NC}"
    echo -e "${GREEN}  Repositorio Git: $GIT_REPO${NC}"
    echo -e "${GREEN}  Rama: $GIT_BRANCH${NC}"
    echo -e "${GREEN}  Dominio: $DOMAIN${NC}"
    echo -e "${GREEN}  Email SSL: $EMAIL${NC}"
    echo -e "${GREEN}  Scripts a modificar: ${#SCRIPTS[@]}${NC}\n"
}

# Función para solicitar confirmación
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Función para hacer backup de scripts
backup_scripts() {
    log "Creando backup de scripts originales..."
    
    BACKUP_DIR="./scripts-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            cp "$script" "$BACKUP_DIR/"
            success "Backup creado: $script"
        else
            warn "Script no encontrado: $script"
        fi
    done
    
    success "Backup completo en: $BACKUP_DIR"
}

# Función para actualizar scripts
update_scripts() {
    log "Actualizando scripts con la nueva configuración..."
    
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            info "Actualizando $script..."
            
            # Actualizar URL del repositorio
            sed -i "s|GIT_REPO=\".*\"|GIT_REPO=\"$GIT_REPO\"|g" "$script"
            
            # Actualizar rama
            sed -i "s|GIT_BRANCH=\".*\"|GIT_BRANCH=\"$GIT_BRANCH\"|g" "$script"
            
            # Actualizar dominio
            sed -i "s|DOMAIN=\".*\"|DOMAIN=\"$DOMAIN\"|g" "$script"
            
            # Actualizar email
            sed -i "s|EMAIL=\".*\"|EMAIL=\"$EMAIL\"|g" "$script"
            
            success "$script actualizado"
        else
            warn "Script no encontrado: $script"
        fi
    done
}

# Función para verificar cambios
verify_changes() {
    log "Verificando cambios aplicados..."
    
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            info "Verificando $script:"
            
            # Verificar que se aplicaron los cambios
            if grep -q "$GIT_REPO" "$script"; then
                echo -e "${GREEN}  ✓ Repositorio actualizado${NC}"
            else
                echo -e "${RED}  ✗ Error: Repositorio no actualizado${NC}"
            fi
            
            if grep -q "$GIT_BRANCH" "$script"; then
                echo -e "${GREEN}  ✓ Rama actualizada${NC}"
            else
                echo -e "${RED}  ✗ Error: Rama no actualizada${NC}"
            fi
            
            if grep -q "$DOMAIN" "$script"; then
                echo -e "${GREEN}  ✓ Dominio actualizado${NC}"
            else
                echo -e "${RED}  ✗ Error: Dominio no actualizado${NC}"
            fi
            
            echo
        fi
    done
}

# Función para crear archivo de configuración
create_config_file() {
    log "Creando archivo de configuración..."
    
    cat > git-config.env << EOF
# Configuración de Git para PDF Validator API
# Generado automáticamente el $(date)

GIT_REPO="$GIT_REPO"
GIT_BRANCH="$GIT_BRANCH"
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"

# Para usar esta configuración en otros scripts:
# source git-config.env
EOF
    
    success "Archivo de configuración creado: git-config.env"
}

# Función principal
main() {
    log "Iniciando configuración de repositorio Git..."
    
    # Verificar que estamos en el directorio correcto
    if [ ! -f "deploy-from-git.sh" ] && [ ! -f "deploy-complete.sh" ]; then
        error "No se encontraron los scripts de despliegue. Ejecuta este script desde el directorio del proyecto."
    fi
    
    # Obtener configuración del usuario
    get_configuration
    
    # Mostrar resumen
    show_summary
    
    # Solicitar confirmación
    if ! confirm "¿Deseas aplicar esta configuración a todos los scripts?"; then
        info "Configuración cancelada por el usuario"
        exit 0
    fi
    
    # Crear backup
    backup_scripts
    
    # Actualizar scripts
    update_scripts
    
    # Verificar cambios
    verify_changes
    
    # Crear archivo de configuración
    create_config_file
    
    success "Configuración completada exitosamente"
}

# Función para mostrar resumen final
show_final_summary() {
    echo -e "\n${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                    CONFIGURACIÓN COMPLETADA                       "
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎉 ¡Scripts configurados exitosamente!${NC}\n"
    
    echo -e "${BLUE}📋 CONFIGURACIÓN APLICADA:${NC}"
    echo -e "${GREEN}   Repositorio: $GIT_REPO${NC}"
    echo -e "${GREEN}   Rama: $GIT_BRANCH${NC}"
    echo -e "${GREEN}   Dominio: $DOMAIN${NC}"
    echo -e "${GREEN}   Email: $EMAIL${NC}\n"
    
    echo -e "${BLUE}📁 ARCHIVOS MODIFICADOS:${NC}"
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            echo -e "${GREEN}   ✓ $script${NC}"
        fi
    done
    echo
    
    echo -e "${BLUE}🔄 PRÓXIMOS PASOS:${NC}"
    echo -e "${GREEN}   1. Subir los scripts modificados a tu repositorio Git${NC}"
    echo -e "${GREEN}   2. Ejecutar el despliegue en tu VPS:${NC}"
    echo -e "${GREEN}      wget https://raw.githubusercontent.com/[tu-usuario]/[tu-repo]/main/deploy-from-git.sh${NC}"
    echo -e "${GREEN}      chmod +x deploy-from-git.sh${NC}"
    echo -e "${GREEN}      sudo ./deploy-from-git.sh${NC}\n"
    
    echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
    echo -e "${GREEN}   - Asegúrate de que $DOMAIN apunte a la IP de tu VPS${NC}"
    echo -e "${GREEN}   - Verifica que el repositorio $GIT_REPO sea accesible${NC}"
    echo -e "${GREEN}   - Los backups están en: $(ls -d scripts-backup-* 2>/dev/null | tail -1 || echo 'No disponible')${NC}\n"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
}

# Ejecutar configuración principal
main

# Mostrar resumen final
show_final_summary

success "¡Configuración de repositorio Git completada!"
exit 0