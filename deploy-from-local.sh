#!/bin/bash

# Script de Despliegue desde Local
# Automatiza: commit, push y despliegue en producción

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuración
PRODUCTION_SERVER="168.231.91.217"
PRODUCTION_USER="root"
PRODUCTION_PATH="/opt/pdf-signer/pdf"
REMOTE_BRANCH="main"

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║              PDF SIGNER - DESPLIEGUE COMPLETO                ║${NC}"
echo -e "${PURPLE}║                Local → Git → Producción                     ║${NC}"
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

# Verificar que estamos en un repositorio Git
if [ ! -d ".git" ]; then
    log_error "No estás en un repositorio Git"
    exit 1
fi

# Mostrar información actual
echo -e "${BLUE}Información del repositorio:${NC}"
echo "  - Directorio: $(pwd)"
echo "  - Rama actual: $(git branch --show-current)"
echo "  - Último commit: $(git log -1 --oneline)"
echo "  - Estado: $(git status --porcelain | wc -l) archivos modificados"
echo ""

# Verificar si hay cambios
if git diff-index --quiet HEAD --; then
    log_info "No hay cambios locales para confirmar"
    SKIP_COMMIT=true
else
    log_info "Se encontraron cambios locales"
    SKIP_COMMIT=false
    
    # Mostrar cambios
    echo -e "${YELLOW}Archivos modificados:${NC}"
    git status --porcelain
    echo ""
fi

# Confirmar antes de proceder
if [ "$SKIP_COMMIT" = false ]; then
    read -p "¿Continuar con commit y despliegue? (y/N): " -n 1 -r
else
    read -p "¿Continuar con despliegue? (y/N): " -n 1 -r
fi
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Operación cancelada por el usuario"
    exit 0
fi

echo ""
if [ "$SKIP_COMMIT" = false ]; then
    log_step "PASO 1: Commit de cambios locales"
    echo "────────────────────────────────────────"
    
    # Solicitar mensaje de commit
    echo -n "Mensaje de commit (Enter para mensaje automático): "
    read COMMIT_MESSAGE
    
    if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="Actualización automática - $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Hacer commit
    log_info "Agregando archivos al staging..."
    git add .
    
    log_info "Creando commit: $COMMIT_MESSAGE"
    git commit -m "$COMMIT_MESSAGE"
    
    log_info "Commit creado exitosamente"
else
    log_step "PASO 1: Omitiendo commit (no hay cambios)"
    echo "────────────────────────────────────────"
fi

echo ""
log_step "PASO 2: Push al repositorio remoto"
echo "────────────────────────────────────────"

# Hacer push
log_info "Enviando cambios al repositorio remoto..."
git push origin $REMOTE_BRANCH || {
    log_error "Error al hacer push al repositorio remoto"
    exit 1
}

log_info "Push completado exitosamente"

echo ""
log_step "PASO 3: Despliegue en producción"
echo "────────────────────────────────────────"

# Verificar conectividad con el servidor
log_info "Verificando conectividad con el servidor de producción..."
if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $PRODUCTION_USER@$PRODUCTION_SERVER 'echo "Conexión exitosa"' >/dev/null 2>&1; then
    log_error "No se puede conectar al servidor de producción"
    log_error "Verifica la conectividad y las credenciales SSH"
    exit 1
fi

log_info "Conectividad verificada"

# Ejecutar despliegue en producción
log_info "Ejecutando despliegue en el servidor de producción..."
echo ""
echo -e "${YELLOW}=== SALIDA DEL SERVIDOR DE PRODUCCIÓN ===${NC}"

ssh -o StrictHostKeyChecking=no $PRODUCTION_USER@$PRODUCTION_SERVER << 'EOF'
cd /opt/pdf-signer/pdf
echo "Directorio actual: $(pwd)"
echo "Ejecutando script maestro de despliegue..."
echo ""
# Ejecutar con respuesta automática 'y'
echo "y" | ./deploy-master.sh
EOF

DEPLOY_EXIT_CODE=$?

echo ""
echo -e "${YELLOW}=== FIN DE SALIDA DEL SERVIDOR ===${NC}"
echo ""

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    log_step "PASO 4: Verificación final"
    echo "────────────────────────────────────────"
    
    # Verificar que la aplicación esté funcionando
    log_info "Verificando que la aplicación esté funcionando..."
    
    if curl -s -k https://validador.usiv.cl/pdf-signer/actuator/health | grep -q '"status":"UP"'; then
        log_info "✓ Aplicación funcionando correctamente"
        
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    ¡DESPLIEGUE EXITOSO!                     ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}🎉 La aplicación ha sido desplegada exitosamente${NC}"
        echo ""
        echo -e "${YELLOW}URLs de acceso:${NC}"
        echo "  • Health Check: https://validador.usiv.cl/pdf-signer/actuator/health"
        echo "  • API Principal: https://validador.usiv.cl/pdf-signer/api/sign"
        echo "  • Documentación: https://validador.usiv.cl/pdf-signer/swagger-ui.html"
        echo ""
        echo -e "${BLUE}Información del despliegue:${NC}"
        echo "  • Fecha: $(date)"
        echo "  • Commit: $(git log -1 --oneline)"
        echo "  • Rama: $(git branch --show-current)"
        echo ""
    else
        log_warn "⚠️  La aplicación se desplegó pero el health check falló"
        log_info "Verifica manualmente: https://validador.usiv.cl/pdf-signer/actuator/health"
    fi
else
    log_error "❌ Error en el despliegue en producción"
    log_error "Revisa los logs del servidor para más detalles"
    exit 1
fi

echo -e "${GREEN}✅ Proceso completado exitosamente${NC}"