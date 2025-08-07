<#
.SYNOPSIS
    Script de limpieza de documentos PDF para USIV

.DESCRIPTION
    Este script mueve archivos PDF antiguos a una carpeta de papelera y elimina
    automáticamente archivos de la papelera después de un período configurable.

.PARAMETER BasePath
    Ruta base donde se almacenan los PDFs

.PARAMETER TrashPath
    Ruta de la carpeta de papelera

.PARAMETER RetentionMonths
    Número de meses de retención antes de mover a papelera

.PARAMETER TrashRetentionDays
    Número de días de retención en papelera antes de eliminar

.PARAMETER DryRun
    Ejecutar en modo simulación sin realizar cambios

.PARAMETER Force
    Ejecutar sin solicitar confirmación

.PARAMETER Verbose
    Mostrar información detallada

.PARAMETER LogFile
    Archivo de log personalizado

.EXAMPLE
    .\cleanup-documents.ps1
    Ejecutar con configuración por defecto

.EXAMPLE
    .\cleanup-documents.ps1 -DryRun
    Simular limpieza sin realizar cambios

.EXAMPLE
    .\cleanup-documents.ps1 -RetentionMonths 3 -Force
    Retener archivos por 3 meses y ejecutar sin confirmación

.NOTES
    Autor: USIV Development Team
    Versión: 1.0
#>

param(
    [string]$BasePath = $env:PDF_STORAGE_BASE_PATH ?? "./storage/pdfs",
    [string]$TrashPath = $env:PDF_TRASH_PATH ?? "./storage/trash",
    [int]$RetentionMonths = [int]($env:PDF_RETENTION_MONTHS ?? 6),
    [int]$TrashRetentionDays = [int]($env:PDF_TRASH_RETENTION_DAYS ?? 30),
    [string]$LogFile = $env:PDF_CLEANUP_LOG ?? "./logs/cleanup.log",
    [switch]$DryRun = [bool]($env:PDF_DRY_RUN ?? $false),
    [switch]$Force,
    [switch]$Verbose,
    [switch]$Help
)

# Configuración de colores
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
    White = "White"
}

# Función para logging
function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Escribir a consola con colores
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor $Colors.Red }
        "WARN" { Write-Host $logMessage -ForegroundColor $Colors.Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor $Colors.Green }
        "DEBUG" { if ($Verbose) { Write-Host $logMessage -ForegroundColor $Colors.Cyan } }
        default { Write-Host $logMessage }
    }
    
    # Escribir a archivo de log
    try {
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logMessage -Encoding UTF8
    }
    catch {
        Write-Warning "No se pudo escribir al archivo de log: $($_.Exception.Message)"
    }
}

# Función para mostrar ayuda
function Show-Help {
    Write-Host @"
Script de Limpieza de Documentos PDF - USIV

USO:
    .\cleanup-documents.ps1 [PARÁMETROS]

PARÁMETROS:
    -BasePath <ruta>           Ruta base de almacenamiento de PDFs
    -TrashPath <ruta>          Ruta de la papelera
    -RetentionMonths <número>  Meses de retención antes de mover a papelera
    -TrashRetentionDays <número> Días de retención en papelera
    -LogFile <archivo>         Archivo de log personalizado
    -DryRun                    Ejecutar en modo simulación
    -Force                     Ejecutar sin confirmación
    -Verbose                   Mostrar información detallada
    -Help                      Mostrar esta ayuda

VARIABLES DE ENTORNO:
    PDF_STORAGE_BASE_PATH      Ruta base de almacenamiento
    PDF_TRASH_PATH             Ruta de la papelera
    PDF_RETENTION_MONTHS       Meses de retención
    PDF_TRASH_RETENTION_DAYS   Días en papelera
    PDF_CLEANUP_LOG            Archivo de log
    PDF_DRY_RUN               Modo simulación (true/false)

EJEMPLOS:
    .\cleanup-documents.ps1
    .\cleanup-documents.ps1 -DryRun
    .\cleanup-documents.ps1 -RetentionMonths 3 -Force
    .\cleanup-documents.ps1 -Verbose -LogFile "C:\logs\cleanup.log"

"@ -ForegroundColor $Colors.White
}

