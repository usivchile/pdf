#!/bin/bash

# Script para desplegar el WAR corregido con web.xml al VPS
# Este script sube el nuevo WAR y lo despliega correctamente

echo "=== DESPLEGANDO WAR CORREGIDO CON WEB.XML ==="
echo "Fecha: $(date)"
echo

# Variables
VPS_HOST="validador.usiv.cl"
VPS_USER="root"
LOCAL_WAR="target/pdf-signer-war-1.0.war"
REMOTE_WAR_PATH="/root/pdf-signer-war-1.0.war"
TOMCAT_WEBAPPS="/var/lib/tomcat/webapps"
APP_NAME="pdf-signer"

# Verificar que el WAR local existe
if [ ! -f "$LOCAL_WAR" ]; then
    echo "❌ ERROR: No se encuentra el archivo WAR: $LOCAL_WAR"
    echo "   Ejecuta primero: mvn clean package -DskipTests"
    exit 1
fi

echo "✅ WAR local encontrado: $LOCAL_WAR"
echo "📦 Tamaño: $(du -h $LOCAL_WAR | cut -f1)"
echo

# Verificar que el web.xml está presente
echo "🔍 Verificando presencia de web.xml..."
if unzip -l "$LOCAL_WAR" | grep -q "WEB-INF/web.xml"; then
    echo "✅ web.xml encontrado en el WAR"
else
    echo "❌ ERROR: web.xml NO encontrado en el WAR"
    echo "   El WAR no se generó correctamente"
    exit 1
fi
echo

# Subir WAR al VPS
echo "📤 Subiendo WAR al VPS..."
scp "$LOCAL_WAR" "$VPS_USER@$VPS_HOST:$REMOTE_WAR_PATH"
if [ $? -eq 0 ]; then
    echo "✅ WAR subido exitosamente"
else
    echo "❌ ERROR: Falló la subida del WAR"
    exit 1
fi
echo

# Ejecutar despliegue en el VPS
echo "🚀 Ejecutando despliegue en el VPS..."
ssh "$VPS_USER@$VPS_HOST" << 'EOF'
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
EOF

echo "=== DESPLIEGUE FINALIZADO ==="
echo "✅ El WAR corregido ha sido desplegado"
echo "🔧 Cambios realizados:"
echo "   - Clase principal extiende SpringBootServletInitializer"
echo "   - web.xml incluido en el WAR"
echo "   - Configuración correcta para Tomcat"
echo
echo "🌐 Prueba las URLs:"
echo "   - https://validador.usiv.cl/pdf-signer/"
echo "   - https://validador.usiv.cl/pdf-signer/api/health"
echo "   - https://validador.usiv.cl/pdf-signer/swagger-ui/"
echo