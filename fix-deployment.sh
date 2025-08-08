#!/bin/bash

# SCRIPT PARA CORREGIR DESPLIEGUE DE APLICACIÓN
# Soluciona el error 404 verificando y corrigiendo el despliegue WAR
# Autor: PDF Signer Team

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
    echo -e "\n${PURPLE}🔧 $1${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
}

echo "═══════════════════════════════════════════════════════════════════"
echo "                    🔧 CORRECCIÓN DE DESPLIEGUE"
echo "                     PDF Signer - Error 404"
echo "═══════════════════════════════════════════════════════════════════"
echo "🕐 Fecha: $(date)"
echo "📁 Directorio: $(pwd)"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar que somos root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Verificar que estamos en el directorio correcto
if [ ! -f "pom.xml" ]; then
    log_error "No se encontró pom.xml. Ejecuta este script desde el directorio raíz del proyecto."
    exit 1
fi

# Configuración
TOMCAT_WEBAPPS="/var/lib/tomcat/webapps"
TOMCAT_WORK="/var/lib/tomcat/work"
WAR_FILE="target/pdf-signer-war-1.0.war"
APP_NAME="pdf-signer"

# PASO 1: Verificar archivo WAR
log_step "VERIFICANDO ARCHIVO WAR"

if [ -f "$WAR_FILE" ]; then
    log_success "Archivo WAR encontrado: $WAR_FILE"
    ls -la "$WAR_FILE"
else
    log_error "Archivo WAR no encontrado: $WAR_FILE"
    log_info "Compilando aplicación..."
    mvn clean package -DskipTests
    
    if [ -f "$WAR_FILE" ]; then
        log_success "Aplicación compilada exitosamente"
    else
        log_error "Error en la compilación. Revisa los logs de Maven."
        exit 1
    fi
fi

# PASO 2: Detener Tomcat
log_step "DETENIENDO TOMCAT"

log_info "Deteniendo servicio Tomcat..."
systemctl stop tomcat

# Esperar a que Tomcat se detenga completamente
sleep 5

if systemctl is-active --quiet tomcat; then
    log_warn "Tomcat aún está ejecutándose, forzando detención..."
    pkill -f tomcat || true
    sleep 3
fi

log_success "Tomcat detenido"

# PASO 3: Limpiar despliegue anterior
log_step "LIMPIANDO DESPLIEGUE ANTERIOR"

log_info "Eliminando aplicación anterior..."

# Eliminar WAR anterior
if [ -f "$TOMCAT_WEBAPPS/$APP_NAME.war" ]; then
    rm -f "$TOMCAT_WEBAPPS/$APP_NAME.war"
    log_success "WAR anterior eliminado"
fi

# Eliminar directorio de aplicación desplegada
if [ -d "$TOMCAT_WEBAPPS/$APP_NAME" ]; then
    rm -rf "$TOMCAT_WEBAPPS/$APP_NAME"
    log_success "Directorio de aplicación eliminado"
fi

# Limpiar directorio de trabajo de Tomcat
if [ -d "$TOMCAT_WORK/Catalina/localhost/$APP_NAME" ]; then
    rm -rf "$TOMCAT_WORK/Catalina/localhost/$APP_NAME"
    log_success "Cache de trabajo eliminado"
fi

# Limpiar logs de Tomcat
if [ -d "/var/log/tomcat" ]; then
    rm -f /var/log/tomcat/catalina.out
    log_success "Logs de Tomcat limpiados"
fi

# PASO 4: Copiar nuevo WAR
log_step "DESPLEGANDO NUEVA APLICACIÓN"

log_info "Copiando archivo WAR..."
cp "$WAR_FILE" "$TOMCAT_WEBAPPS/$APP_NAME.war"

# Establecer permisos correctos
chown tomcat:tomcat "$TOMCAT_WEBAPPS/$APP_NAME.war"
chmod 644 "$TOMCAT_WEBAPPS/$APP_NAME.war"

log_success "Archivo WAR copiado con permisos correctos"
ls -la "$TOMCAT_WEBAPPS/$APP_NAME.war"

# PASO 5: Verificar estructura del WAR
log_step "VERIFICANDO ESTRUCTURA DEL WAR"

log_info "Contenido del archivo WAR:"
jar -tf "$TOMCAT_WEBAPPS/$APP_NAME.war" | head -20
echo "... (mostrando primeras 20 líneas)"

# Verificar que contiene archivos esenciales
if jar -tf "$TOMCAT_WEBAPPS/$APP_NAME.war" | grep -q "WEB-INF/web.xml"; then
    log_success "web.xml encontrado en el WAR"
else
    log_error "web.xml NO encontrado en el WAR"
fi

if jar -tf "$TOMCAT_WEBAPPS/$APP_NAME.war" | grep -q "WEB-INF/classes"; then
    log_success "Clases encontradas en el WAR"
else
    log_warn "No se encontraron clases en el WAR"
fi

# PASO 6: Iniciar Tomcat
log_step "INICIANDO TOMCAT"

