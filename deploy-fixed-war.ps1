# Script PowerShell para desplegar el WAR corregido con web.xml al VPS
# Este script sube el nuevo WAR y lo despliega correctamente

Write-Host "=== DESPLEGANDO WAR CORREGIDO CON WEB.XML ===" -ForegroundColor Green
Write-Host "Fecha: $(Get-Date)" -ForegroundColor Gray
Write-Host

# Variables
$VPS_HOST = "validador.usiv.cl"
$VPS_USER = "root"
$LOCAL_WAR = "target\pdf-signer-war-1.0.war"
$REMOTE_WAR_PATH = "/root/pdf-signer-war-1.0.war"
$TOMCAT_WEBAPPS = "/var/lib/tomcat/webapps"
$APP_NAME = "pdf-signer"

# Verificar que el WAR local existe
if (-not (Test-Path $LOCAL_WAR)) {
    Write-Host "❌ ERROR: No se encuentra el archivo WAR: $LOCAL_WAR" -ForegroundColor Red
    Write-Host "   Ejecuta primero: mvn clean package -DskipTests" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ WAR local encontrado: $LOCAL_WAR" -ForegroundColor Green
$fileSize = (Get-Item $LOCAL_WAR).Length / 1MB
Write-Host "📦 Tamaño: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
Write-Host

# Verificar que el web.xml está presente
Write-Host "🔍 Verificando presencia de web.xml..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($LOCAL_WAR)
    $webXmlEntry = $zip.Entries | Where-Object { $_.FullName -eq "WEB-INF/web.xml" }
    $zip.Dispose()
    
    if ($webXmlEntry) {
        Write-Host "✅ web.xml encontrado en el WAR" -ForegroundColor Green
    } else {
        Write-Host "❌ ERROR: web.xml NO encontrado en el WAR" -ForegroundColor Red
        Write-Host "   El WAR no se generó correctamente" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ ERROR: No se pudo verificar el contenido del WAR" -ForegroundColor Red
    exit 1
}
Write-Host

# Subir WAR al VPS
Write-Host "📤 Subiendo WAR al VPS..." -ForegroundColor Yellow
$scpCommand = "scp `"$LOCAL_WAR`" `"${VPS_USER}@${VPS_HOST}:${REMOTE_WAR_PATH}`""
try {
    Invoke-Expression $scpCommand
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ WAR subido exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ ERROR: Falló la subida del WAR" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ ERROR: Falló la subida del WAR - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host

# Crear script de despliegue temporal
$deployScript = @'
echo "=== INICIANDO DESPLIEGUE EN VPS ==="
echo "Fecha: $(date)"
echo

# Detener Tomcat
echo "🛑 Deteniendo Tomcat..."
sudo systemctl stop tomcat
echo "✅ Tomcat detenido"
echo

# Limpiar despliegue anterior
echo "🧹 Limpiando despliegue anterior..."
rm -rf /var/lib/tomcat/webapps/pdf-signer*
echo "✅ Despliegue anterior eliminado"
echo

# Copiar nuevo WAR
echo "📋 Copiando nuevo WAR..."
cp /root/pdf-signer-war-1.0.war /var/lib/tomcat/webapps/pdf-signer.war
chown tomcat:tomcat /var/lib/tomcat/webapps/pdf-signer.war
echo "✅ WAR copiado y permisos asignados"
echo

# Iniciar Tomcat
echo "▶️ Iniciando Tomcat..."
sudo systemctl start tomcat
echo "✅ Tomcat iniciado"
echo

# Esperar despliegue
echo "⏳ Esperando despliegue de la aplicación..."
sleep 15
echo

# Verificar despliegue
echo "🔍 Verificando despliegue..."
if [ -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    echo "✅ Directorio de aplicación creado"
    
    # Verificar web.xml
    if [ -f "/var/lib/tomcat/webapps/pdf-signer/WEB-INF/web.xml" ]; then
        echo "✅ web.xml presente en el despliegue"
    else
        echo "❌ web.xml NO encontrado en el despliegue"
    fi
    
    # Verificar estructura
    echo "📁 Estructura del despliegue:"
    ls -la /var/lib/tomcat/webapps/pdf-signer/WEB-INF/ | head -10
else
    echo "❌ ERROR: Directorio de aplicación NO creado"
fi
echo

# Verificar estado de servicios
echo "🔍 Estado de servicios:"
echo "Tomcat: $(systemctl is-active tomcat)"
echo "Nginx: $(systemctl is-active nginx)"
echo

# Verificar logs de Tomcat
echo "📋 Últimas líneas del log de Tomcat:"
tail -20 /var/lib/tomcat/logs/catalina.out
echo

# Pruebas de conectividad
echo "🧪 Pruebas de conectividad:"
echo "Tomcat directo:"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8080/pdf-signer/ || echo "❌ Falló"
echo
echo "Nginx HTTP:"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost/pdf-signer/ || echo "❌ Falló"
echo
echo "Nginx HTTPS:"
curl -s -o /dev/null -w "Status: %{http_code}\n" https://localhost/pdf-signer/ -k || echo "❌ Falló"
echo

echo "=== DESPLIEGUE COMPLETADO ==="
echo "🌐 URLs para probar:"
echo "   - https://validador.usiv.cl/pdf-signer/"
echo "   - https://validador.usiv.cl/pdf-signer/api/health"
echo "   - https://validador.usiv.cl/pdf-signer/swagger-ui/"
echo
'@

# Ejecutar despliegue en el VPS
Write-Host "🚀 Ejecutando despliegue en el VPS..." -ForegroundColor Yellow
$sshCommand = "ssh `"${VPS_USER}@${VPS_HOST}`" '$deployScript'"
try {
    Invoke-Expression $sshCommand
} catch {
    Write-Host "❌ ERROR: Falló el despliegue - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "=== DESPLIEGUE FINALIZADO ===" -ForegroundColor Green
Write-Host "✅ El WAR corregido ha sido desplegado" -ForegroundColor Green
Write-Host "🔧 Cambios realizados:" -ForegroundColor Cyan
Write-Host "   - Clase principal extiende SpringBootServletInitializer" -ForegroundColor Gray
Write-Host "   - web.xml incluido en el WAR" -ForegroundColor Gray
Write-Host "   - Configuración correcta para Tomcat" -ForegroundColor Gray
Write-Host
Write-Host "🌐 Prueba las URLs:" -ForegroundColor Cyan
Write-Host "   - https://validador.usiv.cl/pdf-signer/" -ForegroundColor Blue
Write-Host "   - https://validador.usiv.cl/pdf-signer/api/health" -ForegroundColor Blue
Write-Host "   - https://validador.usiv.cl/pdf-signer/swagger-ui/" -ForegroundColor Blue
Write-Host