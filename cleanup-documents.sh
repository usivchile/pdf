#!/bin/bash

# Script de limpieza de documentos PDF
# Autor: USIV Development Team
# Descripción: Mueve archivos antiguos a papelera y limpia automáticamente

# Configuración por defecto (puede ser sobrescrita por variables de entorno)
BASE_PATH="${PDF_STORAGE_BASE_PATH:-./storage/pdfs}"
TRASH_PATH="${PDF_TRASH_PATH:-./storage/trash}"
RETENTION_MONTHS="${PDF_RETENTION_MONTHS:-6}"
TRASH_RETENTION_DAYS="${PDF_TRASH_RETENTION_DAYS:-30}"
LOG_FILE="${PDF_CLEANUP_LOG:-./logs/cleanup.log}"
DRY_RUN="${PDF_DRY_RUN:-false}"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Script de Limpieza de Documentos PDF - USIV

Uso: $0 [OPCIONES]

OPCIONES:
    -h, --help              Mostrar esta ayuda
    -d, --dry-run          Ejecutar en modo simulación (no realizar cambios)
    -v, --verbose          Mostrar información detallada
    -f, --force            Forzar limpieza sin confirmación
    -c, --config FILE      Usar archivo de configuración personalizado
    --base-path PATH       Ruta base de almacenamiento de PDFs
    --trash-path PATH      Ruta de la papelera
    --retention-months N   Meses de retención antes de mover a papelera
    --trash-days N         Días de retención en papelera antes de eliminar

VARIABLES DE ENTORNO:
    PDF_STORAGE_BASE_PATH  Ruta base de almacenamiento
    PDF_TRASH_PATH         Ruta de la papelera
    PDF_RETENTION_MONTHS   Meses de retención
    PDF_TRASH_RETENTION_DAYS Días en papelera
    PDF_CLEANUP_LOG        Archivo de log
    PDF_DRY_RUN           Modo simulación (true/false)

EJEMPLOS:
    $0                     # Ejecutar con configuración por defecto
    $0 --dry-run           # Simular limpieza sin realizar cambios
    $0 --retention-months 3 # Retener archivos por 3 meses
    $0 --force             # Ejecutar sin confirmación

EOF
}

# Función para validar dependencias
check_dependencies() {
    local missing_deps=()
    
    command -v find >/dev/null 2>&1 || missing_deps+=("find")
    command -v date >/dev/null 2>&1 || missing_deps+=("date")
    command -v stat >/dev/null 2>&1 || missing_deps+=("stat")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR" "Dependencias faltantes: ${missing_deps[*]}"
        exit 1
    fi
}

# Función para crear directorios necesarios
setup_directories() {
    log "INFO" "Configurando directorios..."
    
    # Crear directorio de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Crear directorio de papelera
    if [ "$DRY_RUN" != "true" ]; then
        mkdir -p "$TRASH_PATH"
        log "INFO" "Directorio de papelera: $TRASH_PATH"
    fi
    
    # Verificar que existe el directorio base
    if [ ! -d "$BASE_PATH" ]; then
        log "ERROR" "Directorio base no existe: $BASE_PATH"
        exit 1
    fi
}