log_info "Iniciando servicio Tomcat..."
systemctl start tomcat

# Esperar a que Tomcat inicie
log_info "Esperando a que Tomcat inicie..."
sleep 10

# Verificar que Tomcat está ejecutándose
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat iniciado exitosamente"
else
    log_error "Error al iniciar Tomcat"
    log_info "Logs de Tomcat:"
    journalctl -u tomcat --no-pager -n 20
    exit 1
fi

# PASO 7: Esperar despliegue
log_step "ESPERANDO DESPLIEGUE DE APLICACIÓN"

log_info "Esperando a que la aplicación se despliegue..."

# Esperar hasta 60 segundos para que la aplicación se despliegue
COUNTER=0
MAX_WAIT=60

while [ $COUNTER -lt $MAX_WAIT ]; do
    if [ -d "$TOMCAT_WEBAPPS/$APP_NAME" ]; then
        log_success "Aplicación desplegada en: $TOMCAT_WEBAPPS/$APP_NAME"
        break
    fi
    
    echo -n "."
    sleep 1
    COUNTER=$((COUNTER + 1))
done

echo

if [ ! -d "$TOMCAT_WEBAPPS/$APP_NAME" ]; then
    log_error "La aplicación no se desplegó después de $MAX_WAIT segundos"
    log_info "Verificando logs de Tomcat..."
    journalctl -u tomcat --no-pager -n 30
    exit 1
fi

# Verificar contenido del directorio desplegado
log_info "Contenido de la aplicación desplegada:"
ls -la "$TOMCAT_WEBAPPS/$APP_NAME" | head -10

# PASO 8: Verificar conectividad
log_step "VERIFICANDO CONECTIVIDAD"

log_info "Esperando a que la aplicación esté lista..."
sleep 10

# Probar conexión directa a Tomcat
log_info "Probando conexión directa a Tomcat (puerto 8080)..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/$APP_NAME/" || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "404" ]; then
    log_success "Tomcat responde (HTTP $HTTP_STATUS)"
else
    log_error "Tomcat no responde (HTTP $HTTP_STATUS)"
fi

# Probar health check si existe
log_info "Probando health check..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/$APP_NAME/api/health" || echo "000")

if [ "$HEALTH_STATUS" = "200" ]; then
    log_success "Health check responde correctamente"
else
    log_warn "Health check no disponible (HTTP $HEALTH_STATUS)"
fi

# Probar a través de Nginx HTTPS
log_info "Probando a través de Nginx HTTPS..."
HTTPS_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" "https://localhost/$APP_NAME/" || echo "000")

if [ "$HTTPS_STATUS" = "200" ] || [ "$HTTPS_STATUS" = "302" ]; then
    log_success "Nginx HTTPS responde correctamente (HTTP $HTTPS_STATUS)"
else
    log_warn "Nginx HTTPS no responde correctamente (HTTP $HTTPS_STATUS)"
fi

# PASO 9: Resumen final
log_step "RESUMEN DE CORRECCIÓN"

echo "📊 ESTADO DESPUÉS DE LA CORRECCIÓN:"
echo "    🐱 Tomcat: $(systemctl is-active tomcat)"
echo "    📁 WAR: $([ -f "$TOMCAT_WEBAPPS/$APP_NAME.war" ] && echo 'Presente' || echo 'Ausente')"
echo "    📂 App: $([ -d "$TOMCAT_WEBAPPS/$APP_NAME" ] && echo 'Desplegada' || echo 'No desplegada')"
echo "    🔗 Tomcat directo: HTTP $HTTP_STATUS"
echo "    🔒 Nginx HTTPS: HTTP $HTTPS_STATUS"
echo "    💚 Health check: HTTP $HEALTH_STATUS"

echo
echo "🎯 URLS PARA PROBAR:"
echo "    📱 Directo: http://validador.usiv.cl:8080/$APP_NAME/"
echo "    🔒 HTTPS: https://validador.usiv.cl/$APP_NAME/"
echo "    💚 Health: https://validador.usiv.cl/$APP_NAME/api/health"
echo "    📚 Swagger: https://validador.usiv.cl/$APP_NAME/swagger-ui/"

echo
echo "📋 COMANDOS ÚTILES:"
echo "    sudo systemctl status tomcat     # Estado de Tomcat"
echo "    sudo journalctl -u tomcat -f     # Logs en tiempo real"
echo "    sudo systemctl restart tomcat   # Reiniciar si es necesario"
echo "    ls -la $TOMCAT_WEBAPPS/          # Ver aplicaciones desplegadas"

echo
echo "═══════════════════════════════════════════════════════════════════"
if [ -d "$TOMCAT_WEBAPPS/$APP_NAME" ] && ([ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]); then
    echo "                    🎉 CORRECCIÓN EXITOSA"
    echo "                   Aplicación disponible"
else
    echo "                    ⚠️  CORRECCIÓN PARCIAL"
    echo "                   Revisa los logs de Tomcat"
fi
echo "═══════════════════════════════════════════════════════════════════"

log_success "Corrección de despliegue finalizada."