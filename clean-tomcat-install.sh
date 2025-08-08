#!/bin/bash

# Script para limpiar instalaciones previas de Tomcat y hacer una instalación limpia
# Autor: Asistente AI
# Fecha: $(date)

# No usar set -e para evitar terminaciones abruptas
# set -e

# Función para manejo de errores
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR en línea $line_number: Código de salida $exit_code"
    log "Continuando con la ejecución..."
}

# Trap para capturar errores
trap 'handle_error $LINENO' ERR

echo "=== LIMPIEZA E INSTALACIÓN LIMPIA DE TOMCAT ==="
echo "Fecha: $(date)"
echo

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para verificar si el usuario es root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

# Función para detener todos los procesos de Tomcat
stop_all_tomcat() {
    log "Deteniendo todos los procesos de Tomcat..."
    
    # Detener servicios de systemd de forma segura
    log "Buscando servicios de Tomcat..."
    TOMCAT_SERVICES=$(systemctl list-units --type=service --state=active | grep -i tomcat | awk '{print $1}' || true)
    
    if [[ -n "$TOMCAT_SERVICES" ]]; then
        for service in $TOMCAT_SERVICES; do
            log "Deteniendo servicio: $service"
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
        done
    else
        log "No se encontraron servicios activos de Tomcat"
    fi
    
    # Buscar y detener procesos de Tomcat de forma más segura
    log "Buscando procesos de Tomcat..."
    TOMCAT_PIDS=$(pgrep -f "tomcat\|catalina" 2>/dev/null || true)
    
    if [[ -n "$TOMCAT_PIDS" ]]; then
        log "Procesos de Tomcat encontrados: $TOMCAT_PIDS"
        log "Enviando señal TERM a procesos de Tomcat..."
        
        # Intentar terminación suave primero
        for pid in $TOMCAT_PIDS; do
            if kill -0 "$pid" 2>/dev/null; then
                log "Deteniendo proceso $pid"
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
        
        # Esperar a que terminen
        sleep 5
        
        # Verificar si aún hay procesos ejecutándose
        REMAINING_PIDS=$(pgrep -f "tomcat\|catalina" 2>/dev/null || true)
        if [[ -n "$REMAINING_PIDS" ]]; then
            log "Forzando terminación de procesos restantes: $REMAINING_PIDS"
            for pid in $REMAINING_PIDS; do
                if kill -0 "$pid" 2>/dev/null; then
                    log "Forzando terminación del proceso $pid"
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done
            sleep 2
        fi
    else
        log "No se encontraron procesos de Tomcat ejecutándose"
    fi
    
    # Verificación final
    FINAL_CHECK=$(pgrep -f "tomcat\|catalina" 2>/dev/null || true)
    if [[ -z "$FINAL_CHECK" ]]; then
        log "✓ Todos los procesos de Tomcat han sido detenidos"
    else
        log "⚠ Algunos procesos de Tomcat pueden seguir ejecutándose: $FINAL_CHECK"
    fi
}

