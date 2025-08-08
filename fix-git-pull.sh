#!/bin/bash

# Script para solucionar el conflicto de git pull en el VPS
# Limpia archivos target/ y permite el pull exitoso

echo "=== SOLUCIONANDO CONFLICTO DE GIT PULL ==="
echo "Fecha: $(date)"
echo

# Verificar que estamos en el directorio correcto
if [ ! -f "pom.xml" ]; then
    echo "❌ ERROR: No se encuentra pom.xml. Asegúrate de estar en el directorio del proyecto."
    exit 1
fi

echo "✅ Directorio del proyecto confirmado"
echo

# Mostrar estado actual de git
echo "📋 Estado actual de Git:"
git status --porcelain
echo

# Limpiar directorio target/ completamente
echo "🧹 Limpiando directorio target/..."
if [ -d "target" ]; then
    rm -rf target/
    echo "✅ Directorio target/ eliminado"
else
    echo "ℹ️ Directorio target/ no existe"
fi
echo

# Limpiar archivos temporales de Maven
echo "🧹 Limpiando archivos temporales..."
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.log" -delete 2>/dev/null || true
echo "✅ Archivos temporales limpiados"
echo

# Verificar archivos no rastreados
echo "🔍 Verificando archivos no rastreados..."
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo "📁 Archivos no rastreados encontrados:"
    echo "$UNTRACKED"
    echo
    
    # Preguntar si eliminar archivos no rastreados
    read -p "¿Eliminar todos los archivos no rastreados? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git clean -fd
        echo "✅ Archivos no rastreados eliminados"
    else
        echo "ℹ️ Archivos no rastreados mantenidos"
    fi
else
    echo "✅ No hay archivos no rastreados"
fi
echo

# Intentar git pull
echo "📥 Intentando git pull..."
if git pull; then
    echo "✅ Git pull exitoso"
else
    echo "❌ Git pull falló. Intentando reset hard..."
    
    # Mostrar información del remote
    echo "📋 Información del repositorio remoto:"
    git remote -v
    git branch -a
    echo
    
    # Preguntar si hacer reset hard
    read -p "¿Hacer git reset --hard origin/main? ESTO ELIMINARÁ CAMBIOS LOCALES (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git fetch origin
        git reset --hard origin/main
        echo "✅ Reset hard completado"
    else
        echo "❌ Reset cancelado. Resuelve manualmente los conflictos."
        exit 1
    fi
fi
echo

# Verificar estado final
echo "🔍 Estado final de Git:"
git status
echo

# Recompilar proyecto
echo "🔨 Recompilando proyecto..."
if command -v mvn &> /dev/null; then
    mvn clean package -DskipTests
    if [ $? -eq 0 ]; then
        echo "✅ Compilación exitosa"
        
        # Verificar que el WAR se generó correctamente
        if [ -f "target/pdf-signer-war-1.0.war" ]; then
            echo "✅ WAR generado: target/pdf-signer-war-1.0.war"
            
            # Verificar web.xml
            if unzip -l target/pdf-signer-war-1.0.war | grep -q "WEB-INF/web.xml"; then
                echo "✅ web.xml presente en el WAR"
            else
                echo "❌ web.xml NO encontrado en el WAR"
            fi
        else
            echo "❌ WAR no generado"
        fi
    else
        echo "❌ Error en la compilación"
    fi
else
    echo "⚠️ Maven no encontrado. Compila manualmente con: mvn clean package -DskipTests"
fi
echo

echo "=== PROCESO COMPLETADO ==="
echo "✅ Conflicto de git pull resuelto"
echo "📋 Próximos pasos:"
echo "   1. Verificar que el código esté actualizado"
echo "   2. Compilar si no se hizo automáticamente: mvn clean package -DskipTests"
echo "   3. Desplegar usando: ./deploy-fixed-war.sh o ./deploy-fixed-war.ps1"
echo