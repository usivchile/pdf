# VERIFICADOR DE ESTADO SSL - PowerShell
# Script para verificar configuracion SSL/HTTPS desde Windows
# Autor: PDF Signer Team

param(
    [string]$ServerIP = "168.231.91.217"
)

# Funcion para escribir con colores
function Write-Success { param([string]$Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Step { param([string]$Message) Write-Host "`n🔍 $Message" -ForegroundColor Magenta; Write-Host "═══════════════════════════════════════════════════════════════════" }

# Funcion para verificar conectividad TCP
function Test-TcpConnection {
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 5000)
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

# Funcion para verificar URL HTTP/HTTPS
function Test-WebUrl {
    param([string]$Url, [int]$TimeoutSec = 10, [switch]$IgnoreSSLErrors)
    
    try {
        if ($IgnoreSSLErrors) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
        return @{ Success = $true; StatusCode = $response.StatusCode; StatusDescription = $response.StatusDescription }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; StatusCode = "N/A" }
    }
}

# Inicio del script
Clear-Host
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    🔍 VERIFICADOR DE ESTADO SSL" -ForegroundColor Cyan
Write-Host "                      PDF Signer - Diagnostico" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🖥️  Cliente: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "🌐 Servidor: $ServerIP" -ForegroundColor White
Write-Host "🕐 Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# PASO 1: Verificar conectividad basica
Write-Step "VERIFICANDO CONECTIVIDAD BASICA"

# Puerto 80 (HTTP)
Write-Info "Probando conectividad al puerto 80 (HTTP)..."
if (Test-TcpConnection -ComputerName $ServerIP -Port 80) {
    Write-Success "Puerto 80 (HTTP) es accesible"
    $HttpPortOpen = $true
} else {
    Write-Error "Puerto 80 (HTTP) no es accesible"
    $HttpPortOpen = $false
}

# Puerto 443 (HTTPS)
Write-Info "Probando conectividad al puerto 443 (HTTPS)..."
if (Test-TcpConnection -ComputerName $ServerIP -Port 443) {
    Write-Success "Puerto 443 (HTTPS) es accesible"
    $HttpsPortOpen = $true
} else {
    Write-Warning "Puerto 443 (HTTPS) no es accesible"
    $HttpsPortOpen = $false
}

# Puerto 8080 (Tomcat)
Write-Info "Probando conectividad al puerto 8080 (Tomcat)..."
if (Test-TcpConnection -ComputerName $ServerIP -Port 8080) {
    Write-Success "Puerto 8080 (Tomcat) es accesible"
    $TomcatPortOpen = $true
} else {
    Write-Warning "Puerto 8080 (Tomcat) no es accesible"
    $TomcatPortOpen = $false
}

# PASO 2: Verificar acceso HTTP
Write-Step "VERIFICANDO ACCESO HTTP"

if ($HttpPortOpen) {
    $httpUrls = @(
        "http://$ServerIP/",
        "http://$ServerIP/pdf-signer/",
        "http://$ServerIP/pdf-signer/api/health"
    )
    
    foreach ($url in $httpUrls) {
        Write-Info "Probando: $url"
        $result = Test-WebUrl -Url $url -TimeoutSec 10
        
        if ($result.Success) {
            Write-Success "Respuesta: $($result.StatusCode) $($result.StatusDescription)"
        } else {
            Write-Warning "Error: $($result.Error)"
            if ($result.Error -like "*blocked*" -or $result.Error -like "*firewall*") {
                Write-Info "    💡 Posible bloqueo de firewall corporativo"
            }
        }
    }
} else {
    Write-Warning "Saltando pruebas HTTP - Puerto 80 no accesible"
}

# PASO 3: Verificar acceso HTTPS
Write-Step "VERIFICANDO ACCESO HTTPS"

if ($HttpsPortOpen) {
    # Probar URLs HTTPS
    $httpsUrls = @(
        "https://$ServerIP/",
        "https://$ServerIP/pdf-signer/",
        "https://$ServerIP/pdf-signer/api/health"
    )
    
    foreach ($url in $httpsUrls) {
        Write-Info "Probando: $url"
        $result = Test-WebUrl -Url $url -TimeoutSec 10 -IgnoreSSLErrors
        
        if ($result.Success) {
            Write-Success "Respuesta: $($result.StatusCode) $($result.StatusDescription)"
        } else {
            Write-Warning "Error: $($result.Error)"
            if ($result.Error -like "*blocked*" -or $result.Error -like "*firewall*") {
                Write-Info "    💡 Posible bloqueo de firewall corporativo"
            }
        }
    }
} else {
    Write-Warning "Saltando pruebas HTTPS - Puerto 443 no accesible"
}

# PASO 4: Verificar acceso directo a Tomcat
Write-Step "VERIFICANDO ACCESO DIRECTO A TOMCAT"

if ($TomcatPortOpen) {
    $tomcatUrls = @(
        "http://$ServerIP:8080/",
        "http://$ServerIP:8080/pdf-signer/",
        "http://$ServerIP:8080/pdf-signer/api/health"
    )
    
    foreach ($url in $tomcatUrls) {
        Write-Info "Probando: $url"
        $result = Test-WebUrl -Url $url -TimeoutSec 10
        
        if ($result.Success) {
            Write-Success "Respuesta: $($result.StatusCode) $($result.StatusDescription)"
        } else {
            Write-Warning "Error: $($result.Error)"
        }
    }
} else {
    Write-Warning "Saltando pruebas Tomcat - Puerto 8080 no accesible"
}

# PASO 5: Diagnostico de red
Write-Step "DIAGNOSTICO DE RED"

# Ping
Write-Info "Probando ping al servidor..."
try {
    $pingResult = Test-Connection -ComputerName $ServerIP -Count 2 -Quiet
    if ($pingResult) {
        Write-Success "Ping exitoso - Servidor alcanzable"
    } else {
        Write-Warning "Ping fallo - Posible bloqueo de ICMP"
    }
} catch {
    Write-Warning "Error en ping: $($_.Exception.Message)"
}

# PASO 6: Resumen y recomendaciones
Write-Step "RESUMEN Y RECOMENDACIONES"

Write-Host "📊 ESTADO ACTUAL:" -ForegroundColor Cyan
Write-Host "    🌐 HTTP (Puerto 80): $(if ($HttpPortOpen) { '✅ Accesible' } else { '❌ No accesible' })" -ForegroundColor White
Write-Host "    🔐 HTTPS (Puerto 443): $(if ($HttpsPortOpen) { '✅ Accesible' } else { '❌ No accesible' })" -ForegroundColor White
Write-Host "    🐱 Tomcat (Puerto 8080): $(if ($TomcatPortOpen) { '✅ Accesible' } else { '❌ No accesible' })" -ForegroundColor White

Write-Host "`n🎯 RECOMENDACIONES:" -ForegroundColor Yellow

if (-not $HttpsPortOpen) {
    Write-Host "    1. 🔧 Configurar SSL en el servidor:" -ForegroundColor White
    Write-Host "       sudo ./setup-ssl-letsencrypt.sh tu-dominio.com" -ForegroundColor Gray
    Write-Host "       # o para IP: sudo ./setup-ssl-letsencrypt.sh $ServerIP" -ForegroundColor Gray
}

if (-not $HttpPortOpen -and -not $HttpsPortOpen) {
    Write-Host "    2. 🔥 Verificar firewall del servidor:" -ForegroundColor White
    Write-Host "       sudo firewall-cmd --list-all" -ForegroundColor Gray
    Write-Host "       sudo firewall-cmd --add-service=http --permanent" -ForegroundColor Gray
    Write-Host "       sudo firewall-cmd --add-service=https --permanent" -ForegroundColor Gray
}

if ($HttpPortOpen -or $HttpsPortOpen) {
    Write-Host "    3. 🌐 Para evitar bloqueos de firewall corporativo:" -ForegroundColor White
    Write-Host "       - Usar HTTPS en lugar de HTTP" -ForegroundColor Gray
    Write-Host "       - Solicitar excepcion al administrador de red" -ForegroundColor Gray
    Write-Host "       - Usar herramientas como Postman o curl" -ForegroundColor Gray
}

Write-Host "`n📋 COMANDOS UTILES:" -ForegroundColor Cyan
Write-Host "    # Probar con PowerShell:" -ForegroundColor Gray
Write-Host "    Invoke-WebRequest -Uri 'https://$ServerIP/pdf-signer/' -SkipCertificateCheck" -ForegroundColor Gray
Write-Host "    " -ForegroundColor Gray
Write-Host "    # Verificar certificado:" -ForegroundColor Gray
Write-Host "    .\check-ssl-status.ps1 -ServerIP $ServerIP" -ForegroundColor Gray

Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($HttpsPortOpen) {
    Write-Host "                    🔒 HTTPS ESTA DISPONIBLE" -ForegroundColor Green
    Write-Host "    Accede a: https://$ServerIP/pdf-signer/" -ForegroundColor White
    Write-Host "    Usa el archivo test-internet-access.html con HTTPS" -ForegroundColor White
} else {
    Write-Host "                    ⚠️  HTTPS NO ESTA DISPONIBLE" -ForegroundColor Yellow
    Write-Host "    Configura SSL en el servidor primero" -ForegroundColor White
}
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Pausa al final
Write-Host "`nPresiona cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")