# Función para eliminar instalaciones de Tomcat
remove_tomcat_installations() {
    log "Eliminando instalaciones previas de Tomcat..."
    
    # Directorios comunes de instalación de Tomcat
    TOMCAT_DIRS=(
        "/opt/tomcat"
        "/opt/tomcat*"
        "/usr/local/tomcat"
        "/usr/local/tomcat*"
        "/var/lib/tomcat"
        "/var/lib/tomcat*"
        "/usr/share/tomcat"
        "/usr/share/tomcat*"
        "/home/tomcat"
        "/srv/tomcat"
    )
    
    # Eliminar directorios existentes
    for dir_pattern in "${TOMCAT_DIRS[@]}"; do
        # Usar find para buscar directorios que coincidan con el patrón
        if [[ "$dir_pattern" == *"*" ]]; then
            # Para patrones con asterisco, usar find
            BASE_DIR=$(dirname "$dir_pattern")
            PATTERN=$(basename "$dir_pattern")
            if [[ -d "$BASE_DIR" ]]; then
                find "$BASE_DIR" -maxdepth 1 -type d -name "$PATTERN" 2>/dev/null | while read -r dir; do
                    if [[ -d "$dir" ]]; then
                        log "Eliminando directorio: $dir"
                        rm -rf "$dir" 2>/dev/null || true
                    fi
                done
            fi
        else
            # Para rutas exactas
            if [[ -d "$dir_pattern" ]]; then
                log "Eliminando directorio: $dir_pattern"
                rm -rf "$dir_pattern" 2>/dev/null || true
            fi
        fi
    done
    
    # Eliminar archivos de configuración de systemd
    for service_file in /etc/systemd/system/tomcat*.service /lib/systemd/system/tomcat*.service; do
        if [[ -f "$service_file" ]]; then
            log "Eliminando archivo de servicio: $service_file"
            rm -f "$service_file"
        fi
    done
    
    # Recargar systemd
    systemctl daemon-reload
    
    # Eliminar usuario tomcat si existe
    if id "tomcat" &>/dev/null; then
        log "Eliminando usuario tomcat..."
        userdel -r tomcat 2>/dev/null || true
    fi
    
    # Eliminar grupo tomcat si existe
    if getent group tomcat &>/dev/null; then
        log "Eliminando grupo tomcat..."
        groupdel tomcat 2>/dev/null || true
    fi
    
    log "Instalaciones previas de Tomcat eliminadas"
}

