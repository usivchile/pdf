# Verificador SSL simple para PDF Signer
param([string]$ServerIP = "validador.usiv.cl")

function Test-Port {
    param([string]$Computer, [int]$Port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($Computer, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait) {
            $tcp.EndConnect($connect)
            $tcp.Close()
            return $true
        } else {
            $tcp.Close()
            return $false
        }
    } catch {
        return $false
    }
}

function Test-Url {
    param([string]$Url)
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        return "OK - $($response.StatusCode)"
    } catch {
        return "ERROR - $($_.Exception.Message)"
    }
}

Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "           VERIFICADOR SSL - PDF SIGNER" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Servidor: $ServerIP" -ForegroundColor White
Write-Host "Fecha: $(Get-Date)" -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan

Write-Host "`n[1] VERIFICANDO PUERTOS..." -ForegroundColor Yellow

# Puerto 80 (HTTP)
Write-Host "Puerto 80 (HTTP): " -NoNewline
if (Test-Port -Computer $ServerIP -Port 80) {
    Write-Host "ABIERTO" -ForegroundColor Green
    $port80 = $true
} else {
    Write-Host "CERRADO" -ForegroundColor Red
    $port80 = $false
}

# Puerto 443 (HTTPS)
Write-Host "Puerto 443 (HTTPS): " -NoNewline
if (Test-Port -Computer $ServerIP -Port 443) {
    Write-Host "ABIERTO" -ForegroundColor Green
    $port443 = $true
} else {
    Write-Host "CERRADO" -ForegroundColor Red
    $port443 = $false
}

# Puerto 8080 (Tomcat)
Write-Host "Puerto 8080 (Tomcat): " -NoNewline
if (Test-Port -Computer $ServerIP -Port 8080) {
    Write-Host "ABIERTO" -ForegroundColor Green
    $port8080 = $true
} else {
    Write-Host "CERRADO" -ForegroundColor Red
    $port8080 = $false
}

Write-Host "`n[2] PROBANDO URLS HTTP..." -ForegroundColor Yellow

if ($port80) {
    $httpUrls = @(
        "http://$ServerIP/",
        "http://$ServerIP/pdf-signer/",
        "http://$ServerIP/pdf-signer/api/health"
    )
    
    foreach ($url in $httpUrls) {
        Write-Host "$url : " -NoNewline
        $result = Test-Url -Url $url
        if ($result -like "OK*") {
            Write-Host $result -ForegroundColor Green
        } else {
            Write-Host $result -ForegroundColor Red
            if ($result -like "*blocked*" -or $result -like "*firewall*") {
                Write-Host "  -> Posible bloqueo de firewall corporativo" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "Puerto 80 cerrado - saltando pruebas HTTP" -ForegroundColor Yellow
}

Write-Host "`n[3] PROBANDO URLS HTTPS..." -ForegroundColor Yellow

if ($port443) {
    $httpsUrls = @(
        "https://$ServerIP/",
        "https://$ServerIP/pdf-signer/",
        "https://$ServerIP/pdf-signer/api/health"
    )
    
    foreach ($url in $httpsUrls) {
        Write-Host "$url : " -NoNewline
        $result = Test-Url -Url $url
        if ($result -like "OK*") {
            Write-Host $result -ForegroundColor Green
        } else {
            Write-Host $result -ForegroundColor Red
            if ($result -like "*blocked*" -or $result -like "*firewall*") {
                Write-Host "  -> Posible bloqueo de firewall corporativo" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "Puerto 443 cerrado - saltando pruebas HTTPS" -ForegroundColor Yellow
}

Write-Host "`n[4] PROBANDO TOMCAT DIRECTO..." -ForegroundColor Yellow

if ($port8080) {
    $tomcatUrls = @(
        "http://$ServerIP:8080/",
        "http://$ServerIP:8080/pdf-signer/"
    )
    
    foreach ($url in $tomcatUrls) {
        Write-Host "$url : " -NoNewline
        $result = Test-Url -Url $url
        if ($result -like "OK*") {
            Write-Host $result -ForegroundColor Green
        } else {
            Write-Host $result -ForegroundColor Red
        }
    }
} else {
    Write-Host "Puerto 8080 cerrado - saltando pruebas Tomcat" -ForegroundColor Yellow
}

Write-Host "`n[5] RESUMEN" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan

Write-Host "ESTADO DE PUERTOS:" -ForegroundColor White
Write-Host "  HTTP (80): $(if ($port80) { 'DISPONIBLE' } else { 'NO DISPONIBLE' })" -ForegroundColor $(if ($port80) { 'Green' } else { 'Red' })
Write-Host "  HTTPS (443): $(if ($port443) { 'DISPONIBLE' } else { 'NO DISPONIBLE' })" -ForegroundColor $(if ($port443) { 'Green' } else { 'Red' })
Write-Host "  Tomcat (8080): $(if ($port8080) { 'DISPONIBLE' } else { 'NO DISPONIBLE' })" -ForegroundColor $(if ($port8080) { 'Green' } else { 'Red' })

Write-Host "`nRECOMENDACIONES:" -ForegroundColor White

if (-not $port443) {
    Write-Host "  1. Configurar SSL en el servidor:" -ForegroundColor Yellow
    Write-Host "     sudo ./setup-ssl-letsencrypt.sh tu-dominio.com" -ForegroundColor Gray
    Write-Host "     # o para IP: sudo ./setup-ssl-letsencrypt.sh $ServerIP" -ForegroundColor Gray
}

if ($port80 -or $port443) {
    Write-Host "  2. Para evitar bloqueos de firewall:" -ForegroundColor Yellow
    Write-Host "     - Usar HTTPS en lugar de HTTP" -ForegroundColor Gray
    Write-Host "     - Solicitar excepcion al administrador de red" -ForegroundColor Gray
    Write-Host "     - Usar herramientas como Postman" -ForegroundColor Gray
}

Write-Host "`nCOMANDOS UTILES:" -ForegroundColor White
Write-Host "  # Probar manualmente:" -ForegroundColor Gray
Write-Host "  Invoke-WebRequest -Uri 'https://$ServerIP/pdf-signer/' -SkipCertificateCheck" -ForegroundColor Gray

Write-Host "`n=================================================================" -ForegroundColor Cyan
if ($port443) {
    Write-Host "           SSL/HTTPS ESTA DISPONIBLE" -ForegroundColor Green
    Write-Host "    Accede a: https://$ServerIP/pdf-signer/" -ForegroundColor White
} else {
    Write-Host "           SSL/HTTPS NO ESTA DISPONIBLE" -ForegroundColor Red
    Write-Host "    Configura SSL en el servidor primero" -ForegroundColor White
}
Write-Host "=================================================================" -ForegroundColor Cyan

Write-Host "`nPresiona Enter para continuar..." -ForegroundColor Gray
Read-Host