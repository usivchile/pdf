# Script PowerShell para solucionar el conflicto de git pull en el VPS
# Limpia archivos target/ y permite el pull exitoso

Write-Host "=== SOLUCIONANDO CONFLICTO DE GIT PULL ===" -ForegroundColor Green
Write-Host "Fecha: $(Get-Date)" -ForegroundColor Gray
Write-Host

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "pom.xml")) {
    Write-Host "❌ ERROR: No se encuentra pom.xml. Asegúrate de estar en el directorio del proyecto." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Directorio del proyecto confirmado" -ForegroundColor Green
Write-Host

# Mostrar estado actual de git
Write-Host "📋 Estado actual de Git:" -ForegroundColor Yellow
try {
    git status --porcelain
} catch {
    Write-Host "⚠️ Error al obtener estado de git: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host

# Limpiar directorio target/ completamente
Write-Host "🧹 Limpiando directorio target/..." -ForegroundColor Yellow
if (Test-Path "target") {
    try {
        Remove-Item -Path "target" -Recurse -Force
        Write-Host "✅ Directorio target/ eliminado" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Error al eliminar target/: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️ Directorio target/ no existe" -ForegroundColor Cyan
}
Write-Host

# Limpiar archivos temporales
Write-Host "🧹 Limpiando archivos temporales..." -ForegroundColor Yellow
try {
    Get-ChildItem -Path . -Recurse -Include "*.tmp", "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Archivos temporales limpiados" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Error al limpiar archivos temporales: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host

# Verificar archivos no rastreados
Write-Host "🔍 Verificando archivos no rastreados..." -ForegroundColor Yellow
try {
    $untracked = git ls-files --others --exclude-standard
    if ($untracked) {
        Write-Host "📁 Archivos no rastreados encontrados:" -ForegroundColor Cyan
        $untracked | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
        Write-Host
        
        # Preguntar si eliminar archivos no rastreados
        $response = Read-Host "¿Eliminar todos los archivos no rastreados? (y/N)"
        if ($response -match '^[Yy]$') {
            git clean -fd
            Write-Host "✅ Archivos no rastreados eliminados" -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Archivos no rastreados mantenidos" -ForegroundColor Cyan
        }
    } else {
        Write-Host "✅ No hay archivos no rastreados" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Error al verificar archivos no rastreados: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host

# Intentar git pull
Write-Host "📥 Intentando git pull..." -ForegroundColor Yellow
try {
    git pull
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Git pull exitoso" -ForegroundColor Green
    } else {
        throw "Git pull falló con código $LASTEXITCODE"
    }
} catch {
    Write-Host "❌ Git pull falló. Intentando reset hard..." -ForegroundColor Red
    
    # Mostrar información del remote
    Write-Host "📋 Información del repositorio remoto:" -ForegroundColor Cyan
    try {
        git remote -v
        git branch -a
    } catch {
        Write-Host "⚠️ Error al obtener información del repositorio" -ForegroundColor Yellow
    }
    Write-Host
    
    # Preguntar si hacer reset hard
    $response = Read-Host "¿Hacer git reset --hard origin/main? ESTO ELIMINARÁ CAMBIOS LOCALES (y/N)"
    if ($response -match '^[Yy]$') {
        try {
            git fetch origin
            git reset --hard origin/main
            Write-Host "✅ Reset hard completado" -ForegroundColor Green
        } catch {
            Write-Host "❌ Error en reset hard: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "❌ Reset cancelado. Resuelve manualmente los conflictos." -ForegroundColor Red
        exit 1
    }
}
Write-Host

# Verificar estado final
Write-Host "🔍 Estado final de Git:" -ForegroundColor Yellow
try {
    git status
} catch {
    Write-Host "⚠️ Error al obtener estado final de git" -ForegroundColor Yellow
}
Write-Host

# Recompilar proyecto
Write-Host "🔨 Recompilando proyecto..." -ForegroundColor Yellow
try {
    if (Get-Command mvn -ErrorAction SilentlyContinue) {
        mvn clean package -DskipTests
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Compilación exitosa" -ForegroundColor Green
            
            # Verificar que el WAR se generó correctamente
            if (Test-Path "target\pdf-signer-war-1.0.war") {
                Write-Host "✅ WAR generado: target\pdf-signer-war-1.0.war" -ForegroundColor Green
                
                # Verificar web.xml
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $zip = [System.IO.Compression.ZipFile]::OpenRead("target\pdf-signer-war-1.0.war")
                    $webXmlEntry = $zip.Entries | Where-Object { $_.FullName -eq "WEB-INF/web.xml" }
                    $zip.Dispose()
                    
                    if ($webXmlEntry) {
                        Write-Host "✅ web.xml presente en el WAR" -ForegroundColor Green
                    } else {
                        Write-Host "❌ web.xml NO encontrado en el WAR" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "⚠️ Error al verificar web.xml en el WAR" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ WAR no generado" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Error en la compilación" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ Maven no encontrado. Compila manualmente con: mvn clean package -DskipTests" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error durante la compilación: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host

Write-Host "=== PROCESO COMPLETADO ===" -ForegroundColor Green
Write-Host "✅ Conflicto de git pull resuelto" -ForegroundColor Green
Write-Host "📋 Próximos pasos:" -ForegroundColor Cyan
Write-Host "   1. Verificar que el código esté actualizado" -ForegroundColor Gray
Write-Host "   2. Compilar si no se hizo automáticamente: mvn clean package -DskipTests" -ForegroundColor Gray
Write-Host "   3. Desplegar usando: .\deploy-fixed-war.ps1" -ForegroundColor Gray
Write-Host