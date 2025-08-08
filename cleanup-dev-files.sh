#!/bin/bash

# SCRIPT DE LIMPIEZA DE ARCHIVOS DE DESARROLLO
# Elimina archivos y directorios que no deben ir a producción
# Autor: PDF Signer Team

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "═══════════════════════════════════════════════════════════════════"
echo "                    🧹 LIMPIEZA DE ARCHIVOS DE DESARROLLO"
echo "                         PDF Signer - Producción"
echo "═══════════════════════════════════════════════════════════════════"
echo "🕐 Fecha: $(date)"
echo "📁 Directorio: $(pwd)"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar que estamos en el directorio correcto del proyecto
if [ ! -f "pom.xml" ]; then
    log_error "No se encontró pom.xml. Asegúrate de estar en el directorio raíz del proyecto."
    exit 1
fi

log_info "Directorio del proyecto verificado"

# Lista de archivos y directorios a eliminar
DEV_FILES=(
    "test-client.html"
    "test-internet-access.html"
    "ssl-check.ps1"
    "check-ssl-status.ps1"
    "deploy-to-vps.sh"
    "cleanup-dev-files.sh"
    "INSTRUCCIONES-SSL.md"
    ".project"
    ".classpath"
    ".settings/"
    "target/"
    "*.log"
    "*.tmp"
    "*.bak"
    "*.backup"
    ".DS_Store"
    "Thumbs.db"
    "*.swp"
    "*.swo"
    "*~"
)

# Archivos de configuración de desarrollo
DEV_CONFIG_FILES=(
    "src/main/resources/application-dev.properties"
    "src/main/resources/application-test.properties"
    "src/main/resources/logback-test.xml"
)

# Directorios de IDEs
IDE_DIRS=(
    ".idea/"
    ".vscode/"
    "*.iml"
    "*.ipr"
    "*.iws"
)

log_info "Iniciando limpieza de archivos de desarrollo..."

# Contador de archivos eliminados
COUNT=0

# Eliminar archivos de desarrollo
log_info "Eliminando archivos de desarrollo y prueba..."
for file in "${DEV_FILES[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        rm -rf "$file"
        log_success "Eliminado: $file"
        ((COUNT++))
    fi
done

# Eliminar archivos de configuración de desarrollo
log_info "Eliminando archivos de configuración de desarrollo..."
for file in "${DEV_CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        log_success "Eliminado: $file"
        ((COUNT++))
    fi
done

# Eliminar directorios de IDEs
log_info "Eliminando directorios de IDEs..."
for dir in "${IDE_DIRS[@]}"; do
    if [ -d "$dir" ] || [ -f "$dir" ]; then
        rm -rf "$dir"
        log_success "Eliminado: $dir"
        ((COUNT++))
    fi
done

# Limpiar archivos temporales con patrones
log_info "Eliminando archivos temporales..."

# Buscar y eliminar archivos .log
find . -name "*.log" -type f -delete 2>/dev/null && log_success "Archivos .log eliminados" || true

# Buscar y eliminar archivos .tmp
find . -name "*.tmp" -type f -delete 2>/dev/null && log_success "Archivos .tmp eliminados" || true

# Buscar y eliminar archivos de backup
find . -name "*.bak" -type f -delete 2>/dev/null && log_success "Archivos .bak eliminados" || true
find . -name "*.backup" -type f -delete 2>/dev/null && log_success "Archivos .backup eliminados" || true

# Buscar y eliminar archivos de sistema
find . -name ".DS_Store" -type f -delete 2>/dev/null && log_success "Archivos .DS_Store eliminados" || true
find . -name "Thumbs.db" -type f -delete 2>/dev/null && log_success "Archivos Thumbs.db eliminados" || true

# Buscar y eliminar archivos de editores
find . -name "*.swp" -type f -delete 2>/dev/null && log_success "Archivos .swp eliminados" || true
find . -name "*.swo" -type f -delete 2>/dev/null && log_success "Archivos .swo eliminados" || true
find . -name "*~" -type f -delete 2>/dev/null && log_success "Archivos temporales ~ eliminados" || true

# Limpiar directorio target si existe
if [ -d "target" ]; then
    rm -rf target
    log_success "Directorio target eliminado"
    ((COUNT++))
fi

# Limpiar logs de Maven
if [ -d "logs" ]; then
    rm -rf logs
    log_success "Directorio logs eliminado"
    ((COUNT++))
fi

# Verificar archivos que quedan
log_info "Verificando archivos restantes..."

# Mostrar estructura del proyecto limpia
echo
log_info "Estructura del proyecto después de la limpieza:"
find . -maxdepth 2 -type f -name "*.java" -o -name "*.xml" -o -name "*.properties" -o -name "*.jsp" -o -name "*.js" -o -name "*.css" -o -name "*.html" | head -20

if [ $(find . -maxdepth 2 -type f -name "*.java" -o -name "*.xml" -o -name "*.properties" -o -name "*.jsp" -o -name "*.js" -o -name "*.css" -o -name "*.html" | wc -l) -gt 20 ]; then
    echo "... (y más archivos)"
fi

echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    ✨ LIMPIEZA COMPLETADA"
echo "═══════════════════════════════════════════════════════════════════"
echo "📊 Archivos/directorios eliminados: $COUNT"
echo "🎯 El proyecto está listo para producción"
echo "📁 Directorio: $(pwd)"
echo "🕐 Finalizado: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

log_success "Limpieza de archivos de desarrollo completada exitosamente"

# Mostrar archivos importantes que permanecen
echo
log_info "Archivos importantes que permanecen:"
echo "  📄 pom.xml - Configuración de Maven"
echo "  📁 src/ - Código fuente"
echo "  📄 README.md - Documentación (si existe)"
echo "  📄 .gitignore - Configuración de Git (si existe)"

if [ -f "README.md" ]; then
    log_success "README.md presente"
fi

if [ -f ".gitignore" ]; then
    log_success ".gitignore presente"
fi

echo
log_info "El proyecto está listo para ser desplegado en producción."