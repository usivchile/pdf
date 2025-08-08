#!/bin/bash

# Script para diagnosticar problemas con logs de Tomcat y despliegue

echo "=== DIAGNÓSTICO DE TOMCAT Y DESPLIEGUE ==="
echo "Fecha: $(date)"
echo

# 1. Buscar archivos de log de Tomcat
echo "🔍 Buscando archivos de log de Tomcat..."
echo "Ubicaciones comunes de logs:"
for log_path in "/var/lib/tomcat/logs" "/var/log/tomcat" "/opt/tomcat/logs" "/usr/share/tomcat/logs" "/var/lib/tomcat9/logs" "/var/lib/tomcat10/logs"; do
    if [ -d "$log_path" ]; then
        echo "✅ Encontrado: $log_path"
        echo "   Archivos: $(ls -la $log_path 2>/dev/null | wc -l) archivos"
        echo "   Contenido:"
        ls -la "$log_path" 2>/dev/null | head -10
        echo
    else
        echo "❌ No existe: $log_path"
    fi
done
echo

# 2. Buscar catalina.out específicamente
echo "🔍 Buscando catalina.out en todo el sistema..."
find /var /opt /usr -name "catalina.out" 2>/dev/null | while read file; do
    echo "✅ Encontrado: $file"
    echo "   Tamaño: $(du -h "$file" 2>/dev/null | cut -f1)"
    echo "   Últimas 5 líneas:"
    tail -5 "$file" 2>/dev/null
    echo
done
echo

# 3. Verificar configuración de Tomcat
echo "🔧 Verificando configuración de Tomcat..."
echo "Servicio Tomcat:"
systemctl status tomcat --no-pager -l
echo

echo "Procesos de Tomcat:"
ps aux | grep tomcat | grep -v grep
echo

# 4. Verificar directorio de webapps
echo "📁 Verificando directorio webapps..."
for webapps_path in "/var/lib/tomcat/webapps" "/var/lib/tomcat9/webapps" "/var/lib/tomcat10/webapps" "/opt/tomcat/webapps"; do
    if [ -d "$webapps_path" ]; then
        echo "✅ Webapps encontrado: $webapps_path"
        echo "   Contenido:"
        ls -la "$webapps_path"
        echo
        
        # Verificar pdf-signer específicamente
        if [ -d "$webapps_path/pdf-signer" ]; then
            echo "✅ Aplicación pdf-signer encontrada"
            echo "   Estructura:"
            ls -la "$webapps_path/pdf-signer/"
            echo
            
            if [ -d "$webapps_path/pdf-signer/WEB-INF" ]; then
                echo "   WEB-INF contenido:"
                ls -la "$webapps_path/pdf-signer/WEB-INF/"
                echo
                
                if [ -f "$webapps_path/pdf-signer/WEB-INF/web.xml" ]; then
                    echo "✅ web.xml encontrado"
                    echo "   Primeras líneas:"
                    head -10 "$webapps_path/pdf-signer/WEB-INF/web.xml"
                else
                    echo "❌ web.xml NO encontrado"
                fi
            fi
        else
            echo "❌ Aplicación pdf-signer NO encontrada en $webapps_path"
        fi
        echo
    fi
done
echo

# 5. Verificar archivo WAR
echo "📦 Verificando archivo WAR..."
for webapps_path in "/var/lib/tomcat/webapps" "/var/lib/tomcat9/webapps" "/var/lib/tomcat10/webapps" "/opt/tomcat/webapps"; do
    if [ -f "$webapps_path/pdf-signer.war" ]; then
        echo "✅ WAR encontrado: $webapps_path/pdf-signer.war"
        echo "   Tamaño: $(du -h $webapps_path/pdf-signer.war | cut -f1)"
        echo "   Fecha: $(stat -c '%y' $webapps_path/pdf-signer.war)"
        echo "   Contenido del WAR:"
        unzip -l "$webapps_path/pdf-signer.war" | grep -E "(web.xml|WEB-INF|classes)"
        echo
    fi
done
echo

# 6. Verificar puertos y conexiones
echo "🔌 Verificando puertos..."
echo "Puerto 8080 (Tomcat):"
netstat -tlnp | grep :8080
echo
echo "Procesos escuchando en 8080:"
lsof -i :8080 2>/dev/null || echo "lsof no disponible"
echo

# 7. Probar conectividad interna
echo "🧪 Probando conectividad interna..."
echo "Tomcat directo:"
curl -v http://localhost:8080/ 2>&1 | head -20
echo
echo "Tomcat pdf-signer:"
curl -v http://localhost:8080/pdf-signer/ 2>&1 | head -20
echo

# 8. Verificar configuración de Nginx
echo "🌐 Verificando configuración de Nginx..."
echo "Estado de Nginx:"
systemctl status nginx --no-pager -l
echo
echo "Configuración de proxy:"
grep -r "pdf-signer" /etc/nginx/ 2>/dev/null || echo "No se encontró configuración de pdf-signer en Nginx"
echo

# 9. Verificar variables de entorno de Tomcat
echo "🔧 Variables de entorno de Tomcat..."
if [ -f "/etc/default/tomcat" ]; then
    echo "Archivo /etc/default/tomcat:"
    cat /etc/default/tomcat
elif [ -f "/etc/default/tomcat9" ]; then
    echo "Archivo /etc/default/tomcat9:"
    cat /etc/default/tomcat9
elif [ -f "/etc/default/tomcat10" ]; then
    echo "Archivo /etc/default/tomcat10:"
    cat /etc/default/tomcat10
else
    echo "No se encontró archivo de configuración por defecto"
fi
echo

echo "=== DIAGNÓSTICO COMPLETADO ==="
echo "💡 Revisa la información anterior para identificar:"
echo "   - Ubicación real de los logs de Tomcat"
echo "   - Estado del despliegue de pdf-signer"
echo "   - Problemas de configuración"
echo