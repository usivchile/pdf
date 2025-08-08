#!/bin/bash

# Script para diagnosticar problemas específicos de Nginx
# Cuando Tomcat funciona pero Nginx no puede hacer proxy

set -e

echo "🔍 DIAGNÓSTICO AVANZADO DE NGINX"
echo "═══════════════════════════════════════════════════════════════════"
echo "    🎯 Objetivo: Identificar por qué Nginx no puede hacer proxy a Tomcat"
echo "    📅 $(date)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Variables
DOMAIN="validador.usiv.cl"
NGINX_CONFIG="/etc/nginx/conf.d/pdf-signer.conf"
NGINX_SITES_CONFIG="/etc/nginx/sites-available/pdf-signer"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled/pdf-signer"

# Función para logging
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1"
}

log_warning() {
    echo "⚠️  $1"
}

echo "🔍 PASO 1: VERIFICANDO CONFIGURACIÓN DE NGINX"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar archivos de configuración
log_info "Buscando archivos de configuración de Nginx..."
for config in "$NGINX_CONFIG" "$NGINX_SITES_CONFIG"; do
    if [ -f "$config" ]; then
        log_success "Encontrado: $config"
        echo "    Tamaño: $(stat -c%s "$config") bytes"
        echo "    Modificado: $(stat -c%y "$config")"
    else
        log_warning "No encontrado: $config"
    fi
done

# Verificar enlace simbólico
if [ -L "$NGINX_SITES_ENABLED" ]; then
    log_success "Enlace simbólico existe: $NGINX_SITES_ENABLED"
    echo "    Apunta a: $(readlink "$NGINX_SITES_ENABLED")"
else
    log_warning "Enlace simbólico no existe: $NGINX_SITES_ENABLED"
fi

# Mostrar configuración activa
echo ""
log_info "Mostrando configuración de Nginx para PDF Signer..."
if [ -f "$NGINX_CONFIG" ]; then
    echo "--- INICIO DE CONFIGURACIÓN ---"
    cat "$NGINX_CONFIG"
    echo "--- FIN DE CONFIGURACIÓN ---"
elif [ -f "$NGINX_SITES_CONFIG" ]; then
    echo "--- INICIO DE CONFIGURACIÓN ---"
    cat "$NGINX_SITES_CONFIG"
    echo "--- FIN DE CONFIGURACIÓN ---"
else
    log_error "No se encontró ninguna configuración de PDF Signer"
fi

echo ""
echo "🔍 PASO 2: VERIFICANDO SINTAXIS Y CONFIGURACIÓN"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar sintaxis de Nginx
log_info "Verificando sintaxis de Nginx..."
if nginx -t 2>&1; then
    log_success "Sintaxis de Nginx correcta"
else
    log_error "Error en la sintaxis de Nginx"
fi

# Verificar configuración cargada
log_info "Verificando configuración cargada..."
nginx -T 2>/dev/null | grep -A 20 -B 5 "pdf-signer" || log_warning "No se encontró configuración de pdf-signer en la configuración cargada"

echo ""
echo "🔍 PASO 3: VERIFICANDO LOGS DE ERROR"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar logs de error de Nginx
log_info "Verificando logs de error de Nginx..."
ERROR_LOG="/var/log/nginx/error.log"
if [ -f "$ERROR_LOG" ]; then
    log_info "Últimas 20 líneas del log de error general:"
    tail -20 "$ERROR_LOG" | while read line; do
        echo "    $line"
    done
else
    log_warning "Log de error general no encontrado: $ERROR_LOG"
fi

# Verificar logs específicos de PDF Signer
for log_file in "/var/log/nginx/pdf-signer.error.log" "/var/log/nginx/pdf-signer-ssl.error.log"; do
    if [ -f "$log_file" ]; then
        log_info "Últimas líneas de $log_file:"
        tail -10 "$log_file" | while read line; do
            echo "    $line"
        done
    else
        log_warning "Log específico no encontrado: $log_file"
    fi
done

echo ""
echo "🔍 PASO 4: PRUEBAS DE CONECTIVIDAD DETALLADAS"
echo "═══════════════════════════════════════════════════════════════════"

# Probar Tomcat directo con más detalle
log_info "Probando Tomcat directo con detalles..."
echo "    Comando: curl -v http://localhost:8080/pdf-signer/"
curl -v http://localhost:8080/pdf-signer/ 2>&1 | head -20

echo ""
log_info "Probando Nginx HTTP con detalles..."
echo "    Comando: curl -v http://localhost/pdf-signer/"
curl -v http://localhost/pdf-signer/ 2>&1 | head -20

echo ""
log_info "Probando Nginx HTTPS con detalles..."
echo "    Comando: curl -v -k https://localhost/pdf-signer/"
curl -v -k https://localhost/pdf-signer/ 2>&1 | head -20

echo ""
echo "🔍 PASO 5: VERIFICANDO PROCESOS Y PUERTOS"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar procesos de Nginx
log_info "Procesos de Nginx:"
ps aux | grep nginx | grep -v grep

