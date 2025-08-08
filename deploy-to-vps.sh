#!/bin/bash

# SCRIPT DE DESPLIEGUE EN VPS
# Script para desplegar PDF Signer en validador.usiv.cl
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
    echo -e "\n${PURPLE}🚀 $1${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
}

# Configuración
DOMAIN="validador.usiv.cl"
PROJECT_DIR="$(pwd)"  # Usar directorio actual
TOMCAT_USER="tomcat"
NGINX_USER="nginx"

echo "═══════════════════════════════════════════════════════════════════"
echo "                    🚀 DESPLIEGUE EN VPS"
echo "                   PDF Signer - validador.usiv.cl"
echo "═══════════════════════════════════════════════════════════════════"
echo "🌐 Dominio: $DOMAIN"
echo "📁 Directorio: $PROJECT_DIR"
echo "🕐 Fecha: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar que somos root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# PASO 1: Verificar directorio del proyecto
log_step "VERIFICANDO DIRECTORIO DEL PROYECTO"

# Verificar que estamos en el directorio correcto
if [ ! -f "pom.xml" ]; then
    log_error "No se encontró pom.xml en el directorio actual: $PROJECT_DIR"
    log_error "Asegúrate de ejecutar este script desde el directorio raíz del proyecto"
    exit 1
fi

log_success "Directorio del proyecto verificado: $PROJECT_DIR"

# PASO 2: Verificar código actualizado
log_step "VERIFICANDO CÓDIGO ACTUALIZADO"

if [ -d ".git" ]; then
    log_info "Repositorio Git encontrado"
    
    # Verificar si hay cambios sin commitear
    if ! git diff-index --quiet HEAD --; then
        log_warn "⚠️  Hay cambios sin commitear en el repositorio"
        log_info "Asegúrate de haber hecho 'git pull' antes de ejecutar este script"
    else
        log_success "Repositorio limpio, listo para despliegue"
    fi
    
    # Mostrar último commit
    LAST_COMMIT=$(git log -1 --pretty=format:"%h - %s (%an, %ar)")
    log_info "Último commit: $LAST_COMMIT"
else
    log_error "No se encontró repositorio Git en este directorio"
    log_error "Asegúrate de estar en el directorio correcto del proyecto"
    exit 1
fi

# PASO 3: Verificar dependencias del sistema
log_step "VERIFICANDO DEPENDENCIAS DEL SISTEMA"

# Verificar Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    log_success "Java encontrado: $JAVA_VERSION"
else
    log_error "Java no encontrado. Instalando OpenJDK 17..."
    dnf install -y java-17-openjdk java-17-openjdk-devel
fi

# Verificar Maven
if command -v mvn &> /dev/null; then
    MAVEN_VERSION=$(mvn -version | head -n 1 | cut -d' ' -f3)
    log_success "Maven encontrado: $MAVEN_VERSION"
else
    log_error "Maven no encontrado. Instalando..."
    dnf install -y maven
fi

# Verificar Tomcat
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat está ejecutándose"
else
    log_warn "Tomcat no está ejecutándose. Verificando instalación..."
    if ! command -v systemctl status tomcat &> /dev/null; then
        log_error "Tomcat no está instalado. Instalando..."
        dnf install -y tomcat tomcat-webapps tomcat-admin-webapps
        systemctl enable tomcat
    fi
fi

# Verificar Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ejecutándose"
else
    log_warn "Nginx no está ejecutándose. Verificando instalación..."
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx no está instalado. Instalando..."
        dnf install -y nginx
        systemctl enable nginx
    fi
fi

# PASO 4: Compilar aplicación
log_step "COMPILANDO APLICACIÓN"

log_info "Limpiando compilación anterior..."
mvn clean

log_info "Compilando aplicación..."
mvn package -DskipTests

if [ -f "target/pdf-signer-war-1.0.war" ]; then
    log_success "Aplicación compilada exitosamente"
else
    log_error "Error en la compilación. Revisa los logs de Maven."
    exit 1
fi

# PASO 5: Desplegar en Tomcat
log_step "DESPLEGANDO EN TOMCAT"

# Detener Tomcat
log_info "Deteniendo Tomcat..."
systemctl stop tomcat

# Limpiar despliegue anterior
log_info "Limpiando despliegue anterior..."
rm -rf /var/lib/tomcat/webapps/pdf-signer*
rm -rf /var/lib/tomcat/work/Catalina/localhost/pdf-signer*

# Copiar nuevo WAR
log_info "Copiando nueva aplicación..."
cp target/pdf-signer-war-1.0.war /var/lib/tomcat/webapps/pdf-signer.war
chown tomcat:tomcat /var/lib/tomcat/webapps/pdf-signer.war

# Iniciar Tomcat
log_info "Iniciando Tomcat..."
systemctl start tomcat

# Esperar a que Tomcat despliegue la aplicación
log_info "Esperando despliegue de la aplicación..."
sleep 30

