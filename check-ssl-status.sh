#!/bin/bash

# VERIFICADOR DE ESTADO SSL
# Script para verificar configuración SSL/HTTPS
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

# Función para verificar comando
check_command() {
    if command -v $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Función para verificar puerto
check_port() {
    local port=$1
    if ss -tlnp | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# Función para verificar URL
check_url() {
    local url=$1
    local timeout=${2:-10}
    
    if curl -s -k -o /dev/null -w "%{http_code}" --connect-timeout $timeout "$url" | grep -q "200\|301\|302\|404"; then
        return 0
    else
        return 1
    fi
}

# Detectar IP del servidor
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "No detectada")

echo "═══════════════════════════════════════════════════════════════════"
echo "                    🔍 VERIFICADOR DE ESTADO SSL"
echo "                      PDF Signer - Diagnóstico"
echo "═══════════════════════════════════════════════════════════════════"
echo "🖥️  Servidor: $(hostname)"
echo "🌐 IP: $SERVER_IP"
echo "🕐 Fecha: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# PASO 1: Verificar servicios básicos
log_step "VERIFICANDO SERVICIOS BÁSICOS"

# Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ejecutándose"
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3)
    log_info "Versión: $NGINX_VERSION"
else
    log_error "Nginx no está ejecutándose"
    echo "    Ejecuta: sudo systemctl start nginx"
fi

# Tomcat
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat está ejecutándose"
else
    log_error "Tomcat no está ejecutándose"
    echo "    Ejecuta: sudo systemctl start tomcat"
fi

# PASO 2: Verificar puertos
log_step "VERIFICANDO PUERTOS"

# Puerto 80 (HTTP)
if check_port 80; then
    log_success "Puerto 80 (HTTP) está abierto"
else
    log_warn "Puerto 80 (HTTP) no está disponible"
fi

# Puerto 443 (HTTPS)
if check_port 443; then
    log_success "Puerto 443 (HTTPS) está abierto"
    HTTPS_AVAILABLE=true
else
    log_warn "Puerto 443 (HTTPS) no está disponible"
    HTTPS_AVAILABLE=false
fi

# Puerto 8080 (Tomcat)
if check_port 8080; then
    log_success "Puerto 8080 (Tomcat) está abierto"
else
    log_warn "Puerto 8080 (Tomcat) no está disponible"
fi

# PASO 3: Verificar certificados SSL
log_step "VERIFICANDO CERTIFICADOS SSL"

# Let's Encrypt
if [ -d "/etc/letsencrypt/live" ]; then
    CERT_DOMAINS=$(ls /etc/letsencrypt/live 2>/dev/null | head -5)
    if [ -n "$CERT_DOMAINS" ]; then
        log_success "Certificados Let's Encrypt encontrados:"
        for domain in $CERT_DOMAINS; do
            CERT_FILE="/etc/letsencrypt/live/$domain/cert.pem"
            if [ -f "$CERT_FILE" ]; then
                CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
                if [ -n "$CERT_EXPIRY" ]; then
                    echo "    📜 $domain - Expira: $CERT_EXPIRY"
                    
                    # Verificar si expira pronto (30 días)
                    EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s 2>/dev/null || echo "0")
                    CURRENT_EPOCH=$(date +%s)
                    DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
                    
                    if [ $DAYS_LEFT -lt 30 ] && [ $DAYS_LEFT -gt 0 ]; then
                        log_warn "    ⏰ Certificado expira en $DAYS_LEFT días"
                    elif [ $DAYS_LEFT -le 0 ]; then
                        log_error "    ⏰ Certificado EXPIRADO"
                    fi
                fi
            fi
        done
        LETSENCRYPT_AVAILABLE=true
    else
        log_warn "Directorio Let's Encrypt existe pero no hay certificados"
        LETSENCRYPT_AVAILABLE=false
    fi
else
    log_warn "Let's Encrypt no está configurado"
    LETSENCRYPT_AVAILABLE=false
fi