# Función para formatear tamaños
function Format-FileSize {
    param([long]$Size)
    
    $units = @("B", "KB", "MB", "GB", "TB")
    $index = 0
    $sizeDouble = [double]$Size
    
    while ($sizeDouble -ge 1024 -and $index -lt $units.Length - 1) {
        $sizeDouble /= 1024
        $index++
    }
    
    return "{0:N2} {1}" -f $sizeDouble, $units[$index]
}

# Función para configurar directorios
function Initialize-Directories {
    Write-Log "INFO" "Configurando directorios..."
    
    # Crear directorio de logs
    $logDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $logDir)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Write-Log "INFO" "Directorio de logs: $logDir"
    }
    
    # Crear directorio de papelera
    if (-not (Test-Path $TrashPath)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $TrashPath -Force | Out-Null
        }
        Write-Log "INFO" "Directorio de papelera: $TrashPath"
    }
    
    # Verificar que existe el directorio base
    if (-not (Test-Path $BasePath)) {
        Write-Log "ERROR" "Directorio base no existe: $BasePath"
        exit 1
    }
}

# Función para mover archivos antiguos
function Move-OldFiles {
    Write-Log "INFO" "Buscando archivos antiguos (más de $RetentionMonths meses)..."
    
    # Calcular fecha límite
    $cutoffDate = (Get-Date).AddMonths(-$RetentionMonths)
    
    $movedCount = 0
    $totalSize = 0
    
    # Buscar archivos PDF antiguos
    $oldFiles = Get-ChildItem -Path $BasePath -Filter "*.pdf" -Recurse -File | 
                Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($file in $oldFiles) {
        # Calcular ruta de destino manteniendo estructura
        $relativePath = $file.FullName.Substring($BasePath.Length + 1)
        $destFile = Join-Path $TrashPath $relativePath
        $destDir = Split-Path $destFile -Parent
        
        $fileSize = $file.Length
        $totalSize += $fileSize
        
        Write-Log "INFO" "Moviendo a papelera: $relativePath ($(Format-FileSize $fileSize))"
        
        if (-not $DryRun) {
            try {
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Move-Item -Path $file.FullName -Destination $destFile -Force
                $movedCount++
            }
            catch {
                Write-Log "ERROR" "Error al mover archivo: $($file.FullName) - $($_.Exception.Message)"
            }
        }
        else {
            $movedCount++
        }
    }
    
    Write-Log "INFO" "Archivos movidos a papelera: $movedCount ($(Format-FileSize $totalSize))"
}

# Función para limpiar papelera
function Clear-Trash {
    Write-Log "INFO" "Limpiando papelera (archivos más antiguos de $TrashRetentionDays días)..."
    
    if (-not (Test-Path $TrashPath)) {
        Write-Log "INFO" "Directorio de papelera no existe, omitiendo limpieza"
        return
    }
    
    $deletedCount = 0
    $totalSize = 0
    
    # Calcular fecha límite para papelera
    $trashCutoffDate = (Get-Date).AddDays(-$TrashRetentionDays)
    
    # Buscar archivos en papelera más antiguos que el período de retención
    $trashFiles = Get-ChildItem -Path $TrashPath -Filter "*.pdf" -Recurse -File | 
                  Where-Object { $_.LastWriteTime -lt $trashCutoffDate }
    
    foreach ($file in $trashFiles) {
        $relativePath = $file.FullName.Substring($TrashPath.Length + 1)
        $fileSize = $file.Length
        $totalSize += $fileSize
        
        Write-Log "INFO" "Eliminando permanentemente: $relativePath ($(Format-FileSize $fileSize))"
        
        if (-not $DryRun) {
            try {
                Remove-Item -Path $file.FullName -Force
                $deletedCount++
            }
            catch {
                Write-Log "ERROR" "Error al eliminar archivo: $($file.FullName) - $($_.Exception.Message)"
            }
        }
        else {
            $deletedCount++
        }
    }
    
    Write-Log "INFO" "Archivos eliminados permanentemente: $deletedCount ($(Format-FileSize $totalSize))"
    
    # Limpiar directorios vacíos en papelera
    if (-not $DryRun) {
        try {
            Get-ChildItem -Path $TrashPath -Recurse -Directory | 
            Where-Object { (Get-ChildItem $_.FullName -Force | Measure-Object).Count -eq 0 } | 
            Remove-Item -Force -Recurse
        }
        catch {
            Write-Log "WARN" "No se pudieron eliminar algunos directorios vacíos: $($_.Exception.Message)"
        }
    }
}