# Verificar qué está escuchando en los puertos
log_info "Servicios escuchando en puertos relevantes:"
netstat -tlnp | grep -E ":(80|443|8080) "

echo ""
echo "🔍 PASO 6: VERIFICANDO CONFIGURACIÓN DEL SISTEMA"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar SELinux (si está presente)
if command -v getenforce &> /dev/null; then
    log_info "Estado de SELinux: $(getenforce)"
    if [ "$(getenforce)" = "Enforcing" ]; then
        log_warning "SELinux está en modo Enforcing, puede estar bloqueando conexiones"
        log_info "Verificando contextos de SELinux para Nginx..."
        setsebool -P httpd_can_network_connect on 2>/dev/null || log_warning "No se pudo configurar httpd_can_network_connect"
    fi
else
    log_info "SELinux no está presente"
fi

# Verificar firewall
log_info "Verificando reglas de firewall..."
if command -v iptables &> /dev/null; then
    iptables -L -n | grep -E "(80|443|8080)" || log_info "No se encontraron reglas específicas para puertos web"
fi

echo ""
echo "🔍 PASO 7: INTENTANDO REPARACIÓN AUTOMÁTICA"
echo "═══════════════════════════════════════════════════════════════════"

# Intentar recrear configuración básica
log_info "Recreando configuración básica de Nginx..."

# Backup de configuración actual
if [ -f "$NGINX_CONFIG" ]; then
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.debug.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Crear configuración mínima funcional
cat > "$NGINX_CONFIG" << 'EOF'
# Configuración mínima para PDF Signer - Debug
server {
    listen 80;
    server_name validador.usiv.cl;
    
    # Log detallado para debug
    access_log /var/log/nginx/pdf-signer-debug.access.log;
    error_log /var/log/nginx/pdf-signer-debug.error.log debug;
    
    location /pdf-signer/ {
        proxy_pass http://127.0.0.1:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts más largos para debug
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    location = / {
        return 301 /pdf-signer/;
    }
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name validador.usiv.cl;
    
    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/validador.usiv.cl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/validador.usiv.cl/privkey.pem;
    
    # Log detallado para debug
    access_log /var/log/nginx/pdf-signer-debug-ssl.access.log;
    error_log /var/log/nginx/pdf-signer-debug-ssl.error.log debug;
    
    location /pdf-signer/ {
        proxy_pass http://127.0.0.1:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts más largos para debug
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    location = / {
        return 301 /pdf-signer/;
    }
}
EOF

log_success "Configuración mínima creada"

# Verificar sintaxis
if nginx -t; then
    log_success "Sintaxis correcta, recargando Nginx..."
    systemctl reload nginx
    log_success "Nginx recargado"
else
    log_error "Error en la sintaxis de la nueva configuración"
fi

echo ""
echo "🔍 PASO 8: PRUEBAS FINALES"
echo "═══════════════════════════════════════════════════════════════════"

# Esperar un momento para que Nginx se estabilice
sleep 3

# Probar nuevamente
log_info "Probando conectividad después de la reparación..."

echo -n "  🐱 Tomcat directo: "
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/pdf-signer/" | grep -q "200\|302\|404"; then
    echo "✅ OK"
else
    echo "❌ FALLO"
fi

echo -n "  🌐 Nginx HTTP: "
if curl -s -o /dev/null -w "%{http_code}" "http://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
    echo "✅ OK"
else
    echo "❌ FALLO"
    # Mostrar error específico
    echo "    Error: $(curl -s http://localhost/pdf-signer/ 2>&1 | head -1)"
fi

echo -n "  🔒 Nginx HTTPS: "
if curl -s -k -o /dev/null -w "%{http_code}" "https://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
    echo "✅ OK"
else
    echo "❌ FALLO"
    # Mostrar error específico
    echo "    Error: $(curl -s -k https://localhost/pdf-signer/ 2>&1 | head -1)"
fi

echo ""
echo "📋 RESUMEN DEL DIAGNÓSTICO"
echo "═══════════════════════════════════════════════════════════════════"
echo "    📁 Configuración: $NGINX_CONFIG"
echo "    🔍 Logs de debug: /var/log/nginx/pdf-signer-debug*.log"
echo "    🐱 Tomcat: $(systemctl is-active tomcat)"
echo "    🌐 Nginx: $(systemctl is-active nginx)"
echo ""
echo "🔧 COMANDOS PARA SEGUIMIENTO:"
echo "    tail -f /var/log/nginx/pdf-signer-debug*.log  # Ver logs en tiempo real"
echo "    nginx -t  # Verificar configuración"
echo "    systemctl status nginx  # Ver estado detallado"
echo "    curl -v http://localhost/pdf-signer/  # Probar con detalles"
echo ""
log_info "Diagnóstico completado. Revisa los logs para más detalles."
echo "═══════════════════════════════════════════════════════════════════"