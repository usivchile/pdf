#!/bin/bash

# Script para verificar el estado del despliegue de PDF Validator API
# Comprueba Tomcat, WAR y funcionalidad de la aplicación

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Banner
echo -e "${CYAN}"
echo "═══════════════════════════════════════════════════════════════════"
echo "                PDF VALIDATOR API - VERIFICACIÓN                   "
echo "                   Estado del Despliegue                          "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

log_info "Iniciando verificación del despliegue..."

# 1. Verificar estado de Tomcat
echo -e "\n${PURPLE}1. VERIFICANDO TOMCAT${NC}"
if systemctl is-active --quiet tomcat; then
    log_success "Tomcat está ejecutándose"
    
    # Obtener información del proceso
    TOMCAT_PID=$(systemctl show tomcat --property=MainPID --value)
    if [ "$TOMCAT_PID" != "0" ]; then
        log_info "PID de Tomcat: $TOMCAT_PID"
        
        # Verificar uso de memoria
        MEMORY_USAGE=$(ps -p $TOMCAT_PID -o %mem --no-headers | tr -d ' ')
        log_info "Uso de memoria: ${MEMORY_USAGE}%"
    fi
    
    # Verificar puertos
    if netstat -tlnp | grep -q ":8080.*java"; then
        log_success "Tomcat escuchando en puerto 8080"
    else
        log_warn "Tomcat no está escuchando en puerto 8080"
    fi
else
    log_error "Tomcat no está ejecutándose"
    log_info "Para iniciar Tomcat: systemctl start tomcat"
fi

# 2. Verificar logs de Tomcat
echo -e "\n${PURPLE}2. VERIFICANDO LOGS DE TOMCAT${NC}"
TOMCAT_LOG="/var/lib/tomcat/logs/catalina.out"
if [ -f "$TOMCAT_LOG" ]; then
    log_info "Últimas líneas del log de Tomcat:"
    echo -e "${YELLOW}$(tail -10 $TOMCAT_LOG)${NC}"
    
    # Buscar errores recientes
    if tail -50 "$TOMCAT_LOG" | grep -i "error\|exception\|failed" > /dev/null; then
        log_warn "Se encontraron errores en los logs recientes"
        echo -e "${RED}Errores encontrados:${NC}"
        tail -50 "$TOMCAT_LOG" | grep -i "error\|exception\|failed" | tail -5
    else
        log_success "No se encontraron errores recientes en los logs"
    fi
else
    log_warn "No se encontró el archivo de log de Tomcat"
fi

# 3. Verificar aplicación WAR desplegada
echo -e "\n${PURPLE}3. VERIFICANDO APLICACIÓN WAR${NC}"
WAR_PATH="/var/lib/tomcat/webapps/pdf-signer-war-1.0.war"
APP_DIR="/var/lib/tomcat/webapps/pdf-signer-war-1.0"

if [ -f "$WAR_PATH" ]; then
    WAR_SIZE=$(du -h "$WAR_PATH" | cut -f1)
    log_success "Archivo WAR encontrado: $WAR_SIZE"
else
    log_error "Archivo WAR no encontrado en $WAR_PATH"
fi

if [ -d "$APP_DIR" ]; then
    log_success "Aplicación desplegada en $APP_DIR"
    
    # Verificar archivos importantes
    if [ -f "$APP_DIR/WEB-INF/web.xml" ]; then
        log_success "Descriptor web.xml encontrado"
    fi
    
    if [ -d "$APP_DIR/WEB-INF/classes" ]; then
        CLASS_COUNT=$(find "$APP_DIR/WEB-INF/classes" -name "*.class" | wc -l)
        log_success "Clases compiladas encontradas: $CLASS_COUNT archivos"
    fi
else
    log_error "Directorio de aplicación no encontrado"
    log_info "La aplicación puede no haberse desplegado correctamente"
fi

# 4. Verificar conectividad local
echo -e "\n${PURPLE}4. VERIFICANDO CONECTIVIDAD LOCAL${NC}"