# Función para mostrar estadísticas
function Show-Statistics {
    Write-Log "INFO" "=== ESTADÍSTICAS ==="
    
    if (Test-Path $BasePath) {
        $activeFiles = Get-ChildItem -Path $BasePath -Filter "*.pdf" -Recurse -File
        $activeCount = $activeFiles.Count
        $activeSize = ($activeFiles | Measure-Object -Property Length -Sum).Sum
        Write-Log "INFO" "Archivos activos: $activeCount ($(Format-FileSize $activeSize))"
    }
    
    if (Test-Path $TrashPath) {
        $trashFiles = Get-ChildItem -Path $TrashPath -Filter "*.pdf" -Recurse -File
        $trashCount = $trashFiles.Count
        $trashSize = ($trashFiles | Measure-Object -Property Length -Sum).Sum
        Write-Log "INFO" "Archivos en papelera: $trashCount ($(Format-FileSize $trashSize))"
    }
    
    Write-Log "INFO" "==================="
}

# Función principal
function Main {
    # Mostrar ayuda si se solicita
    if ($Help) {
        Show-Help
        return
    }
    
    # Convertir rutas a absolutas
    $script:BasePath = Resolve-Path $BasePath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
    if (-not $script:BasePath) {
        $script:BasePath = $BasePath
    }
    
    # Mostrar configuración
    Write-Log "INFO" "=== CONFIGURACIÓN ==="
    Write-Log "INFO" "Ruta base: $BasePath"
    Write-Log "INFO" "Ruta papelera: $TrashPath"
    Write-Log "INFO" "Retención (meses): $RetentionMonths"
    Write-Log "INFO" "Retención papelera (días): $TrashRetentionDays"
    Write-Log "INFO" "Archivo de log: $LogFile"
    Write-Log "INFO" "Modo simulación: $DryRun"
    Write-Log "INFO" "====================="
    
    # Configurar directorios
    Initialize-Directories
    
    # Mostrar estadísticas iniciales
    if ($Verbose) {
        Show-Statistics
    }
    
    # Confirmación si no es modo forzado
    if (-not $Force -and -not $DryRun) {
        $response = Read-Host "¿Continuar con la limpieza? (y/N)"
        if ($response -notmatch "^[Yy]$") {
            Write-Log "INFO" "Operación cancelada por el usuario"
            return
        }
    }
    
    # Ejecutar limpieza
    Write-Log "INFO" "Iniciando proceso de limpieza..."
    
    Move-OldFiles
    Clear-Trash
    
    # Mostrar estadísticas finales
    Show-Statistics
    
    if ($DryRun) {
        Write-Log "INFO" "Simulación completada. Ejecute sin -DryRun para realizar los cambios."
    }
    else {
        Write-Log "INFO" "Proceso de limpieza completado exitosamente."
    }
}

# Manejo de errores global
trap {
    Write-Log "ERROR" "Error no manejado: $($_.Exception.Message)"
    Write-Log "ERROR" "Línea: $($_.InvocationInfo.ScriptLineNumber)"
    exit 1
}

# Ejecutar función principal
Main