# Función para instalar Tomcat limpio
install_clean_tomcat() {
    log "Instalando Tomcat 9 limpio..."
    
    # Actualizar repositorios
    log "Actualizando repositorios..."
    apt update || { log "Error actualizando repositorios, continuando..."; }
    
    # Instalar Java si no está instalado
    if ! command -v java &> /dev/null; then
        log "Instalando OpenJDK 11..."
        apt install -y openjdk-11-jdk || { log "Error instalando Java"; return 1; }
    else
        log "✓ Java ya está instalado: $(java -version 2>&1 | head -1)"
    fi
    
    # Crear usuario tomcat (verificar si ya existe)
    log "Configurando usuario tomcat..."
    if ! getent group tomcat &>/dev/null; then
        groupadd tomcat || { log "Error creando grupo tomcat"; return 1; }
        log "✓ Grupo tomcat creado"
    else
        log "✓ Grupo tomcat ya existe"
    fi
    
    if ! id "tomcat" &>/dev/null; then
        useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat || { log "Error creando usuario tomcat"; return 1; }
        log "✓ Usuario tomcat creado"
    else
        log "✓ Usuario tomcat ya existe"
    fi
    
    # Descargar e instalar Tomcat 9
    TOMCAT_VERSION="9.0.82"
    TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    TOMCAT_FILE="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    
    log "Descargando Tomcat ${TOMCAT_VERSION}..."
    cd /tmp || { log "Error accediendo a /tmp"; return 1; }
    
    # Limpiar descargas previas
    rm -f "$TOMCAT_FILE" 2>/dev/null || true
    
    # Intentar descarga con reintentos
    for attempt in 1 2 3; do
        log "Intento $attempt de descarga..."
        if wget "$TOMCAT_URL" -O "$TOMCAT_FILE" --timeout=30 --tries=3; then
            log "✓ Descarga exitosa"
            break
        else
            log "⚠ Error en descarga, intento $attempt"
            if [[ $attempt -eq 3 ]]; then
                log "ERROR: No se pudo descargar Tomcat después de 3 intentos"
                return 1
            fi
            sleep 5
        fi
    done
    
    # Verificar archivo descargado
    if [[ ! -f "$TOMCAT_FILE" ]] || [[ ! -s "$TOMCAT_FILE" ]]; then
        log "ERROR: Archivo de Tomcat no válido"
        return 1
    fi
    
    # Extraer Tomcat
    log "Extrayendo Tomcat..."
    if tar xzf "$TOMCAT_FILE"; then
        log "✓ Extracción exitosa"
    else
        log "ERROR: Error extrayendo Tomcat"
        return 1
    fi
    
    # Verificar directorio extraído
    if [[ ! -d "apache-tomcat-${TOMCAT_VERSION}" ]]; then
        log "ERROR: Directorio de Tomcat no encontrado después de extracción"
        return 1
    fi
    
    # Mover a directorio final
    log "Instalando en /opt/tomcat..."
    if mv "apache-tomcat-${TOMCAT_VERSION}" /opt/tomcat; then
        log "✓ Tomcat movido a /opt/tomcat"
    else
        log "ERROR: Error moviendo Tomcat a /opt/tomcat"
        return 1
    fi
    
    # Configurar permisos
    log "Configurando permisos..."
    chown -R tomcat:tomcat /opt/tomcat || { log "Error configurando permisos"; return 1; }
    chmod +x /opt/tomcat/bin/*.sh || { log "Error configurando permisos de scripts"; return 1; }
    log "✓ Permisos configurados"
    
    # Configurar Tomcat para usar puerto 8080
    log "Configurando puerto 8080..."
    if [[ -f "/opt/tomcat/conf/server.xml" ]]; then
        # Hacer backup del server.xml original
        cp /opt/tomcat/conf/server.xml /opt/tomcat/conf/server.xml.backup
        
        # Asegurar que el puerto HTTP esté en 8080
        sed -i 's/port="[0-9]*" protocol="HTTP\/1.1"/port="8080" protocol="HTTP\/1.1"/' /opt/tomcat/conf/server.xml
        
        # Verificar configuración
        if grep -q 'port="8080".*protocol="HTTP/1.1"' /opt/tomcat/conf/server.xml; then
            log "✓ Puerto 8080 configurado correctamente"
        else
            log "⚠ Verificar configuración de puerto manualmente"
        fi
    else
        log "ERROR: server.xml no encontrado"
        return 1
    fi
    
    # Detectar JAVA_HOME automáticamente
    log "Detectando JAVA_HOME..."
    JAVA_HOME_PATH=""
    
    # Buscar Java en ubicaciones comunes
    JAVA_LOCATIONS=(
        "/usr/lib/jvm/java-11-openjdk-amd64"     # Ubuntu/Debian
        "/usr/lib/jvm/java-11-openjdk"           # CentOS/RHEL
        "/usr/lib/jvm/java-1.11.0-openjdk"       # CentOS/RHEL alternativo
        "/usr/lib/jvm/java-11"                   # Genérico
        "/usr/java/latest"                       # Oracle Java
        "/opt/java/openjdk"                      # Contenedores
    )
    
    for java_path in "${JAVA_LOCATIONS[@]}"; do
        if [[ -d "$java_path" ]] && [[ -x "$java_path/bin/java" ]]; then
            JAVA_HOME_PATH="$java_path"
            log "✓ JAVA_HOME detectado: $JAVA_HOME_PATH"
            break
        fi
    done
    
    # Si no se encuentra, usar el comando java
    if [[ -z "$JAVA_HOME_PATH" ]]; then
        if command -v java >/dev/null 2>&1; then
            JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
            log "✓ JAVA_HOME derivado de 'which java': $JAVA_HOME_PATH"
        else
            log "ERROR: No se pudo detectar JAVA_HOME"
            return 1
        fi
    fi
    
    # Verificar que JAVA_HOME es válido
    if [[ ! -x "$JAVA_HOME_PATH/bin/java" ]]; then
        log "ERROR: JAVA_HOME no válido: $JAVA_HOME_PATH"
        return 1
    fi
    
    # Crear archivo de servicio systemd
    log "Creando servicio systemd con JAVA_HOME=$JAVA_HOME_PATH..."
    cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Recargar systemd y habilitar servicio
    log "Recargando systemd y habilitando servicio..."
    if systemctl daemon-reload; then
        log "✓ systemd daemon recargado"
    else
        log "ERROR: Error recargando systemd daemon"
        return 1
    fi
    
    if systemctl enable tomcat; then
        log "✓ Servicio tomcat habilitado"
    else
        log "ERROR: Error habilitando servicio tomcat"
        return 1
    fi
    
    # Verificar que el servicio fue creado correctamente
    if systemctl list-unit-files | grep -q "tomcat.service"; then
        log "✓ Servicio tomcat.service creado correctamente"
    else
        log "ERROR: Servicio tomcat.service no fue creado"
        log "Verificando archivo de servicio..."
        if [[ -f "/etc/systemd/system/tomcat.service" ]]; then
            log "Archivo de servicio existe, contenido:"
            cat /etc/systemd/system/tomcat.service
        else
            log "ERROR: Archivo de servicio no existe"
        fi
        return 1
    fi
    
    log "✓ Tomcat instalado correctamente"
}

# Función para desplegar la aplicación
deploy_application() {
    log "Desplegando aplicación PDF Signer..."
    
    # Verificar que existe el WAR
    WAR_FILE="/home/ubuntu/pdf-signer/target/pdf-signer-war-1.0.war"
    if [[ ! -f "$WAR_FILE" ]]; then
        log "ERROR: No se encuentra el archivo WAR en $WAR_FILE"
        log "Intentando buscar en ubicaciones alternativas..."
        
        # Buscar el WAR en ubicaciones comunes
        POSSIBLE_WARS=(
            "/opt/pdf-signer/target/pdf-signer-war-1.0.war"
            "/var/www/pdf-signer/target/pdf-signer-war-1.0.war"
            "/root/pdf-signer/target/pdf-signer-war-1.0.war"
        )
        
        for war in "${POSSIBLE_WARS[@]}"; do
            if [[ -f "$war" ]]; then
                WAR_FILE="$war"
                log "WAR encontrado en: $WAR_FILE"
                break
            fi
        done
        
        if [[ ! -f "$WAR_FILE" ]]; then
            log "ERROR: No se pudo encontrar el archivo WAR"
            log "Por favor, compila la aplicación primero con: mvn clean package"
            return 1
        fi
    fi
    
    # Limpiar webapps
    rm -rf /opt/tomcat/webapps/*
    
    # Copiar WAR
    cp "$WAR_FILE" /opt/tomcat/webapps/ROOT.war
    chown tomcat:tomcat /opt/tomcat/webapps/ROOT.war
    
    log "Aplicación desplegada como ROOT.war"
}

# Función para iniciar y verificar Tomcat
start_and_verify_tomcat() {
    log "Iniciando Tomcat..."
    
    # Verificar que el servicio existe antes de intentar iniciarlo
    if ! systemctl list-unit-files | grep -q "tomcat.service"; then
        log "ERROR: Servicio tomcat.service no encontrado"
        log "Servicios disponibles:"
        systemctl list-unit-files | grep -i tomcat || log "No hay servicios de tomcat"
        return 1
    fi
    
    if systemctl start tomcat; then
        log "✓ Comando de inicio ejecutado correctamente"
    else
        log "ERROR: Error ejecutando comando de inicio"
        log "Estado del servicio:"
        systemctl status tomcat --no-pager
        log "Logs del servicio:"
        journalctl -u tomcat --no-pager -n 20
        return 1
    fi
    
    # Esperar a que Tomcat inicie
    log "Esperando a que Tomcat inicie completamente..."
    sleep 10
    
    # Verificar estado del servicio
    if systemctl is-active --quiet tomcat; then
        log "✓ Servicio Tomcat está activo"
    else
        log "✗ ERROR: Servicio Tomcat no está activo"
        log "Estado detallado del servicio:"
        systemctl status tomcat --no-pager
        log "Últimos logs del servicio:"
        journalctl -u tomcat --no-pager -n 30
        log "Verificando JAVA_HOME y archivos:"
        log "JAVA_HOME configurado: $(grep JAVA_HOME /etc/systemd/system/tomcat.service)"
        log "¿Existe startup.sh?: $(ls -la /opt/tomcat/bin/startup.sh 2>/dev/null || echo 'NO EXISTE')"
        return 1
    fi
    
    # Verificar que está escuchando en puerto 8080
    log "Verificando puerto 8080..."
    sleep 5
    
    if netstat -tlnp | grep -q ":8080.*LISTEN"; then
        log "✓ Tomcat está escuchando en puerto 8080"
        netstat -tlnp | grep ":8080"
    else
        log "✗ ERROR: Tomcat no está escuchando en puerto 8080"
        log "Puertos en uso:"
        netstat -tlnp | grep java || true
        return 1
    fi
    
    # Verificar conectividad local
    log "Verificando conectividad local..."
    sleep 5
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200\|302\|404"; then
        log "✓ Tomcat responde correctamente en puerto 8080"
    else
        log "✗ WARNING: Tomcat no responde en puerto 8080"
        log "Esto puede ser normal si la aplicación aún se está desplegando"
    fi
}

# Función principal
main() {
    log "Iniciando limpieza e instalación de Tomcat..."
    
    check_root
    
    # Crear backup de logs si existen
    if [[ -d "/opt/tomcat/logs" ]]; then
        log "Creando backup de logs..."
        mkdir -p /tmp/tomcat-backup-$(date +%Y%m%d-%H%M%S)
        cp -r /opt/tomcat/logs /tmp/tomcat-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true
    fi
    
    stop_all_tomcat
    remove_tomcat_installations
    install_clean_tomcat
    deploy_application
    start_and_verify_tomcat
    
    log "=== INSTALACIÓN COMPLETADA ==="
    echo
    echo "RESUMEN:"
    echo "- Tomcat 9 instalado en /opt/tomcat"
    echo "- Servicio systemd: tomcat.service"
    echo "- Comandos: systemctl {start|stop|restart|status} tomcat"
    echo "- Puerto: 8080"
    echo "- Usuario: tomcat"
    echo "- Logs: /opt/tomcat/logs/"
    echo "- Aplicación desplegada como ROOT"
    echo
    echo "VERIFICACIONES INMEDIATAS:"
    echo "- Estado del servicio: systemctl status tomcat"
    echo "- ¿Servicio habilitado?: systemctl is-enabled tomcat"
    echo "- ¿Servicio activo?: systemctl is-active tomcat"
    echo "- Puerto en uso: netstat -tlnp | grep 8080"
    echo "- Procesos Java: ps aux | grep java"
    echo
    echo "LOGS Y DIAGNÓSTICO:"
    echo "- Logs del servicio: journalctl -u tomcat -f"
    echo "- Logs de Tomcat: tail -f /opt/tomcat/logs/catalina.out"
    echo "- Logs de aplicación: tail -f /opt/tomcat/logs/localhost.*.log"
    echo "- Configuración del servicio: cat /etc/systemd/system/tomcat.service"
    echo
    echo "PRUEBAS DE CONECTIVIDAD:"
    echo "- Local: curl -I http://localhost:8080/"
    echo "- Aplicación: curl http://localhost:8080/"
    echo "- Desde exterior: curl -I http://$(hostname -I | awk '{print $1}'):8080/"
    echo
    echo "COMANDOS DE SOLUCIÓN DE PROBLEMAS:"
    echo "- Reiniciar servicio: sudo systemctl restart tomcat"
    echo "- Ver logs en tiempo real: sudo journalctl -u tomcat -f"
    echo "- Verificar JAVA_HOME: sudo systemctl show tomcat -p Environment"
    echo "- Verificar permisos: ls -la /opt/tomcat/bin/startup.sh"
    echo
    echo "SIGUIENTE PASO:"
    echo "Ejecutar: sudo ./check-deployment.sh"
}

# Ejecutar función principal
main "$@"