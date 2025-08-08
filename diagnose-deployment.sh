#!/bin/bash

# SCRIPT DE DIAGNÓSTICO DE DESPLIEGUE
# Verifica por qué la aplicación no está disponible en HTTPS
# Autor: PDF Signer Team

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "\n${PURPLE}🔍 $1${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
}

echo "═══════════════════════════════════════════════════════════════════"
echo "                    🔍 DIAGNÓSTICO DE DESPLIEGUE"
echo "                     PDF Signer - validador.usiv.cl"
echo "═══════════════════════════════════════════════════════════════════"
echo "🕐 Fecha: $(date)"
echo "📁 Directorio: $(pwd)"
echo "═══════════════════════════════════════════════════════════════════"

# PASO 1: Verificar servicios básicos
log_step "VERIFICANDO SERVICIOS BÁSICOS"

log_info "Estado de Tomcat:"
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat está ejecutándose"
    systemctl status tomcat --no-pager -l
else
    log_error "Tomcat NO está ejecutándose"
    log_info "Intentando iniciar Tomcat..."
    systemctl start tomcat
    sleep 5
    if systemctl is-active --quiet tomcat; then
        log_success "Tomcat iniciado exitosamente"
    else
        log_error "Error al iniciar Tomcat"
        journalctl -u tomcat --no-pager -n 10
    fi
fi

echo
log_info "Estado de Nginx:"
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ejecutándose"
    nginx -t && log_success "Configuración de Nginx válida" || log_error "Error en configuración de Nginx"
else
    log_error "Nginx NO está ejecutándose"
    log_info "Intentando iniciar Nginx..."
    systemctl start nginx
    sleep 2
    if systemctl is-active --quiet nginx; then
        log_success "Nginx iniciado exitosamente"
    else
        log_error "Error al iniciar Nginx"
        journalctl -u nginx --no-pager -n 10
    fi
fi

# PASO 2: Verificar puertos
log_step "VERIFICANDO PUERTOS"

log_info "Puertos en uso:"
ss -tlnp | grep -E ':(80|443|8080) ' || log_warn "No se encontraron puertos 80, 443 o 8080 abiertos"

echo
log_info "Procesos escuchando en puertos clave:"
echo "Puerto 80 (HTTP):"
lsof -i :80 2>/dev/null || log_warn "Ningún proceso escuchando en puerto 80"

echo "Puerto 443 (HTTPS):"
lsof -i :443 2>/dev/null || log_warn "Ningún proceso escuchando en puerto 443"

echo "Puerto 8080 (Tomcat):"
lsof -i :8080 2>/dev/null || log_warn "Ningún proceso escuchando en puerto 8080"

# PASO 3: Verificar aplicación en Tomcat
log_step "VERIFICANDO APLICACIÓN EN TOMCAT"

TOMCAT_WEBAPPS="/var/lib/tomcat/webapps"
log_info "Contenido de $TOMCAT_WEBAPPS:"
ls -la "$TOMCAT_WEBAPPS" 2>/dev/null || log_error "No se puede acceder a $TOMCAT_WEBAPPS"

if [ -f "$TOMCAT_WEBAPPS/pdf-signer.war" ]; then
    log_success "Archivo WAR encontrado: pdf-signer.war"
    ls -la "$TOMCAT_WEBAPPS/pdf-signer.war"
else
    log_error "Archivo WAR NO encontrado: pdf-signer.war"
fi

if [ -d "$TOMCAT_WEBAPPS/pdf-signer" ]; then
    log_success "Aplicación desplegada encontrada: pdf-signer/"
    ls -la "$TOMCAT_WEBAPPS/pdf-signer" | head -10
else
    log_error "Aplicación desplegada NO encontrada: pdf-signer/"
    log_info "La aplicación puede no haberse desplegado correctamente"
fi

# PASO 4: Verificar logs de Tomcat
log_step "VERIFICANDO LOGS DE TOMCAT"

log_info "Últimas líneas del log de Tomcat:"
journalctl -u tomcat --no-pager -n 20

echo
log_info "Logs de catalina (si existen):"
if [ -f "/var/log/tomcat/catalina.out" ]; then
    tail -20 /var/log/tomcat/catalina.out
elif [ -f "/opt/tomcat/logs/catalina.out" ]; then
    tail -20 /opt/tomcat/logs/catalina.out
else
    log_warn "No se encontraron logs de catalina.out"
fi

# PASO 5: Verificar configuración de Nginx
log_step "VERIFICANDO CONFIGURACIÓN DE NGINX"

