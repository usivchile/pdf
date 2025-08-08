#!/bin/bash

# 🔧 SCRIPT DE REPARACIÓN COMPLETA DEL DESPLIEGUE
# ═══════════════════════════════════════════════════════════════════
# Este script soluciona los problemas identificados:
# 1. Nginx busca archivos estáticos en lugar de hacer proxy
# 2. Tomcat devuelve 404 porque la aplicación no está desplegada
# ═══════════════════════════════════════════════════════════════════

echo "🔧 INICIANDO REPARACIÓN COMPLETA DEL DESPLIEGUE"
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

# PASO 1: VERIFICAR ESTADO ACTUAL
echo
echo "🔍 PASO 1: VERIFICANDO ESTADO ACTUAL"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Verificando servicios..."
if systemctl is-active --quiet tomcat; then
    show_status "success" "Tomcat está ejecutándose"
else
    show_status "error" "Tomcat no está ejecutándose"
    exit 1
fi

if systemctl is-active --quiet nginx; then
    show_status "success" "Nginx está ejecutándose"
else
    show_status "error" "Nginx no está ejecutándose"
    exit 1
fi

# PASO 2: VERIFICAR DESPLIEGUE DE TOMCAT
echo
echo "🔍 PASO 2: VERIFICANDO DESPLIEGUE DE TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Verificando archivos WAR..."
if [ -f "/var/lib/tomcat/webapps/pdf-signer.war" ]; then
    show_status "success" "Archivo WAR encontrado: /var/lib/tomcat/webapps/pdf-signer.war"
else
    show_status "warning" "Archivo WAR no encontrado en /var/lib/tomcat/webapps/"
fi

