#!/bin/bash

# Script para desplegar el WAR corregido cuando ya estás EN el VPS
# Este script NO usa SSH, ejecuta todo localmente en el VPS

echo "=== DESPLEGANDO WAR DESDE VPS LOCAL ==="
echo "Fecha: $(date)"
echo

# Variables
LOCAL_WAR="target/pdf-signer-war-1.0.war"
TOMCAT_WEBAPPS="/var/lib/tomcat/webapps"
APP_NAME="pdf-signer"

# Verificar que estamos en el VPS
if [ ! -f "/etc/nginx/nginx.conf" ] || [ ! -d "/var/lib/tomcat" ]; then
    echo "❌ ERROR: Este script debe ejecutarse EN el VPS"
    echo "   No se detecta Nginx o Tomcat instalados"
    exit 1
fi

echo "✅ Ejecutándose en el VPS"
echo

# Verificar que el WAR local existe
if [ ! -f "$LOCAL_WAR" ]; then
    echo "❌ ERROR: No se encuentra el archivo WAR: $LOCAL_WAR"
    echo "   Asegúrate de haber compilado el proyecto:"
    echo "   mvn clean package -DskipTests"
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

# Detener Tomcat
echo "🛑 Deteniendo Tomcat..."
sudo systemctl stop tomcat
if [ $? -eq 0 ]; then
    echo "✅ Tomcat detenido"
else
    echo "❌ ERROR: No se pudo detener Tomcat"
    exit 1
fi
echo

# Limpiar despliegue anterior
echo "🧹 Limpiando despliegue anterior..."
sudo rm -rf $TOMCAT_WEBAPPS/pdf-signer*
echo "✅ Despliegue anterior eliminado"
echo

# Copiar nuevo WAR
echo "📋 Copiando nuevo WAR..."
sudo cp "$LOCAL_WAR" "$TOMCAT_WEBAPPS/pdf-signer.war"
sudo chown tomcat:tomcat "$TOMCAT_WEBAPPS/pdf-signer.war"
if [ $? -eq 0 ]; then
    echo "✅ WAR copiado y permisos asignados"
else
    echo "❌ ERROR: No se pudo copiar el WAR"
    exit 1
fi
echo

# Iniciar Tomcat
echo "▶️ Iniciando Tomcat..."
sudo systemctl start tomcat
if [ $? -eq 0 ]; then
    echo "✅ Tomcat iniciado"
else
    echo "❌ ERROR: No se pudo iniciar Tomcat"
    exit 1
fi
echo

# Esperar despliegue
echo "⏳ Esperando despliegue de la aplicación..."
sleep 15
echo

# Verificar despliegue
echo "🔍 Verificando despliegue..."
if [ -d "$TOMCAT_WEBAPPS/pdf-signer" ]; then
    echo "✅ Directorio de aplicación creado"
    
    # Verificar web.xml
    if [ -f "$TOMCAT_WEBAPPS/pdf-signer/WEB-INF/web.xml" ]; then
        echo "✅ web.xml presente en el despliegue"
        echo "📄 Contenido de web.xml:"
        head -10 "$TOMCAT_WEBAPPS/pdf-signer/WEB-INF/web.xml"
    else
        echo "❌ web.xml NO encontrado en el despliegue"
    fi
    
    # Verificar estructura
    echo "📁 Estructura del despliegue:"
    ls -la $TOMCAT_WEBAPPS/pdf-signer/WEB-INF/ | head -10
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
echo "Tomcat directo (puerto 8080):"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8080/pdf-signer/ || echo "❌ Falló"
echo
echo "Nginx HTTP (puerto 80):"
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost/pdf-signer/ || echo "❌ Falló"
echo
echo "Nginx HTTPS (puerto 443):"
curl -s -o /dev/null -w "Status: %{http_code}\n" https://localhost/pdf-signer/ -k || echo "❌ Falló"
echo

# Verificar puertos
echo "🔌 Puertos en uso:"
echo "Puerto 8080 (Tomcat): $(netstat -tlnp | grep :8080 | wc -l) conexiones"
echo "Puerto 80 (Nginx): $(netstat -tlnp | grep :80 | wc -l) conexiones"
echo "Puerto 443 (Nginx SSL): $(netstat -tlnp | grep :443 | wc -l) conexiones"
echo

echo "=== DESPLIEGUE COMPLETADO ==="
echo "✅ El WAR corregido ha sido desplegado localmente"
echo "🔧 Cambios realizados:"
echo "   - Clase principal extiende SpringBootServletInitializer"
echo "   - web.xml incluido en el WAR"
echo "   - Configuración correcta para Tomcat"
echo
echo "🌐 Prueba las URLs desde fuera del VPS:"
echo "   - https://validador.usiv.cl/pdf-signer/"
echo "   - https://validador.usiv.cl/pdf-signer/api/health"
echo "   - https://validador.usiv.cl/pdf-signer/swagger-ui/"
echo
echo "💡 Si hay problemas, revisa:"
echo "   - Logs de Tomcat: tail -f /var/lib/tomcat/logs/catalina.out"
echo "   - Logs de Nginx: tail -f /var/log/nginx/error.log"
echo "   - Estado de servicios: systemctl status tomcat nginx"
echo