# Probar conexión HTTP local
log_info "Probando conexión HTTP local (puerto 8080)..."
if curl -s --connect-timeout 5 http://localhost:8080/pdf-signer-war-1.0/api/health > /dev/null 2>&1; then
    log_success "Aplicación responde en HTTP local"
else
    log_warn "Aplicación no responde en HTTP local"
    
    # Intentar conexión básica a Tomcat
    if curl -s --connect-timeout 5 http://localhost:8080/ > /dev/null 2>&1; then
        log_info "Tomcat responde, pero la aplicación puede no estar disponible"
    else
        log_error "Tomcat no responde en puerto 8080"
    fi
fi

# 5. Probar endpoints específicos
echo -e "\n${PURPLE}5. PROBANDO ENDPOINTS DE LA API${NC}"

# Endpoint de salud
log_info "Probando endpoint de salud..."
HEALTH_RESPONSE=$(curl -s --connect-timeout 10 http://localhost:8080/pdf-signer-war-1.0/api/health 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$HEALTH_RESPONSE" ]; then
    log_success "Endpoint de salud responde: $HEALTH_RESPONSE"
else
    log_error "Endpoint de salud no responde"
fi

# Endpoint de información
log_info "Probando endpoint de información..."
INFO_RESPONSE=$(curl -s --connect-timeout 10 http://localhost:8080/pdf-signer-war-1.0/api/info 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$INFO_RESPONSE" ]; then
    log_success "Endpoint de información responde"
    echo -e "${GREEN}Respuesta: $INFO_RESPONSE${NC}"
else
    log_warn "Endpoint de información no responde"
fi

# 6. Verificar que solo esté corriendo nuestro Tomcat
echo -e "\n${PURPLE}6. VERIFICANDO INSTANCIAS DE TOMCAT${NC}"
TOMCAT_PROCESSES=$(ps aux | grep -E '[t]omcat|[j]ava.*catalina' | grep -v grep)
TOMCAT_COUNT=$(echo "$TOMCAT_PROCESSES" | grep -c .)

if [ "$TOMCAT_COUNT" -eq 0 ]; then
    log_error "No se encontraron procesos de Tomcat ejecutándose"
elif [ "$TOMCAT_COUNT" -eq 1 ]; then
    log_success "Solo una instancia de Tomcat ejecutándose (correcto)"
    echo -e "${GREEN}Proceso: $(echo "$TOMCAT_PROCESSES" | head -1)${NC}"
else
    log_warn "Se encontraron múltiples procesos de Tomcat/Java:"
    echo -e "${YELLOW}$TOMCAT_PROCESSES${NC}"
    log_warn "Verifica que no haya conflictos entre instancias"
fi

# Verificar que nuestro Tomcat esté en el directorio correcto
if [ -d "/var/lib/tomcat" ]; then
    TOMCAT_OWNER=$(ls -ld /var/lib/tomcat | awk '{print $3}')
    log_info "Propietario del directorio Tomcat: $TOMCAT_OWNER"
    
    if [ "$TOMCAT_OWNER" = "tomcat" ]; then
        log_success "Directorio Tomcat tiene el propietario correcto"
    else
        log_warn "Directorio Tomcat no tiene el propietario esperado (tomcat)"
    fi
fi

# 7. Verificar Nginx y redirección HTTP a HTTPS
echo -e "\n${PURPLE}7. VERIFICANDO NGINX Y REDIRECCIÓN HTTPS${NC}"
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ejecutándose"
    
    # Verificar puertos
    if netstat -tlnp | grep -q ":443.*nginx"; then
        log_success "Nginx escuchando en puerto 443 (HTTPS)"
    else
        log_warn "Nginx no está escuchando en puerto 443"
    fi
    
    if netstat -tlnp | grep -q ":80.*nginx"; then
        log_success "Nginx escuchando en puerto 80 (HTTP)"
        
        # Probar redirección HTTP a HTTPS
        log_info "Probando redirección HTTP a HTTPS..."
        HTTP_RESPONSE=$(curl -s -I --connect-timeout 10 http://localhost/ 2>/dev/null | head -1)
        if echo "$HTTP_RESPONSE" | grep -q "301\|302"; then
            log_success "Redirección HTTP a HTTPS configurada correctamente"
            LOCATION=$(curl -s -I --connect-timeout 10 http://localhost/ 2>/dev/null | grep -i "location:" | cut -d' ' -f2 | tr -d '\r')
            if [ -n "$LOCATION" ]; then
                log_info "Redirige a: $LOCATION"
            fi
        else
            log_warn "Redirección HTTP a HTTPS no configurada o no funciona"
            log_info "Respuesta HTTP: $HTTP_RESPONSE"
        fi
    else
        log_warn "Nginx no está escuchando en puerto 80"
    fi
    
    # Probar proxy reverso HTTPS
    log_info "Probando proxy reverso HTTPS de Nginx..."
    if curl -s --connect-timeout 10 -k https://localhost/api/health > /dev/null 2>&1; then
        log_success "Proxy reverso HTTPS de Nginx funcionando"
    else
        log_warn "Proxy reverso HTTPS de Nginx no responde"
    fi
    
    # Verificar configuración de Nginx
    NGINX_CONFIG="/etc/nginx/sites-available/pdf-validator"
    if [ -f "$NGINX_CONFIG" ]; then
        log_success "Archivo de configuración de Nginx encontrado"
        
        # Verificar redirección en configuración
        if grep -q "return 301 https" "$NGINX_CONFIG"; then
            log_success "Redirección HTTPS configurada en Nginx"
        else
            log_warn "Redirección HTTPS no encontrada en configuración"
        fi
        
        # Verificar proxy_pass a Tomcat
        if grep -q "proxy_pass.*8080" "$NGINX_CONFIG"; then
            log_success "Proxy pass a Tomcat (puerto 8080) configurado"
        else
            log_warn "Proxy pass a Tomcat no encontrado en configuración"
        fi
    else
        log_warn "Archivo de configuración de Nginx no encontrado"
    fi
else
    log_warn "Nginx no está ejecutándose"
fi

# 7. Verificar certificados SSL
echo -e "\n${PURPLE}7. VERIFICANDO CERTIFICADOS SSL${NC}"
SSL_CERT="/etc/letsencrypt/live"
if [ -d "$SSL_CERT" ]; then
    CERT_DOMAINS=$(ls "$SSL_CERT" 2>/dev/null)
    if [ -n "$CERT_DOMAINS" ]; then
        log_success "Certificados SSL encontrados para: $CERT_DOMAINS"
        
        for domain in $CERT_DOMAINS; do
            CERT_FILE="$SSL_CERT/$domain/cert.pem"
            if [ -f "$CERT_FILE" ]; then
                CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
                if [ -n "$CERT_EXPIRY" ]; then
                    log_info "Certificado para $domain expira: $CERT_EXPIRY"
                fi
            fi
        done
    else
        log_warn "No se encontraron certificados SSL"
    fi
else
    log_warn "Directorio de certificados SSL no encontrado"
fi

# 8. Comandos útiles para troubleshooting
echo -e "\n${PURPLE}8. COMANDOS ÚTILES PARA TROUBLESHOOTING${NC}"
echo -e "${CYAN}Comandos que puedes ejecutar para más información:${NC}"
echo -e "${GREEN}# Ver estado de servicios${NC}"
echo -e "${GREEN}systemctl status tomcat nginx${NC}"
echo -e "${GREEN}# Ver logs en tiempo real${NC}"
echo -e "${GREEN}tail -f /var/lib/tomcat/logs/catalina.out${NC}"
echo -e "${GREEN}# Ver procesos Java${NC}"
echo -e "${GREEN}ps aux | grep java${NC}"
echo -e "${GREEN}# Ver puertos en uso${NC}"
echo -e "${GREEN}netstat -tlnp | grep -E ':(80|443|8080)'${NC}"
echo -e "${GREEN}# Reiniciar servicios${NC}"
echo -e "${GREEN}systemctl restart tomcat${NC}"
echo -e "${GREEN}systemctl restart nginx${NC}"
echo -e "${GREEN}# Probar endpoints manualmente${NC}"
echo -e "${GREEN}curl -v http://localhost:8080/pdf-signer-war-1.0/api/health${NC}"
echo -e "${GREEN}curl -k https://localhost/api/health${NC}"

# 9. Resumen del sistema
echo -e "\n${PURPLE}=== RESUMEN DEL SISTEMA ===${NC}"
echo -e "${GREEN}Estado de Tomcat: $(systemctl is-active tomcat 2>/dev/null || echo 'No configurado como servicio')${NC}"
echo -e "${GREEN}Instancias de Tomcat: $TOMCAT_COUNT${NC}"
echo -e "${GREEN}Puerto Tomcat: $(netstat -tlnp | grep ':8080' | wc -l) conexiones${NC}"
echo -e "${GREEN}Aplicación desplegada: $([ -f '/var/lib/tomcat/webapps/pdf-signer-war-1.0.war' ] && echo 'Sí' || echo 'No')${NC}"
echo -e "${GREEN}Estado de Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'No instalado')${NC}"
echo -e "${GREEN}Redirección HTTP→HTTPS: $(curl -s -I --connect-timeout 5 http://localhost/ 2>/dev/null | head -1 | grep -q '301\|302' && echo 'Configurada' || echo 'No configurada')${NC}"
echo -e "${GREEN}Certificado SSL: $([ -f '/etc/letsencrypt/live/*/fullchain.pem' ] && echo 'Configurado' || echo 'No configurado')${NC}"

# 10. Resumen final
echo -e "\n${PURPLE}10. RESUMEN DEL ESTADO${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"

# Determinar estado general
TOMCAT_OK=false
APP_OK=false
NGINX_OK=false

if systemctl is-active --quiet tomcat; then
    TOMCAT_OK=true
fi

if curl -s --connect-timeout 5 http://localhost:8080/pdf-signer-war-1.0/api/health > /dev/null 2>&1; then
    APP_OK=true
fi

if systemctl is-active --quiet nginx; then
    NGINX_OK=true
fi

if [ "$TOMCAT_OK" = true ] && [ "$APP_OK" = true ]; then
    log_success "✅ SISTEMA FUNCIONANDO CORRECTAMENTE"
    echo -e "${GREEN}La aplicación PDF Validator API está operativa${NC}"
    
    if [ "$NGINX_OK" = true ]; then
        echo -e "${GREEN}Acceso disponible a través de Nginx (HTTPS)${NC}"
    fi
    
    echo -e "${GREEN}URLs de prueba:${NC}"
    echo -e "${GREEN}  - HTTP directo: http://localhost:8080/pdf-signer-war-1.0/api/health${NC}"
    if [ "$NGINX_OK" = true ]; then
        echo -e "${GREEN}  - HTTPS (Nginx): https://tu-dominio.com/api/health${NC}"
    fi
elif [ "$TOMCAT_OK" = true ] && [ "$APP_OK" = false ]; then
    log_warn "⚠️  TOMCAT FUNCIONANDO PERO APLICACIÓN NO RESPONDE"
    echo -e "${YELLOW}Tomcat está ejecutándose pero la aplicación no responde${NC}"
    echo -e "${YELLOW}Posibles causas:${NC}"
    echo -e "${YELLOW}  - Aplicación aún se está iniciando${NC}"
    echo -e "${YELLOW}  - Error en el despliegue del WAR${NC}"
    echo -e "${YELLOW}  - Problemas de configuración${NC}"
    echo -e "${YELLOW}Revisa los logs: tail -f /var/lib/tomcat/logs/catalina.out${NC}"
elif [ "$TOMCAT_OK" = false ]; then
    log_error "❌ TOMCAT NO ESTÁ EJECUTÁNDOSE"
    echo -e "${RED}El servidor Tomcat no está activo${NC}"
    echo -e "${RED}Para iniciar: systemctl start tomcat${NC}"
    echo -e "${RED}Para ver logs: journalctl -u tomcat -f${NC}"
else
    log_warn "⚠️  ESTADO INDETERMINADO"
    echo -e "${YELLOW}No se pudo determinar el estado completo del sistema${NC}"
    echo -e "${YELLOW}Ejecuta los comandos de troubleshooting mostrados arriba${NC}"
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Verificación completada. Para ayuda adicional, ejecuta: ./help.sh${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"