# Verificar despliegue
if [ -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    log_success "Aplicación desplegada exitosamente en Tomcat"
else
    log_error "Error en el despliegue. Revisa los logs de Tomcat."
    journalctl -u tomcat --no-pager -n 20
    exit 1
fi

# PASO 6: Configurar SSL con Let's Encrypt
log_step "CONFIGURANDO SSL CON LET'S ENCRYPT"

log_info "Ejecutando configuración SSL..."
./setup-ssl-letsencrypt.sh "$DOMAIN"

if [ $? -eq 0 ]; then
    log_success "SSL configurado exitosamente"
else
    log_error "Error en la configuración SSL"
    exit 1
fi

# PASO 7: Configurar firewall
log_step "CONFIGURANDO FIREWALL"

log_info "Detectando sistema de firewall..."

# Detectar y configurar firewall disponible
if command -v firewall-cmd &> /dev/null; then
    log_info "Usando firewalld..."
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --reload
    log_success "Firewall configurado con firewalld"
elif command -v ufw &> /dev/null; then
    log_info "Usando UFW..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8080/tcp
    log_success "Firewall configurado con UFW"
elif command -v iptables &> /dev/null; then
    log_info "Usando iptables..."
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
    # Intentar guardar reglas
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    log_success "Firewall configurado con iptables"
else
    log_warn "⚠️  No se detectó sistema de firewall conocido"
    log_info "Asegúrate manualmente de que los puertos 80, 443 y 8080 estén abiertos"
fi

# PASO 8: Verificación final
log_step "VERIFICACIÓN FINAL"

# Verificar servicios
log_info "Verificando servicios..."

if systemctl is-active --quiet tomcat; then
    log_success "✅ Tomcat: Ejecutándose"
else
    log_error "❌ Tomcat: No está ejecutándose"
fi

if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx: Ejecutándose"
else
    log_error "❌ Nginx: No está ejecutándose"
fi

# Verificar puertos
log_info "Verificando puertos..."

if ss -tlnp | grep -q ":80 "; then
    log_success "✅ Puerto 80: Abierto"
else
    log_warn "⚠️  Puerto 80: No disponible"
fi

if ss -tlnp | grep -q ":443 "; then
    log_success "✅ Puerto 443: Abierto"
else
    log_warn "⚠️  Puerto 443: No disponible"
fi

if ss -tlnp | grep -q ":8080 "; then
    log_success "✅ Puerto 8080: Abierto"
else
    log_warn "⚠️  Puerto 8080: No disponible"
fi

# Verificar URLs
log_info "Verificando URLs..."

# Esperar un poco más para que todo esté listo
sleep 10

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/pdf-signer/api/health" | grep -q "200\|404"; then
    log_success "✅ Tomcat directo: Respondiendo"
else
    log_warn "⚠️  Tomcat directo: No responde"
fi

if curl -s -o /dev/null -w "%{http_code}" "http://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
    log_success "✅ Nginx HTTP: Respondiendo"
else
    log_warn "⚠️  Nginx HTTP: No responde"
fi

if curl -s -k -o /dev/null -w "%{http_code}" "https://localhost/pdf-signer/" | grep -q "200\|301\|302"; then
    log_success "✅ Nginx HTTPS: Respondiendo"
else
    log_warn "⚠️  Nginx HTTPS: No responde"
fi

# PASO 9: Resumen final
log_step "RESUMEN DEL DESPLIEGUE"

echo "📊 ESTADO DEL DESPLIEGUE:"
echo "    🌐 Dominio: $DOMAIN"
echo "    📁 Directorio: $PROJECT_DIR"
echo "    🐱 Tomcat: $(systemctl is-active tomcat)"
echo "    🌍 Nginx: $(systemctl is-active nginx)"
echo "    🔒 SSL: $([ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ] && echo 'Configurado' || echo 'No configurado')"

echo
echo "🎯 URLS DE ACCESO:"
echo "    📱 Aplicación: https://$DOMAIN/pdf-signer/"
echo "    🔍 Health Check: https://$DOMAIN/pdf-signer/api/health"
echo "    📚 Swagger UI: https://$DOMAIN/pdf-signer/swagger-ui/"
echo "    🐱 Tomcat directo: http://$DOMAIN:8080/pdf-signer/"

echo
echo "📋 COMANDOS ÚTILES:"
echo "    sudo systemctl status tomcat     # Estado de Tomcat"
echo "    sudo systemctl status nginx      # Estado de Nginx"
echo "    sudo journalctl -u tomcat -f     # Logs de Tomcat en tiempo real"
echo "    sudo journalctl -u nginx -f      # Logs de Nginx en tiempo real"
echo "    sudo certbot certificates        # Ver certificados SSL"
echo "    sudo ./check-ssl-status.sh       # Verificar estado SSL"

echo
echo "═══════════════════════════════════════════════════════════════════"
if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    echo "                    🎉 DESPLIEGUE COMPLETADO EXITOSAMENTE"
    echo "                   Accede a: https://$DOMAIN/pdf-signer/"
else
    echo "                    ⚠️  DESPLIEGUE COMPLETADO CON ADVERTENCIAS"
    echo "                   Revisa la configuración SSL"
fi
echo "═══════════════════════════════════════════════════════════════════"

log_success "Despliegue finalizado. Revisa las URLs de acceso arriba."