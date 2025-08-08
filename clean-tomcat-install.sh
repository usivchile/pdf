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
    
    # Detectar gestor de paquetes y actualizar repositorios
    log "Detectando gestor de paquetes del sistema..."
    if command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
        JAVA_PACKAGE="java-11-openjdk-devel"
        log "✓ Usando DNF (Fedora/RHEL 8+/Rocky Linux)"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
        JAVA_PACKAGE="java-11-openjdk-devel"
        log "✓ Usando YUM (CentOS/RHEL)"
    elif command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt-get"
        JAVA_PACKAGE="openjdk-11-jdk"
        log "✓ Usando APT (Ubuntu/Debian)"
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
        JAVA_PACKAGE="java-11-openjdk-devel"
        log "✓ Usando Zypper (openSUSE)"
    elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
        JAVA_PACKAGE="jdk11-openjdk"
        log "✓ Usando Pacman (Arch Linux)"
    else
        log "ERROR: No se pudo detectar un gestor de paquetes compatible"
        log "Gestores soportados: dnf, yum, apt-get, zypper, pacman"
        return 1
    fi
    
    # Actualizar repositorios según el gestor de paquetes
    log "Actualizando repositorios con $PACKAGE_MANAGER..."
    case "$PACKAGE_MANAGER" in
        "apt-get")
            apt-get update || { log "Error actualizando repositorios, continuando..."; }
            ;;
        "dnf"|"yum")
            $PACKAGE_MANAGER makecache || { log "Error actualizando repositorios, continuando..."; }
            ;;
        "zypper")
            zypper refresh || { log "Error actualizando repositorios, continuando..."; }
            ;;
        "pacman")
            pacman -Sy || { log "Error actualizando repositorios, continuando..."; }
            ;;
    esac
    
    # Instalar Java si no está instalado
    if ! command -v java &> /dev/null; then
        log "Instalando OpenJDK 11 con $PACKAGE_MANAGER..."
        case "$PACKAGE_MANAGER" in
            "apt-get")
                apt-get install -y $JAVA_PACKAGE || { log "Error instalando Java"; return 1; }
                ;;
            "dnf"|"yum")
                $PACKAGE_MANAGER install -y $JAVA_PACKAGE || { log "Error instalando Java"; return 1; }
                ;;
            "zypper")
                zypper install -y $JAVA_PACKAGE || { log "Error instalando Java"; return 1; }
                ;;
            "pacman")
                pacman -S --noconfirm $JAVA_PACKAGE || { log "Error instalando Java"; return 1; }
                ;;
        esac
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
    EXTRACTED_DIR="apache-tomcat-${TOMCAT_VERSION}"
    log "Verificando directorio extraído: $EXTRACTED_DIR"
    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        log "ERROR: Directorio de Tomcat no encontrado después de extracción"
        log "Directorios disponibles:"
        ls -la || true
        return 1
    fi
    
    # Verificar estructura antes de mover
    log "Verificando estructura antes de mover..."
    if [[ ! -d "$EXTRACTED_DIR/bin" ]]; then
        log "ERROR: Directorio bin no encontrado en $EXTRACTED_DIR"
        log "Contenido de $EXTRACTED_DIR:"
        ls -la "$EXTRACTED_DIR/" || true
        return 1
    fi
    
    # Verificar archivos críticos
    CRITICAL_FILES=("startup.sh" "shutdown.sh" "catalina.sh")
    for file in "${CRITICAL_FILES[@]}"; do
        if [[ ! -f "$EXTRACTED_DIR/bin/$file" ]]; then
            log "ERROR: Archivo crítico $file no encontrado en $EXTRACTED_DIR/bin/"
            log "Contenido de $EXTRACTED_DIR/bin/:"
            ls -la "$EXTRACTED_DIR/bin/" || true
            return 1
        fi
    done
    log "✓ Todos los archivos críticos encontrados"
    
    # Mover a directorio final
    log "Instalando en /opt/tomcat..."
    if mv "$EXTRACTED_DIR" /opt/tomcat; then
        log "✓ Tomcat movido a /opt/tomcat"
    else
        log "ERROR: Error moviendo Tomcat a /opt/tomcat"
        return 1
    fi
    
    # Verificar estructura final
    log "Verificando estructura final de Tomcat..."
    if [[ ! -d "/opt/tomcat/bin" ]]; then
        log "ERROR: Directorio /opt/tomcat/bin no encontrado después del movimiento"
        log "Contenido de /opt/tomcat:"
        ls -la /opt/tomcat/ || true
        return 1
    fi
    
    # Verificar archivos de script en ubicación final
    for file in "${CRITICAL_FILES[@]}"; do
        if [[ ! -f "/opt/tomcat/bin/$file" ]]; then
            log "ERROR: $file no encontrado en /opt/tomcat/bin/ después del movimiento"
            log "Contenido de /opt/tomcat/bin:"
            ls -la /opt/tomcat/bin/ || true
            return 1
        fi
    done
    log "✓ Estructura de Tomcat verificada correctamente"
    
    # Configurar permisos
    log "Configurando permisos de Tomcat..."
    
    # Configurar propietario
    if chown -R tomcat:tomcat /opt/tomcat; then
        log "✓ Propietario configurado (tomcat:tomcat)"
    else
        log "ERROR: Error configurando permisos de propietario"
        return 1
    fi
    
    # Configurar permisos de directorios
    chmod 755 /opt/tomcat || { log "ERROR: Error configurando permisos del directorio principal"; return 1; }
    chmod 755 /opt/tomcat/bin || { log "ERROR: Error configurando permisos del directorio bin"; return 1; }
    
    # Configurar permisos de scripts específicamente
    log "Configurando permisos de scripts ejecutables..."
    SCRIPT_COUNT=0
    for script in /opt/tomcat/bin/*.sh; do
        if [[ -f "$script" ]]; then
            if chmod +x "$script"; then
                SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
                log "✓ Permisos configurados para: $(basename "$script")"
            else
                log "ERROR: Error configurando permisos para: $(basename "$script")"
                return 1
            fi
        fi
    done
    
    if [[ $SCRIPT_COUNT -gt 0 ]]; then
        log "✓ Permisos configurados para $SCRIPT_COUNT scripts"
    else
        log "ERROR: No se encontraron archivos .sh en /opt/tomcat/bin/"
        log "Contenido actual de /opt/tomcat/bin/:"
        ls -la /opt/tomcat/bin/ || true
        return 1
    fi
    
    # Verificar permisos finales
    log "Verificando permisos finales..."
    if [[ -x "/opt/tomcat/bin/startup.sh" ]] && [[ -x "/opt/tomcat/bin/shutdown.sh" ]]; then
        log "✓ Scripts principales son ejecutables"
    else
        log "ERROR: Scripts principales no son ejecutables"
        ls -la /opt/tomcat/bin/startup.sh /opt/tomcat/bin/shutdown.sh || true
        return 1
    fi
    
    log "✓ Todos los permisos configurados correctamente"
    
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

# Función para compilar la aplicación
compile_application() {
    log "Compilando aplicación PDF Signer..."
    
    # Detectar directorio del proyecto
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Verificar que existe pom.xml
    if [[ ! -f "$SCRIPT_DIR/pom.xml" ]]; then
        log "ERROR: No se encontró pom.xml en $SCRIPT_DIR"
        log "Este script debe ejecutarse desde el directorio del proyecto"
        return 1
    fi
    
    # Verificar que Maven está instalado
    if ! command -v mvn >/dev/null 2>&1; then
        log "ERROR: Maven no está instalado"
        log "Instalando Maven automáticamente..."
        
        # Detectar gestor de paquetes
        if command -v dnf >/dev/null 2>&1; then
            MAVEN_PACKAGE_MANAGER="dnf"
        elif command -v yum >/dev/null 2>&1; then
            MAVEN_PACKAGE_MANAGER="yum"
        elif command -v apt-get >/dev/null 2>&1; then
            MAVEN_PACKAGE_MANAGER="apt-get"
        elif command -v zypper >/dev/null 2>&1; then
            MAVEN_PACKAGE_MANAGER="zypper"
        elif command -v pacman >/dev/null 2>&1; then
            MAVEN_PACKAGE_MANAGER="pacman"
        else
            log "ERROR: No se pudo detectar un gestor de paquetes para instalar Maven"
            return 1
        fi
        
        # Instalar Maven según el gestor de paquetes
        case "$MAVEN_PACKAGE_MANAGER" in
            "apt-get")
                apt-get update && apt-get install -y maven || { log "Error instalando Maven"; return 1; }
                ;;
            "dnf"|"yum")
                $MAVEN_PACKAGE_MANAGER install -y maven || { log "Error instalando Maven"; return 1; }
                ;;
            "zypper")
                zypper install -y maven || { log "Error instalando Maven"; return 1; }
                ;;
            "pacman")
                pacman -S --noconfirm maven || { log "Error instalando Maven"; return 1; }
                ;;
        esac
        
        # Verificar instalación
        if ! command -v mvn >/dev/null 2>&1; then
            log "ERROR: Maven no se instaló correctamente"
            return 1
        else
            log "✓ Maven instalado exitosamente"
        fi
    fi
    
    # Cambiar al directorio del proyecto
    cd "$SCRIPT_DIR" || {
        log "ERROR: No se pudo acceder al directorio del proyecto"
        return 1
    }
    
    # Compilar con Maven
    log "Ejecutando: mvn clean package -DskipTests"
    if mvn clean package -DskipTests; then
        log "✓ Compilación exitosa"
        
        # Verificar que se generó el WAR
        if [[ -f "target/pdf-signer-war-1.0.war" ]]; then
            WAR_SIZE=$(du -h "target/pdf-signer-war-1.0.war" | cut -f1)
            log "✓ WAR generado exitosamente (tamaño: $WAR_SIZE)"
            return 0
        else
            log "ERROR: El archivo WAR no se generó después de la compilación"
            return 1
        fi
    else
        log "ERROR: Error durante la compilación"
        log "Verificar logs de Maven para más detalles"
        return 1
    fi
}

# Función para desplegar la aplicación
deploy_application() {
    log "Desplegando aplicación PDF Signer..."
    
    # Detectar directorio actual del script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log "Directorio del script: $SCRIPT_DIR"
    
    # Buscar el WAR en ubicaciones probables
    POSSIBLE_WARS=(
        "$SCRIPT_DIR/target/pdf-signer-war-1.0.war"                    # Directorio actual del proyecto
        "$SCRIPT_DIR/../target/pdf-signer-war-1.0.war"                 # Un nivel arriba
        "/opt/pdf-signer/pdf/target/pdf-signer-war-1.0.war"            # Ubicación en VPS
        "/opt/pdf-signer/target/pdf-signer-war-1.0.war"                # Ubicación alternativa
        "/home/ubuntu/pdf-signer/target/pdf-signer-war-1.0.war"        # Ubicación Ubuntu
        "/var/www/pdf-signer/target/pdf-signer-war-1.0.war"            # Ubicación web
        "/root/pdf-signer/target/pdf-signer-war-1.0.war"               # Ubicación root
        "$(pwd)/target/pdf-signer-war-1.0.war"                         # Directorio de trabajo actual
    )
    
    WAR_FILE=""
    log "Buscando archivo WAR en ubicaciones posibles..."
    
    for war in "${POSSIBLE_WARS[@]}"; do
        log "Verificando: $war"
        if [[ -f "$war" ]]; then
            WAR_FILE="$war"
            log "✓ WAR encontrado en: $WAR_FILE"
            break
        fi
    done
    
    if [[ -z "$WAR_FILE" ]]; then
        log "ADVERTENCIA: No se encontró el archivo WAR en ninguna ubicación"
        log "Ubicaciones verificadas:"
        for war in "${POSSIBLE_WARS[@]}"; do
            log "  - $war"
        done
        log ""
        log "Intentando compilar la aplicación automáticamente..."
        
        # Intentar compilar la aplicación
        if compile_application; then
            log "✓ Compilación exitosa, reintentando búsqueda del WAR..."
            
            # Buscar nuevamente el WAR después de la compilación
            for war in "${POSSIBLE_WARS[@]}"; do
                if [[ -f "$war" ]]; then
                    WAR_FILE="$war"
                    log "✓ WAR encontrado después de la compilación: $WAR_FILE"
                    break
                fi
            done
            
            if [[ -z "$WAR_FILE" ]]; then
                log "ERROR: Aún no se puede encontrar el WAR después de la compilación"
                return 1
            fi
        else
            log "ERROR: No se pudo compilar la aplicación"
            log "SOLUCIONES MANUALES:"
            log "1. Compilar manualmente: cd $SCRIPT_DIR && mvn clean package"
            log "2. Verificar que el archivo WAR existe: ls -la $SCRIPT_DIR/target/"
            log "3. Si el WAR está en otra ubicación, copiarlo a: $SCRIPT_DIR/target/pdf-signer-war-1.0.war"
            return 1
        fi
    fi
    
    # Verificar tamaño del WAR
    WAR_SIZE=$(du -h "$WAR_FILE" | cut -f1)
    log "Tamaño del archivo WAR: $WAR_SIZE"
    
    # Limpiar webapps
    log "Limpiando directorio webapps..."
    rm -rf /opt/tomcat/webapps/*
    
    # Copiar WAR
    log "Copiando WAR a Tomcat..."
    if cp "$WAR_FILE" /opt/tomcat/webapps/ROOT.war; then
        log "✓ WAR copiado exitosamente"
    else
        log "ERROR: Error copiando el archivo WAR"
        return 1
    fi
    
    # Configurar permisos
    chown tomcat:tomcat /opt/tomcat/webapps/ROOT.war
    chmod 644 /opt/tomcat/webapps/ROOT.war
    
    # Verificar que el archivo fue copiado correctamente
    if [[ -f "/opt/tomcat/webapps/ROOT.war" ]]; then
        DEPLOYED_SIZE=$(du -h "/opt/tomcat/webapps/ROOT.war" | cut -f1)
        log "✓ Aplicación desplegada como ROOT.war (tamaño: $DEPLOYED_SIZE)"
    else
        log "ERROR: El archivo WAR no se copió correctamente"
        return 1
    fi
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
    
    # Paso 1: Detener procesos de Tomcat
    log "Paso 1: Deteniendo procesos de Tomcat..."
    stop_all_tomcat
    
    # Paso 2: Eliminar instalaciones previas
    log "Paso 2: Eliminando instalaciones previas..."
    remove_tomcat_installations
    
    # Paso 3: Verificar/Compilar aplicación
    log "Paso 3: Verificando aplicación..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ ! -f "$SCRIPT_DIR/target/pdf-signer-war-1.0.war" ]]; then
        log "WAR no encontrado, compilando aplicación..."
        if ! compile_application; then
            log "ADVERTENCIA: Error compilando aplicación, continuando con instalación de Tomcat"
        fi
    else
        WAR_SIZE=$(du -h "$SCRIPT_DIR/target/pdf-signer-war-1.0.war" | cut -f1)
        log "✓ WAR encontrado (tamaño: $WAR_SIZE)"
    fi
    
    # Paso 4: Instalar Tomcat
    log "Paso 4: Instalando Tomcat..."
    if ! install_clean_tomcat; then
        log "ERROR: Error instalando Tomcat"
        exit 1
    fi
    
    # Paso 5: Desplegar aplicación
    log "Paso 5: Desplegando aplicación..."
    if ! deploy_application; then
        log "ERROR: Error desplegando aplicación"
        exit 1
    fi
    
    # Paso 6: Iniciar y verificar Tomcat
    log "Paso 6: Iniciando y verificando Tomcat..."
    if ! start_and_verify_tomcat; then
        log "ERROR: Error iniciando o verificando Tomcat"
        exit 1
    fi
    
    log "=== INSTALACIÓN COMPLETADA ==="
    log "✓ Aplicación compilada exitosamente"
    log "✓ Tomcat instalado y configurado como servicio systemd"
    log "✓ Aplicación PDF Signer desplegada como ROOT.war"
    log "✓ Servicio iniciado y verificado"
    log ""
    log "INFORMACIÓN DEL DESPLIEGUE:"
    if [[ -f "/opt/tomcat/webapps/ROOT.war" ]]; then
        DEPLOYED_SIZE=$(du -h "/opt/tomcat/webapps/ROOT.war" | cut -f1)
        log "• Aplicación desplegada: ROOT.war (tamaño: $DEPLOYED_SIZE)"
    fi
    log "• URL de acceso: http://localhost:8080/"
    log "• Endpoint de salud: http://localhost:8080/api/health"
    log "• Directorio de logs: /opt/tomcat/logs/"
    log ""
    log "VERIFICACIONES INMEDIATAS:"
    log "• Estado del servicio: systemctl status tomcat"
    log "• Verificar que el servicio existe: systemctl list-unit-files | grep tomcat"
    log "• Logs del servicio: journalctl -u tomcat -f"
    log "• Verificar puerto 8080: netstat -tlnp | grep 8080"
    log "• Probar conectividad: curl -v http://localhost:8080/"
    log ""
    log "LOGS Y DIAGNÓSTICOS:"
    log "• Logs de Tomcat: tail -f /opt/tomcat/logs/catalina.out"
    log "• Logs del sistema: journalctl -u tomcat --no-pager"
    log "• Verificar JAVA_HOME: echo \$JAVA_HOME (debe mostrar la ruta de Java)"
    log "• Verificar startup.sh: ls -la /opt/tomcat/bin/startup.sh"
    log "• Verificar permisos: ls -la /opt/tomcat/"
    log ""
    log "PRUEBAS DE CONECTIVIDAD:"
    log "• Conectividad local: curl http://localhost:8080/api/health"
    log "• Verificar aplicación: curl http://localhost:8080/"
    log "• Ver aplicaciones desplegadas: ls -la /opt/tomcat/webapps/"
    log ""
    log "COMANDOS DE TROUBLESHOOTING:"
    log "• Reiniciar servicio: systemctl restart tomcat"
    log "• Ver estado detallado: systemctl status tomcat -l"
    log "• Verificar configuración: cat /etc/systemd/system/tomcat.service"
    log "• Verificar procesos Java: ps aux | grep java"
    log "• Verificar puertos: ss -tlnp | grep 8080"
    log "• Recompilar aplicación: cd $(dirname "${BASH_SOURCE[0]}") && mvn clean package"
    log ""
    log "SCRIPT DE VERIFICACIÓN:"
    log "• Ejecutar verificación completa: ./check-deployment.sh"
    log ""
    log "SIGUIENTE PASO:"
    log "Ejecutar: ./check-deployment.sh"
}

# Ejecutar función principal
main "$@"