# Función para mover archivos antiguos a papelera
move_old_files() {
    log "INFO" "Buscando archivos antiguos (más de $RETENTION_MONTHS meses)..."
    
    # Calcular fecha límite
    if command -v gdate >/dev/null 2>&1; then
        # macOS con GNU date instalado
        cutoff_date=$(gdate -d "$RETENTION_MONTHS months ago" +%s)
    else
        # Linux
        cutoff_date=$(date -d "$RETENTION_MONTHS months ago" +%s)
    fi
    
    local moved_count=0
    local total_size=0
    
    # Buscar archivos PDF antiguos
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            # Obtener fecha de modificación del archivo
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                file_date=$(stat -f %m "$file")
            else
                # Linux
                file_date=$(stat -c %Y "$file")
            fi
            
            if [ "$file_date" -lt "$cutoff_date" ]; then
                # Calcular ruta de destino manteniendo estructura de directorios
                relative_path=${file#$BASE_PATH/}
                dest_file="$TRASH_PATH/$relative_path"
                dest_dir=$(dirname "$dest_file")
                
                # Obtener tamaño del archivo
                file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
                total_size=$((total_size + file_size))
                
                log "INFO" "Moviendo a papelera: $relative_path ($(numfmt --to=iec $file_size 2>/dev/null || echo $file_size bytes))"
                
                if [ "$DRY_RUN" != "true" ]; then
                    mkdir -p "$dest_dir"
                    mv "$file" "$dest_file"
                    if [ $? -eq 0 ]; then
                        moved_count=$((moved_count + 1))
                    else
                        log "ERROR" "Error al mover archivo: $file"
                    fi
                else
                    moved_count=$((moved_count + 1))
                fi
            fi
        fi
    done < <(find "$BASE_PATH" -name "*.pdf" -type f -print0)
    
    log "INFO" "Archivos movidos a papelera: $moved_count ($(numfmt --to=iec $total_size 2>/dev/null || echo $total_size bytes))"
}

# Función para limpiar papelera
clean_trash() {
    log "INFO" "Limpiando papelera (archivos más antiguos de $TRASH_RETENTION_DAYS días)..."
    
    if [ ! -d "$TRASH_PATH" ]; then
        log "INFO" "Directorio de papelera no existe, omitiendo limpieza"
        return
    fi
    
    local deleted_count=0
    local total_size=0
    
    # Buscar archivos en papelera más antiguos que el período de retención
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            # Obtener tamaño del archivo
            file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            total_size=$((total_size + file_size))
            
            relative_path=${file#$TRASH_PATH/}
            log "INFO" "Eliminando permanentemente: $relative_path ($(numfmt --to=iec $file_size 2>/dev/null || echo $file_size bytes))"
            
            if [ "$DRY_RUN" != "true" ]; then
                rm -f "$file"
                if [ $? -eq 0 ]; then
                    deleted_count=$((deleted_count + 1))
                else
                    log "ERROR" "Error al eliminar archivo: $file"
                fi
            else
                deleted_count=$((deleted_count + 1))
            fi
        fi
    done < <(find "$TRASH_PATH" -name "*.pdf" -type f -mtime +$TRASH_RETENTION_DAYS -print0)
    
    log "INFO" "Archivos eliminados permanentemente: $deleted_count ($(numfmt --to=iec $total_size 2>/dev/null || echo $total_size bytes))"
    
    # Limpiar directorios vacíos en papelera
    if [ "$DRY_RUN" != "true" ]; then
        find "$TRASH_PATH" -type d -empty -delete 2>/dev/null
    fi
}

# Función para mostrar estadísticas
show_statistics() {
    log "INFO" "=== ESTADÍSTICAS ==="
    
    if [ -d "$BASE_PATH" ]; then
        local active_files=$(find "$BASE_PATH" -name "*.pdf" -type f | wc -l)
        local active_size=$(find "$BASE_PATH" -name "*.pdf" -type f -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        log "INFO" "Archivos activos: $active_files ($(numfmt --to=iec $active_size 2>/dev/null || echo $active_size bytes))"
    fi
    
    if [ -d "$TRASH_PATH" ]; then
        local trash_files=$(find "$TRASH_PATH" -name "*.pdf" -type f | wc -l)
        local trash_size=$(find "$TRASH_PATH" -name "*.pdf" -type f -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        log "INFO" "Archivos en papelera: $trash_files ($(numfmt --to=iec $trash_size 2>/dev/null || echo $trash_size bytes))"
    fi
    
    log "INFO" "==================="
}

# Función principal
main() {
    local force=false
    local verbose=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            --base-path)
                BASE_PATH="$2"
                shift 2
                ;;
            --trash-path)
                TRASH_PATH="$2"
                shift 2
                ;;
            --retention-months)
                RETENTION_MONTHS="$2"
                shift 2
                ;;
            --trash-days)
                TRASH_RETENTION_DAYS="$2"
                shift 2
                ;;
            -c|--config)
                if [ -f "$2" ]; then
                    source "$2"
                else
                    log "ERROR" "Archivo de configuración no encontrado: $2"
                    exit 1
                fi
                shift 2
                ;;
            *)
                log "ERROR" "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Mostrar configuración
    log "INFO" "=== CONFIGURACIÓN ==="
    log "INFO" "Ruta base: $BASE_PATH"
    log "INFO" "Ruta papelera: $TRASH_PATH"
    log "INFO" "Retención (meses): $RETENTION_MONTHS"
    log "INFO" "Retención papelera (días): $TRASH_RETENTION_DAYS"
    log "INFO" "Modo simulación: $DRY_RUN"
    log "INFO" "====================="
    
    # Validar dependencias
    check_dependencies
    
    # Configurar directorios
    setup_directories
    
    # Mostrar estadísticas iniciales
    if [ "$verbose" = true ]; then
        show_statistics
    fi
    
    # Confirmación si no es modo forzado
    if [ "$force" != true ] && [ "$DRY_RUN" != "true" ]; then
        echo -e "${YELLOW}¿Continuar con la limpieza? (y/N):${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "INFO" "Operación cancelada por el usuario"
            exit 0
        fi
    fi
    
    # Ejecutar limpieza
    log "INFO" "Iniciando proceso de limpieza..."
    
    move_old_files
    clean_trash
    
    # Mostrar estadísticas finales
    show_statistics
    
    if [ "$DRY_RUN" = "true" ]; then
        log "INFO" "Simulación completada. Use sin --dry-run para ejecutar los cambios."
    else
        log "INFO" "Proceso de limpieza completado exitosamente."
    fi
}

# Ejecutar función principal
main "$@"