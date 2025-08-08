#!/bin/bash

# Script para limpiar instalaciones previas de Tomcat y hacer una instalación limpia
# Autor: Asistente AI
# Fecha: $(date)

set -e

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
    
    # Detener servicios de systemd
    for service in $(systemctl list-units --type=service | grep -i tomcat | awk '{print $1}'); do
        log "Deteniendo servicio: $service"
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
    done
    
    # Matar procesos de Tomcat que puedan estar ejecutándose
    pkill -f tomcat 2>/dev/null || true
    pkill -f catalina 2>/dev/null || true
    
    # Esperar un momento para que los procesos terminen
    sleep 3
    
    # Verificar que no hay procesos de Tomcat ejecutándose
    if pgrep -f tomcat > /dev/null; then
        log "Forzando terminación de procesos Tomcat restantes..."
        pkill -9 -f tomcat 2>/dev/null || true
        pkill -9 -f catalina 2>/dev/null || true
    fi
    
    log "Todos los procesos de Tomcat han sido detenidos"
}

# Función para eliminar instalaciones de Tomcat
remove_tomcat_installations() {
    log "Eliminando instalaciones previas de Tomcat..."
    
    # Directorios comunes de instalación de Tomcat
    TOMCAT_DIRS=(
        "/opt/tomcat*"
        "/usr/local/tomcat*"
        "/var/lib/tomcat*"
        "/usr/share/tomcat*"
        "/home/tomcat*"
        "/srv/tomcat*"
    )
    
    for dir_pattern in "${TOMCAT_DIRS[@]}"; do
        for dir in $dir_pattern; do
            if [[ -d "$dir" ]]; then
                log "Eliminando directorio: $dir"
                rm -rf "$dir"
            fi
        done
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
    apt update
    
    # Instalar Java si no está instalado
    if ! command -v java &> /dev/null; then
        log "Instalando OpenJDK 11..."
        apt install -y openjdk-11-jdk
    fi
    
    # Crear usuario tomcat
    log "Creando usuario tomcat..."
    groupadd tomcat
    useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
    
    # Descargar e instalar Tomcat 9
    TOMCAT_VERSION="9.0.82"
    TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    
    log "Descargando Tomcat ${TOMCAT_VERSION}..."
    cd /tmp
    wget "$TOMCAT_URL" -O apache-tomcat-${TOMCAT_VERSION}.tar.gz
    
    # Extraer Tomcat
    log "Extrayendo Tomcat..."
    tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
    
    # Mover a directorio final
    log "Instalando en /opt/tomcat..."
    mv apache-tomcat-${TOMCAT_VERSION} /opt/tomcat
    
    # Configurar permisos
    log "Configurando permisos..."
    chown -R tomcat:tomcat /opt/tomcat
    chmod +x /opt/tomcat/bin/*.sh
    
    # Configurar Tomcat para usar puerto 8080
    log "Configurando puerto 8080..."
    sed -i 's/port="8080"/port="8080"/' /opt/tomcat/conf/server.xml
    sed -i 's/port="[0-9]*" protocol="HTTP\/1.1"/port="8080" protocol="HTTP\/1.1"/' /opt/tomcat/conf/server.xml
    
    # Crear archivo de servicio systemd
    log "Creando servicio systemd..."
    cat > /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
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
    systemctl daemon-reload
    systemctl enable tomcat
    
    log "Tomcat instalado correctamente"
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
    systemctl start tomcat
    
    # Esperar a que Tomcat inicie
    log "Esperando a que Tomcat inicie completamente..."
    sleep 10
    
    # Verificar estado del servicio
    if systemctl is-active --quiet tomcat; then
        log "✓ Servicio Tomcat está activo"
    else
        log "✗ ERROR: Servicio Tomcat no está activo"
        systemctl status tomcat
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
    echo "- Servicio: systemctl {start|stop|restart|status} tomcat"
    echo "- Puerto: 8080"
    echo "- Usuario: tomcat"
    echo "- Logs: /opt/tomcat/logs/"
    echo "- Aplicación desplegada como ROOT"
    echo
    echo "VERIFICACIONES:"
    echo "- Estado del servicio: systemctl status tomcat"
    echo "- Puerto: netstat -tlnp | grep 8080"
    echo "- Logs: tail -f /opt/tomcat/logs/catalina.out"
    echo "- Aplicación: curl http://localhost:8080/"
    echo
    echo "SIGUIENTE PASO:"
    echo "Ejecutar: sudo ./check-deployment.sh"
}

# Ejecutar función principal
main "$@"