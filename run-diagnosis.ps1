# Script de PowerShell para ejecutar diagnóstico en el VPS

Write-Host "=== EJECUTANDO DIAGNÓSTICO EN VPS ===" -ForegroundColor Green
Write-Host "Fecha: $(Get-Date)" -ForegroundColor Gray
Write-Host

# Variables
$VPS_HOST = "validador.usiv.cl"
$VPS_USER = "root"
$LOCAL_SCRIPT = "diagnose-tomcat-logs.sh"
$REMOTE_SCRIPT = "/root/pdf/diagnose-tomcat-logs.sh"

# Verificar que el script local existe
if (-not (Test-Path $LOCAL_SCRIPT)) {
    Write-Host "❌ ERROR: No se encuentra el script: $LOCAL_SCRIPT" -ForegroundColor Red
    Write-Host "   Asegúrate de que el archivo existe en el directorio actual" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Script local encontrado: $LOCAL_SCRIPT" -ForegroundColor Green
Write-Host

# Subir script al VPS
Write-Host "📤 Subiendo script de diagnóstico al VPS..." -ForegroundColor Cyan
try {
    scp $LOCAL_SCRIPT "${VPS_USER}@${VPS_HOST}:${REMOTE_SCRIPT}"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Script subido exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ ERROR: Falló la subida del script" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ ERROR: No se pudo subir el script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host

# Ejecutar diagnóstico en el VPS
Write-Host "🔍 Ejecutando diagnóstico en el VPS..." -ForegroundColor Cyan
Write-Host "⏳ Esto puede tomar unos momentos..." -ForegroundColor Yellow
Write-Host

try {
    ssh "${VPS_USER}@${VPS_HOST}" @"
cd /root/pdf
chmod +x diagnose-tomcat-logs.sh
./diagnose-tomcat-logs.sh
"@
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host
        Write-Host "✅ Diagnóstico completado exitosamente" -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "⚠️ Diagnóstico completado con advertencias" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ ERROR: No se pudo ejecutar el diagnóstico: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host
Write-Host "=== DIAGNÓSTICO FINALIZADO ===" -ForegroundColor Green
Write-Host "💡 Revisa la salida anterior para identificar problemas" -ForegroundColor Cyan
Write-Host
Write-Host "🔧 Posibles soluciones basadas en los resultados:" -ForegroundColor Yellow
Write-Host "   - Si no se encuentra catalina.out: verificar ubicación de logs" -ForegroundColor Gray
Write-Host "   - Si pdf-signer no está desplegado: verificar WAR y permisos" -ForegroundColor Gray
Write-Host "   - Si web.xml no existe: recompilar con las correcciones" -ForegroundColor Gray
Write-Host "   - Si hay errores de puerto: verificar conflictos de servicios" -ForegroundColor Gray
Write-Host