NGINX_CONF="/etc/nginx/conf.d/pdf-signer.conf"
if [ -f "$NGINX_CONF" ]; then
    log_success "Configuración de Nginx encontrada: $NGINX_CONF"
    echo "Contenido de la configuración:"
    cat "$NGINX_CONF"
else
    log_error "Configuración de Nginx NO encontrada: $NGINX_CONF"
    log_info "Buscando otras configuraciones..."
    find /etc/nginx -name "*pdf*" -o -name "*signer*" 2>/dev/null || log_warn "No se encontraron configuraciones relacionadas"
fi

echo
log_info "Verificando sintaxis de Nginx:"
nginx -t

# PASO 6: Verificar certificados SSL
log_step "VERIFICANDO CERTIFICADOS SSL"

log_info "Certificados de Let's Encrypt:"
if command -v certbot &> /dev/null; then
    certbot certificates
else
    log_warn "Certbot no está instalado"
fi

echo
log_info "Archivos de certificado:"
if [ -d "/etc/letsencrypt/live/validador.usiv.cl" ]; then
    ls -la /etc/letsencrypt/live/validador.usiv.cl/
else
    log_warn "No se encontraron certificados para validador.usiv.cl"
fi

# PASO 7: Pruebas de conectividad
log_step "PRUEBAS DE CONECTIVIDAD"

log_info "Prueba HTTP local (puerto 8080):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://localhost:8080/pdf-signer/" || log_error "Error conectando a Tomcat directo"

echo
log_info "Prueba HTTP a través de Nginx (puerto 80):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://localhost/pdf-signer/" || log_error "Error conectando a Nginx HTTP"

echo
log_info "Prueba HTTPS a través de Nginx (puerto 443):"
curl -s -k -o /dev/null -w "HTTP Status: %{http_code}\n" "https://localhost/pdf-signer/" || log_error "Error conectando a Nginx HTTPS"

echo
log_info "Prueba externa HTTPS:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "https://validador.usiv.cl/pdf-signer/" || log_error "Error conectando externamente"

# PASO 8: Verificar health check
log_step "VERIFICANDO HEALTH CHECK"

log_info "Health check directo (Tomcat):"
curl -s "http://localhost:8080/pdf-signer/api/health" || log_error "Health check directo falló"

echo
log_info "Health check a través de Nginx HTTPS:"
curl -s -k "https://localhost/pdf-signer/api/health" || log_error "Health check HTTPS falló"

# PASO 9: Resumen y recomendaciones
log_step "RESUMEN Y RECOMENDACIONES"

echo "📊 ESTADO ACTUAL:"
echo "    🐱 Tomcat: $(systemctl is-active tomcat)"
echo "    🌍 Nginx: $(systemctl is-active nginx)"
echo "    📁 WAR: $([ -f "$TOMCAT_WEBAPPS/pdf-signer.war" ] && echo 'Presente' || echo 'Ausente')"
echo "    📂 App: $([ -d "$TOMCAT_WEBAPPS/pdf-signer" ] && echo 'Desplegada' || echo 'No desplegada')"
echo "    🔒 SSL: $([ -f "/etc/letsencrypt/live/validador.usiv.cl/cert.pem" ] && echo 'Configurado' || echo 'No configurado')"

echo
echo "🔧 POSIBLES SOLUCIONES:"

if [ ! -d "$TOMCAT_WEBAPPS/pdf-signer" ]; then
    echo "    1. Redesplegar aplicación:"
    echo "       sudo systemctl stop tomcat"
    echo "       sudo rm -rf $TOMCAT_WEBAPPS/pdf-signer*"
    echo "       sudo cp target/pdf-signer-war-1.0.war $TOMCAT_WEBAPPS/pdf-signer.war"
    echo "       sudo chown tomcat:tomcat $TOMCAT_WEBAPPS/pdf-signer.war"
    echo "       sudo systemctl start tomcat"
fi

if [ ! -f "$NGINX_CONF" ]; then
    echo "    2. Reconfigurar SSL:"
    echo "       sudo ./setup-ssl-letsencrypt.sh validador.usiv.cl"
fi

echo "    3. Verificar logs:"
echo "       sudo journalctl -u tomcat -f"
echo "       sudo journalctl -u nginx -f"

echo "    4. Reiniciar servicios:"
echo "       sudo systemctl restart tomcat nginx"

echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    🔍 DIAGNÓSTICO COMPLETADO"
echo "═══════════════════════════════════════════════════════════════════"

log_success "Diagnóstico finalizado. Revisa las recomendaciones arriba."