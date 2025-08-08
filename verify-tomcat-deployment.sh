#!/bin/bash

# 🔍 SCRIPT DE VERIFICACIÓN DETALLADA DEL DESPLIEGUE DE TOMCAT
# ═══════════════════════════════════════════════════════════════════
# Este script verifica en detalle por qué Tomcat devuelve 404
# ═══════════════════════════════════════════════════════════════════

echo "🔍 VERIFICACIÓN DETALLADA DEL DESPLIEGUE DE TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"
echo "📅 $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# Función para mostrar mensajes con colores
show_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo "ℹ️  $message" ;;
        "success") echo "✅ $message" ;;
        "warning") echo "⚠️  $message" ;;
        "error") echo "❌ $message" ;;
    esac
}

# PASO 1: VERIFICAR ARCHIVOS WAR
echo
echo "🔍 PASO 1: VERIFICANDO ARCHIVOS WAR"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Buscando archivos WAR en el sistema..."
find / -name "*pdf-signer*.war" 2>/dev/null | while read war_file; do
    show_status "success" "WAR encontrado: $war_file"
    ls -la "$war_file"
done

show_status "info" "Verificando directorio webapps de Tomcat..."
ls -la /var/lib/tomcat/webapps/

if [ -f "/var/lib/tomcat/webapps/pdf-signer.war" ]; then
    show_status "success" "WAR desplegado encontrado"
    ls -la /var/lib/tomcat/webapps/pdf-signer.war
else
    show_status "error" "WAR no encontrado en webapps"
fi

# PASO 2: VERIFICAR DIRECTORIO DESPLEGADO
echo
echo "🔍 PASO 2: VERIFICANDO DIRECTORIO DESPLEGADO"
echo "═══════════════════════════════════════════════════════════════════"

if [ -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    show_status "success" "Directorio desplegado existe"
    show_status "info" "Contenido del directorio:"
    ls -la /var/lib/tomcat/webapps/pdf-signer/
    
    show_status "info" "Verificando estructura de la aplicación:"
    if [ -f "/var/lib/tomcat/webapps/pdf-signer/WEB-INF/web.xml" ]; then
        show_status "success" "web.xml encontrado"
        echo "--- CONTENIDO DE web.xml ---"
        cat /var/lib/tomcat/webapps/pdf-signer/WEB-INF/web.xml
        echo "--- FIN DE web.xml ---"
    else
        show_status "error" "web.xml NO encontrado"
    fi
    
    if [ -d "/var/lib/tomcat/webapps/pdf-signer/WEB-INF/classes" ]; then
        show_status "success" "Directorio classes encontrado"
        ls -la /var/lib/tomcat/webapps/pdf-signer/WEB-INF/classes/
    else
        show_status "error" "Directorio classes NO encontrado"
    fi
    
    if [ -d "/var/lib/tomcat/webapps/pdf-signer/WEB-INF/lib" ]; then
        show_status "success" "Directorio lib encontrado"
        ls -la /var/lib/tomcat/webapps/pdf-signer/WEB-INF/lib/ | head -10
    else
        show_status "error" "Directorio lib NO encontrado"
    fi
else
    show_status "error" "Directorio desplegado NO existe"
fi

# PASO 3: VERIFICAR LOGS DE TOMCAT
echo
echo "🔍 PASO 3: VERIFICANDO LOGS DE TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Buscando archivos de log de Tomcat..."
find /var/log -name "*tomcat*" -type f 2>/dev/null | while read log_file; do
    show_status "info" "Log encontrado: $log_file"
done

find /var/lib/tomcat/logs -name "*.log" -type f 2>/dev/null | while read log_file; do
    show_status "info" "Log encontrado: $log_file"
done

show_status "info" "Verificando logs principales..."
for log_path in "/var/log/tomcat/catalina.out" "/var/lib/tomcat/logs/catalina.out" "/opt/tomcat/logs/catalina.out"; do
    if [ -f "$log_path" ]; then
        show_status "success" "Log principal encontrado: $log_path"
        echo "--- ÚLTIMAS 30 LÍNEAS DE $log_path ---"
        tail -30 "$log_path"
        echo "--- FIN DEL LOG ---"
        break
    fi
done

show_status "info" "Verificando logs de localhost..."
for log_path in "/var/lib/tomcat/logs/localhost."*".log"; do
    if [ -f "$log_path" ]; then
        show_status "success" "Log localhost encontrado: $log_path"
        echo "--- CONTENIDO DE $log_path ---"
        cat "$log_path"
        echo "--- FIN DEL LOG ---"
    fi
done

# PASO 4: VERIFICAR CONFIGURACIÓN DE TOMCAT
echo
echo "🔍 PASO 4: VERIFICANDO CONFIGURACIÓN DE TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Verificando server.xml..."
if [ -f "/var/lib/tomcat/conf/server.xml" ]; then
    show_status "success" "server.xml encontrado"
    grep -A 10 -B 5 "8080" /var/lib/tomcat/conf/server.xml
elif [ -f "/etc/tomcat/server.xml" ]; then
    show_status "success" "server.xml encontrado en /etc/tomcat/"
    grep -A 10 -B 5 "8080" /etc/tomcat/server.xml
else
    show_status "error" "server.xml NO encontrado"
fi

# PASO 5: PROBAR TOMCAT DIRECTAMENTE
echo
echo "🔍 PASO 5: PROBANDO TOMCAT DIRECTAMENTE"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Probando página principal de Tomcat..."
curl -v http://localhost:8080/ 2>&1 | head -20

show_status "info" "Probando manager de Tomcat..."
curl -I http://localhost:8080/manager/ 2>/dev/null

show_status "info" "Listando aplicaciones desplegadas..."
curl -s http://localhost:8080/manager/text/list 2>/dev/null || show_status "warning" "Manager no accesible"

show_status "info" "Probando aplicación pdf-signer..."
echo "--- RESPUESTA COMPLETA DE /pdf-signer/ ---"
curl -v http://localhost:8080/pdf-signer/ 2>&1
echo "--- FIN DE RESPUESTA ---"

show_status "info" "Probando diferentes rutas de la aplicación..."
for path in "/pdf-signer" "/pdf-signer/index.html" "/pdf-signer/api" "/pdf-signer/api/health"; do
    echo "Probando: http://localhost:8080$path"
    curl -I http://localhost:8080$path 2>/dev/null
    echo
done

# PASO 6: VERIFICAR PROCESOS Y PUERTOS
echo
echo "🔍 PASO 6: VERIFICANDO PROCESOS Y PUERTOS"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Procesos Java ejecutándose..."
ps aux | grep java | grep -v grep

show_status "info" "Puertos en uso por Java..."
netstat -tlnp | grep java

show_status "info" "Verificando puerto 8080..."
netstat -tlnp | grep 8080

show_status "info" "Probando conectividad al puerto 8080..."
telnet localhost 8080 < /dev/null 2>&1 | head -5

echo
echo "📋 RESUMEN DE VERIFICACIÓN"
echo "═══════════════════════════════════════════════════════════════════"
show_status "info" "Verificación completada. Revisa los resultados arriba."
echo "═══════════════════════════════════════════════════════════════════"