# Certificados autofirmados
if [ -f "/etc/ssl/certs/pdf-signer.crt" ] && [ -f "/etc/ssl/private/pdf-signer.key" ]; then
    log_success "Certificado autofirmado encontrado"
    CERT_INFO=$(openssl x509 -in /etc/ssl/certs/pdf-signer.crt -noout -subject -dates 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "$CERT_INFO" | sed 's/^/    /'
    fi
    SELFSIGNED_AVAILABLE=true
else
    log_info "No hay certificados autofirmados"
    SELFSIGNED_AVAILABLE=false
fi

# PASO 4: Verificar configuración de Nginx
log_step "VERIFICANDO CONFIGURACIÓN DE NGINX"

NGINX_CONFIG="/etc/nginx/conf.d/pdf-signer.conf"
if [ -f "$NGINX_CONFIG" ]; then
    log_success "Archivo de configuración encontrado: $NGINX_CONFIG"
    
    # Verificar configuración SSL
    if grep -q "listen 443 ssl" "$NGINX_CONFIG"; then
        log_success "Configuración HTTPS encontrada en Nginx"
        
        # Verificar certificados en configuración
        if grep -q "ssl_certificate" "$NGINX_CONFIG"; then
            CERT_PATH=$(grep "ssl_certificate " "$NGINX_CONFIG" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -f "$CERT_PATH" ]; then
                log_success "Certificado SSL configurado: $CERT_PATH"
            else
                log_error "Certificado SSL no encontrado: $CERT_PATH"
            fi
        fi
        
        # Verificar redirección HTTP → HTTPS
        if grep -q "return 301 https" "$NGINX_CONFIG"; then
            log_success "Redirección HTTP → HTTPS configurada"
        else
            log_warn "Redirección HTTP → HTTPS no configurada"
        fi
    else
        log_warn "Configuración HTTPS no encontrada en Nginx"
    fi
    
    # Verificar sintaxis
    if nginx -t &>/dev/null; then
        log_success "Configuración de Nginx es válida"
    else
        log_error "Error en configuración de Nginx"
        echo "    Ejecuta: sudo nginx -t"
    fi
else
    log_error "Archivo de configuración no encontrado: $NGINX_CONFIG"
fi

# PASO 5: Verificar conectividad
log_step "VERIFICANDO CONECTIVIDAD"

# HTTP local
log_info "Probando HTTP local..."
if check_url "http://localhost/pdf-signer/" 5; then
    log_success "HTTP local funciona"
else
    log_warn "HTTP local no responde"
fi

# HTTPS local (si está disponible)
if [ "$HTTPS_AVAILABLE" = true ]; then
    log_info "Probando HTTPS local..."
    if check_url "https://localhost/pdf-signer/" 5; then
        log_success "HTTPS local funciona"
    else
        log_warn "HTTPS local no responde"
    fi
fi

# Tomcat directo
log_info "Probando Tomcat directo..."
if check_url "http://localhost:8080/pdf-signer/" 5; then
    log_success "Tomcat directo funciona"
else
    log_warn "Tomcat directo no responde"
fi

# PASO 6: Verificar desde IP externa (si es posible)
if [ "$SERVER_IP" != "No detectada" ] && [ "$SERVER_IP" != "127.0.0.1" ]; then
    log_step "VERIFICANDO ACCESO EXTERNO"
    
    # HTTP externo
    log_info "Probando HTTP externo ($SERVER_IP)..."
    if check_url "http://$SERVER_IP/pdf-signer/" 10; then
        log_success "HTTP externo funciona"
    else
        log_warn "HTTP externo no responde (puede ser firewall)"
    fi
    
    # HTTPS externo (si está disponible)
    if [ "$HTTPS_AVAILABLE" = true ]; then
        log_info "Probando HTTPS externo ($SERVER_IP)..."
        if check_url "https://$SERVER_IP/pdf-signer/" 10; then
            log_success "HTTPS externo funciona"
        else
            log_warn "HTTPS externo no responde (puede ser firewall)"
        fi
    fi
fi

# PASO 7: Verificar herramientas SSL
log_step "VERIFICANDO HERRAMIENTAS SSL"

# Certbot
if check_command certbot; then
    log_success "Certbot está instalado"
    CERTBOT_VERSION=$(certbot --version 2>&1 | head -1)
    log_info "$CERTBOT_VERSION"
    
    # Verificar renovación automática
    if [ -f "/etc/cron.daily/certbot-renew" ] || [ -f "/etc/cron.d/certbot" ]; then
        log_success "Renovación automática configurada"
    else
        log_warn "Renovación automática no configurada"
    fi
else
    log_warn "Certbot no está instalado"
    echo "    Para instalar: sudo dnf install certbot python3-certbot-nginx"
fi

# OpenSSL
if check_command openssl; then
    OPENSSL_VERSION=$(openssl version)
    log_success "OpenSSL disponible: $OPENSSL_VERSION"
else
    log_error "OpenSSL no está disponible"
fi

# PASO 8: Resumen y recomendaciones
log_step "RESUMEN Y RECOMENDACIONES"

echo "📊 ESTADO ACTUAL:"

# Estado de SSL
if [ "$HTTPS_AVAILABLE" = true ] && ([ "$LETSENCRYPT_AVAILABLE" = true ] || [ "$SELFSIGNED_AVAILABLE" = true ]); then
    log_success "SSL/HTTPS está configurado y funcionando"
    SSL_STATUS="✅ CONFIGURADO"
else
    log_warn "SSL/HTTPS no está completamente configurado"
    SSL_STATUS="⚠️  NO CONFIGURADO"
fi

echo "    🔒 SSL/HTTPS: $SSL_STATUS"
echo "    🌐 HTTP (Puerto 80): $(check_port 80 && echo '✅ Disponible' || echo '❌ No disponible')"
echo "    🔐 HTTPS (Puerto 443): $(check_port 443 && echo '✅ Disponible' || echo '❌ No disponible')"
echo "    🐱 Tomcat (Puerto 8080): $(check_port 8080 && echo '✅ Disponible' || echo '❌ No disponible')"

if [ "$LETSENCRYPT_AVAILABLE" = true ]; then
    echo "    📜 Certificados: ✅ Let's Encrypt (confiable)"
elif [ "$SELFSIGNED_AVAILABLE" = true ]; then
    echo "    📜 Certificados: ⚠️  Autofirmado (advertencia en navegador)"
else
    echo "    📜 Certificados: ❌ No configurado"
fi

echo
echo "🎯 RECOMENDACIONES:"

if [ "$HTTPS_AVAILABLE" = false ]; then
    echo "    1. 🔧 Configurar SSL ejecutando:"
    echo "       sudo ./setup-ssl-letsencrypt.sh tu-dominio.com"
    echo "       # o para IP: sudo ./setup-ssl-letsencrypt.sh $SERVER_IP"
fi

if [ "$LETSENCRYPT_AVAILABLE" = false ] && [ "$SELFSIGNED_AVAILABLE" = false ]; then
    echo "    2. 📜 Obtener certificados SSL:"
    echo "       - Para dominio: Let's Encrypt (gratuito y confiable)"
    echo "       - Para IP: Certificado autofirmado"
fi

if ! systemctl is-active --quiet nginx; then
    echo "    3. 🔄 Iniciar Nginx: sudo systemctl start nginx"
fi

if ! systemctl is-active --quiet tomcat; then
    echo "    4. 🔄 Iniciar Tomcat: sudo systemctl start tomcat"
fi

echo
echo "📋 COMANDOS ÚTILES:"
echo "    sudo ./setup-ssl-letsencrypt.sh <dominio>     # Configurar SSL automáticamente"
echo "    sudo certbot certificates                     # Ver certificados instalados"
echo "    sudo certbot renew                          # Renovar certificados"
echo "    sudo nginx -t                               # Verificar configuración Nginx"
echo "    sudo systemctl reload nginx                 # Recargar Nginx"
echo "    curl -k -I https://$SERVER_IP/pdf-signer/   # Probar HTTPS"

echo
echo "═══════════════════════════════════════════════════════════════════"
if [ "$HTTPS_AVAILABLE" = true ]; then
    echo "                    🔒 SSL ESTÁ CONFIGURADO"
    echo "    Accede a: https://$SERVER_IP/pdf-signer/"
else
    echo "                    ⚠️  SSL NO ESTÁ CONFIGURADO"
    echo "    Ejecuta: sudo ./setup-ssl-letsencrypt.sh <dominio>"
fi
echo "═══════════════════════════════════════════════════════════════════"