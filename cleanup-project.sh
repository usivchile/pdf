#!/bin/bash

# Script para limpiar archivos innecesarios del proyecto PDF Signer
# Elimina scripts duplicados, archivos obsoletos y temporales

echo "🧹 Limpiando proyecto PDF Signer..."
echo "═══════════════════════════════════════════════════════════════════"

# Función para mostrar mensajes
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warn() {
    echo "⚠️  $1"
}

# Contador de archivos eliminados
COUNT=0

# 1. ELIMINAR SCRIPTS DE DESPLIEGUE OBSOLETOS/DUPLICADOS
log_info "Eliminando scripts de despliegue obsoletos..."

# Scripts obsoletos que ya no se necesitan (tenemos deploy-master.sh como principal)
OBSOLETE_SCRIPTS=(
    "deploy-fixed-war.sh"
    "deploy-fixed-war.ps1"
    "deploy-local-vps.sh"
    "deploy-smart.sh"
    "deploy-to-vps.sh"
    "simple-production-install.sh"
    "fix-complete-deployment.sh"
    "fix-deployment.sh"
    "fix-404-error.sh"
    "fix-nginx-config.sh"
    "fix-web-xml.sh"
    "debug-nginx-issue.sh"
    "diagnose-deployment.sh"
    "diagnose-tomcat-logs.sh"
    "manage-tomcat.sh"
    "verify-tomcat-deployment.sh"
    "verify-tomcat-service.sh"
    "troubleshoot.sh"
    "fix-git-pull.sh"
    "fix-git-pull.ps1"
    "run-diagnosis.ps1"
)

for script in "${OBSOLETE_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        rm "$script"
        log_success "Eliminado: $script"
        ((COUNT++))
    fi
done

# 2. ELIMINAR DOCUMENTACIÓN OBSOLETA
log_info "Eliminando documentación obsoleta..."

OBSOLETE_DOCS=(
    "INSTRUCCIONES-DESPLIEGUE.md"
    "INSTRUCCIONES-SSL.md"
    "INSTRUCCIONES-VPS.sh"
    "README-DESPLIEGUE-VPS.md"
    "DEPLOYMENT-GUIDE.md"
    "PROJECT-STRUCTURE.md"
)

for doc in "${OBSOLETE_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        rm "$doc"
        log_success "Eliminado: $doc"
        ((COUNT++))
    fi
done

# 3. ELIMINAR SCRIPTS DE VERIFICACIÓN DUPLICADOS
log_info "Eliminando scripts de verificación duplicados..."

VERIFY_SCRIPTS=(
    "check-ssl-status.sh"
    "check-ssl-status.ps1"
    "ssl-check.ps1"
    "setup-ssl-letsencrypt.sh"
)

for script in "${VERIFY_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        rm "$script"
        log_success "Eliminado: $script"
        ((COUNT++))
    fi
done

# 4. ELIMINAR ARCHIVOS DE CONFIGURACIÓN DE IDE OBSOLETOS
log_info "Eliminando archivos de configuración de IDE..."

if [ -f ".classpath" ]; then
    rm ".classpath"
    log_success "Eliminado: .classpath"
    ((COUNT++))
fi

if [ -f ".project" ]; then
    rm ".project"
    log_success "Eliminado: .project"
    ((COUNT++))
fi

if [ -d ".settings" ]; then
    rm -rf ".settings"
    log_success "Eliminado: .settings/"
    ((COUNT++))
fi

# 5. ELIMINAR DIRECTORIO WEB-INF DUPLICADO (ya está en src/main/webapp/)
log_info "Eliminando directorio WEB-INF duplicado..."

if [ -d "WEB-INF" ]; then
    rm -rf "WEB-INF"
    log_success "Eliminado: WEB-INF/ (duplicado)"
    ((COUNT++))
fi

# 6. ELIMINAR ARCHIVO PDF DE PRUEBA
log_info "Eliminando archivos de prueba..."

if [ -f "pdf-firmado.pdf" ]; then
    rm "pdf-firmado.pdf"
    log_success "Eliminado: pdf-firmado.pdf"
    ((COUNT++))
fi

# 7. LIMPIAR DIRECTORIO TARGET (archivos compilados)
log_info "Limpiando directorio target..."

if [ -d "target" ]; then
    rm -rf "target"
    log_success "Eliminado: target/ (se regenerará con mvn package)"
    ((COUNT++))
fi

# 8. MANTENER SOLO LOS ARCHIVOS NECESARIOS
log_info "Archivos mantenidos (necesarios):"
echo "  ✅ pom.xml - Configuración de Maven"
echo "  ✅ src/ - Código fuente"
echo "  ✅ README.md - Documentación principal"
echo "  ✅ DEPLOYMENT-SUCCESS.md - Estado del despliegue"
echo "  ✅ README-DEPLOYMENT-AUTOMATION.md - Guía de automatización"
echo "  ✅ deploy-production.sh - Script de despliegue"
echo "  ✅ deploy-master.sh - Script maestro"
echo "  ✅ deploy-from-local.sh - Despliegue desde local"
echo "  ✅ cleanup-production.sh - Limpieza del servidor"
echo "  ✅ cleanup-dev-files.sh - Limpieza de desarrollo"
echo "  ✅ check-deployment.sh - Verificación de despliegue"
echo "  ✅ check-maven.sh - Verificación de Maven"
echo "  ✅ test-client.html - Cliente de pruebas (corregido)"
echo "  ✅ test-internet-access.html - Verificación de acceso (corregido)"

echo
echo "═══════════════════════════════════════════════════════════════════"
log_success "Limpieza completada: $COUNT archivos/directorios eliminados"
echo "🎯 Proyecto optimizado y listo para producción"
echo "═══════════════════════════════════════════════════════════════════"

# Mostrar estructura final
echo
log_info "Estructura final del proyecto:"
find . -maxdepth 2 -type f -name "*.sh" -o -name "*.md" -o -name "*.html" -o -name "pom.xml" | sort