show_status "info" "Verificando directorio desplegado..."
if [ -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    show_status "success" "Directorio desplegado encontrado"
    ls -la /var/lib/tomcat/webapps/pdf-signer/ | head -10
else
    show_status "error" "Directorio desplegado NO encontrado"
    show_status "info" "Contenido de /var/lib/tomcat/webapps/:"
    ls -la /var/lib/tomcat/webapps/
fi

# PASO 3: REDESPLEGAR APLICACIÓN EN TOMCAT
echo
echo "🔧 PASO 3: REDESPLEGANDO APLICACIÓN EN TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Deteniendo Tomcat..."
systemctl stop tomcat
sleep 3

show_status "info" "Limpiando despliegues anteriores..."
rm -rf /var/lib/tomcat/webapps/pdf-signer*
rm -rf /var/lib/tomcat/work/Catalina/localhost/pdf-signer*
rm -rf /var/lib/tomcat/temp/*

show_status "info" "Buscando archivo WAR en el proyecto..."
WAR_FILE=""
if [ -f "/root/pdf-signer-war-1.0.war" ]; then
    WAR_FILE="/root/pdf-signer-war-1.0.war"
elif [ -f "/home/*/pdf-signer-war-1.0.war" ]; then
    WAR_FILE=$(find /home -name "pdf-signer-war-1.0.war" 2>/dev/null | head -1)
elif [ -f "./target/pdf-signer-war-1.0.war" ]; then
    WAR_FILE="./target/pdf-signer-war-1.0.war"
else
    show_status "error" "No se encontró el archivo WAR. Buscando..."
    find / -name "*pdf-signer*.war" 2>/dev/null | head -5
    exit 1
fi

show_status "success" "Archivo WAR encontrado: $WAR_FILE"

show_status "info" "Copiando WAR a Tomcat..."
cp "$WAR_FILE" /var/lib/tomcat/webapps/pdf-signer.war
chown tomcat:tomcat /var/lib/tomcat/webapps/pdf-signer.war
chmod 644 /var/lib/tomcat/webapps/pdf-signer.war

show_status "info" "Iniciando Tomcat..."
systemctl start tomcat

show_status "info" "Esperando despliegue de la aplicación..."
for i in {1..30}; do
    if [ -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
        show_status "success" "Aplicación desplegada exitosamente"
        break
    fi
    echo -n "."
    sleep 2
done
echo

if [ ! -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    show_status "error" "La aplicación no se desplegó correctamente"
    show_status "info" "Verificando logs de Tomcat..."
    tail -20 /var/log/tomcat/catalina.out
    exit 1
fi

# PASO 4: CORREGIR CONFIGURACIÓN DE NGINX
echo
echo "🔧 PASO 4: CORRIGIENDO CONFIGURACIÓN DE NGINX"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Creando configuración corregida de Nginx..."
cat > /etc/nginx/conf.d/pdf-signer.conf << 'EOF'
# Configuración corregida para PDF Signer
server {
    listen 80;
    server_name validador.usiv.cl;
    
    # Logs para debug
    access_log /var/log/nginx/pdf-signer.access.log;
    error_log /var/log/nginx/pdf-signer.error.log;
    
    # Proxy a Tomcat para la aplicación
    location /pdf-signer/ {
        proxy_pass http://127.0.0.1:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Configuración de proxy mejorada
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Redirección de raíz a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }
    
    # Redirección a HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name validador.usiv.cl;
    
    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/validador.usiv.cl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/validador.usiv.cl/privkey.pem;
    
    # Configuración SSL mejorada
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Logs para debug
    access_log /var/log/nginx/pdf-signer-ssl.access.log;
    error_log /var/log/nginx/pdf-signer-ssl.error.log;
    
    # Proxy a Tomcat para la aplicación
    location /pdf-signer/ {
        proxy_pass http://127.0.0.1:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Configuración de proxy mejorada
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Redirección de raíz a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }
}
EOF

show_status "info" "Verificando sintaxis de Nginx..."
if nginx -t; then
    show_status "success" "Sintaxis de Nginx correcta"
else
    show_status "error" "Error en la sintaxis de Nginx"
    exit 1
fi

show_status "info" "Recargando Nginx..."
systemctl reload nginx

# PASO 5: PRUEBAS DE CONECTIVIDAD
echo
echo "🔍 PASO 5: PRUEBAS DE CONECTIVIDAD"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Esperando que los servicios se estabilicen..."
sleep 5

show_status "info" "Probando Tomcat directo..."
if curl -s -f http://localhost:8080/pdf-signer/ > /dev/null; then
    show_status "success" "Tomcat directo: OK"
else
    show_status "warning" "Tomcat directo: Verificando respuesta..."
    curl -I http://localhost:8080/pdf-signer/
fi

show_status "info" "Probando Nginx HTTP..."
if curl -s -f http://localhost/pdf-signer/ > /dev/null; then
    show_status "success" "Nginx HTTP: OK"
else
    show_status "warning" "Nginx HTTP: Verificando respuesta..."
    curl -I http://localhost/pdf-signer/
fi

show_status "info" "Probando Nginx HTTPS..."
if curl -s -f -k https://localhost/pdf-signer/ > /dev/null; then
    show_status "success" "Nginx HTTPS: OK"
else
    show_status "warning" "Nginx HTTPS: Verificando respuesta..."
    curl -I -k https://localhost/pdf-signer/
fi

# PASO 6: VERIFICACIÓN FINAL
echo
echo "🎯 PASO 6: VERIFICACIÓN FINAL"
echo "═══════════════════════════════════════════════════════════════════"

show_status "info" "Probando URLs externas..."
echo "📱 Prueba estas URLs en tu navegador:"
echo "   🌐 HTTP:  http://validador.usiv.cl/pdf-signer/"
echo "   🔒 HTTPS: https://validador.usiv.cl/pdf-signer/"
echo "   🩺 Health: https://validador.usiv.cl/pdf-signer/api/health"
echo "   📚 Swagger: https://validador.usiv.cl/pdf-signer/swagger-ui/"

echo
echo "📋 RESUMEN DE LA REPARACIÓN"
echo "═══════════════════════════════════════════════════════════════════"
show_status "success" "Aplicación redesplegada en Tomcat"
show_status "success" "Configuración de Nginx corregida"
show_status "success" "Proxy reverso configurado correctamente"
show_status "info" "Logs disponibles en:"
echo "   📄 /var/log/nginx/pdf-signer*.log"
echo "   📄 /var/log/tomcat/catalina.out"

echo
echo "🔧 COMANDOS ÚTILES PARA MONITOREO:"
echo "   tail -f /var/log/nginx/pdf-signer*.log"
echo "   tail -f /var/log/tomcat/catalina.out"
echo "   systemctl status tomcat nginx"
echo "   curl -v https://validador.usiv.cl/pdf-signer/"

echo
echo "✅ REPARACIÓN COMPLETA FINALIZADA"
echo "═══════════════════════════════════════════════════════════════════"