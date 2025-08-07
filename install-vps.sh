#!/bin/bash

# Script de instalación automatizada para PDF Validator API en VPS Hostinger (CentOS 9)
# Autor: Sistema PDF Validator
# Fecha: $(date +%Y-%m-%d)

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

# Variables de configuración
TOMCAT_VERSION="10.1.15"
TOMCAT_USER="tomcat"
TOMCAT_HOME="/opt/tomcat"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
WAR_FILE="pdf-signer-war-1.0.war"
DOMAIN="validador.usiv.cl"

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para generar contraseña segura
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

log "Iniciando instalación de PDF Validator API en VPS Hostinger..."

# 1. Actualizar el sistema
log "Actualizando el sistema..."
dnf update -y

# 2. Instalar Java 17
log "Instalando Java 17..."
dnf install java-17-openjdk java-17-openjdk-devel wget curl unzip -y

# Verificar instalación de Java
java -version
if [ $? -ne 0 ]; then
    error "Error al instalar Java 17"
fi

log "Java 17 instalado correctamente"

# 3. Crear usuario para Tomcat
log "Creando usuario para Tomcat..."
if ! id "$TOMCAT_USER" &>/dev/null; then
    useradd -m -U -d $TOMCAT_HOME -s /bin/false $TOMCAT_USER
    log "Usuario $TOMCAT_USER creado"
else
    warn "Usuario $TOMCAT_USER ya existe"
fi

# 4. Descargar e instalar Tomcat
log "Descargando Tomcat $TOMCAT_VERSION..."
cd /tmp
wget -q https://downloads.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

if [ ! -f "apache-tomcat-$TOMCAT_VERSION.tar.gz" ]; then
    error "Error al descargar Tomcat"
fi

log "Extrayendo Tomcat..."
tar -xf apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_HOME --strip-components=1

# Configurar permisos
chown -R $TOMCAT_USER: $TOMCAT_HOME
chmod +x $TOMCAT_HOME/bin/*.sh

log "Tomcat instalado en $TOMCAT_HOME"

# 5. Crear servicio systemd para Tomcat
log "Configurando servicio systemd para Tomcat..."
cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
Wants=network.target
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=$TOMCAT_HOME/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_HOME
Environment=CATALINA_BASE=$TOMCAT_HOME
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh

User=$TOMCAT_USER
Group=$TOMCAT_USER
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar Tomcat
systemctl daemon-reload
systemctl enable tomcat

log "Servicio Tomcat configurado"

# 6. Configurar usuarios administrativos de Tomcat
log "Configurando usuarios administrativos de Tomcat..."
TOMCAT_ADMIN_PASSWORD=$(generate_password)

# Backup del archivo original
cp $TOMCAT_HOME/conf/tomcat-users.xml $TOMCAT_HOME/conf/tomcat-users.xml.backup

# Configurar usuarios
sed -i '/<\/tomcat-users>/i\  <role rolename="manager-gui"/>\n  <role rolename="manager-script"/>\n  <role rolename="admin-gui"/>\n  <user username="admin" password="'$TOMCAT_ADMIN_PASSWORD'" roles="manager-gui,manager-script,admin-gui"/>' $TOMCAT_HOME/conf/tomcat-users.xml

log "Usuario administrativo configurado - Password: $TOMCAT_ADMIN_PASSWORD"

# 7. Configurar acceso al Manager (temporal)
log "Configurando acceso temporal al Manager..."
cp $TOMCAT_HOME/webapps/manager/META-INF/context.xml $TOMCAT_HOME/webapps/manager/META-INF/context.xml.backup
sed -i 's/<Valve className="org.apache.catalina.valves.RemoteAddrValve"/<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"/' $TOMCAT_HOME/webapps/manager/META-INF/context.xml
sed -i 's/allow="127\\.\\d+\\.\\d+\\.\\d+|::1|0:0:0:0:0:0:0:1" \/>/allow="127\\.\\d+\\.\\d+\\.\\d+|::1|0:0:0:0:0:0:0:1" \/> -->/' $TOMCAT_HOME/webapps/manager/META-INF/context.xml

# 8. Configurar firewall
log "Configurando firewall..."
if command_exists firewall-cmd; then
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=8443/tcp
    firewall-cmd --reload
    log "Firewall configurado"
else
    warn "firewall-cmd no encontrado, configurar manualmente"
fi

# 9. Crear directorios para la aplicación
log "Creando directorios para la aplicación..."
mkdir -p $TOMCAT_HOME/webapps/storage/pdfs
mkdir -p $TOMCAT_HOME/webapps/storage/temp
mkdir -p $TOMCAT_HOME/webapps/storage/trash
chown -R $TOMCAT_USER:$TOMCAT_USER $TOMCAT_HOME/webapps/storage
chmod -R 755 $TOMCAT_HOME/webapps/storage

log "Directorios creados"

# 10. Instalar fail2ban para seguridad
log "Instalando fail2ban..."
if ! command_exists fail2ban-server; then
    dnf install epel-release -y
    dnf install fail2ban -y
    
    # Configurar jail para Tomcat
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[tomcat-auth]
enabled = true
port = 8080,8443
filter = tomcat-auth
logpath = $TOMCAT_HOME/logs/catalina.out
maxretry = 3
bantime = 3600
EOF
    
    systemctl enable fail2ban
    systemctl start fail2ban
    log "fail2ban instalado y configurado"
else
    warn "fail2ban ya está instalado"
fi

# 11. Configurar rotación de logs
log "Configurando rotación de logs..."
cat > /etc/logrotate.d/tomcat << EOF
$TOMCAT_HOME/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 $TOMCAT_USER $TOMCAT_USER
    postrotate
        systemctl reload tomcat
    endscript
}
EOF

log "Rotación de logs configurada"

# 12. Configurar actualizaciones automáticas
log "Configurando actualizaciones automáticas..."
if ! command_exists dnf-automatic; then
    dnf install dnf-automatic -y
    systemctl enable --now dnf-automatic.timer
    log "Actualizaciones automáticas configuradas"
else
    warn "dnf-automatic ya está instalado"
fi

# 13. Iniciar Tomcat
log "Iniciando Tomcat..."
systemctl start tomcat

# Esperar a que Tomcat inicie
sleep 10

# Verificar estado
if systemctl is-active --quiet tomcat; then
    log "Tomcat iniciado correctamente"
else
    error "Error al iniciar Tomcat"
fi

# 14. Generar credenciales para la aplicación
log "Generando credenciales para la aplicación..."
API_ADMIN_PASSWORD=$(generate_password)
API_USER_PASSWORD=$(generate_password)
JWT_SECRET=$(openssl rand -base64 64 | tr -d "\n")

# 15. Crear script de despliegue
log "Creando script de despliegue..."
cat > /opt/deploy-pdf-validator.sh << EOF
#!/bin/bash
# Script de despliegue para PDF Validator API

set -e

WAR_FILE="\$1"
if [ -z "\$WAR_FILE" ]; then
    echo "Uso: \$0 <archivo.war>"
    exit 1
fi

if [ ! -f "\$WAR_FILE" ]; then
    echo "Error: Archivo \$WAR_FILE no encontrado"
    exit 1
fi

echo "Desplegando \$WAR_FILE..."

# Detener Tomcat
systemctl stop tomcat

# Limpiar despliegue anterior
rm -rf $TOMCAT_HOME/webapps/ROOT
rm -f $TOMCAT_HOME/webapps/ROOT.war

# Copiar nuevo WAR
cp "\$WAR_FILE" $TOMCAT_HOME/webapps/ROOT.war
chown $TOMCAT_USER:$TOMCAT_USER $TOMCAT_HOME/webapps/ROOT.war

# Iniciar Tomcat
systemctl start tomcat

echo "Despliegue completado. Esperando que la aplicación inicie..."
sleep 15

if systemctl is-active --quiet tomcat; then
    echo "Aplicación desplegada correctamente"
    echo "URL: http://localhost:8080"
else
    echo "Error: Tomcat no está ejecutándose"
    exit 1
fi
EOF

chmod +x /opt/deploy-pdf-validator.sh

# 16. Crear script de backup
log "Creando script de backup..."
cat > /opt/backup-pdf-validator.sh << EOF
#!/bin/bash
# Script de backup para PDF Validator API

BACKUP_DIR="/backup/pdf-validator"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

echo "Creando backup \$DATE..."

# Backup de archivos
tar -czf \$BACKUP_DIR/storage_\$DATE.tar.gz $TOMCAT_HOME/webapps/storage/

# Backup de configuración
cp $TOMCAT_HOME/webapps/ROOT/WEB-INF/classes/application.properties \$BACKUP_DIR/config_\$DATE.properties 2>/dev/null || true

# Limpiar backups antiguos (más de 30 días)
find \$BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completado: \$BACKUP_DIR/storage_\$DATE.tar.gz"
EOF

chmod +x /opt/backup-pdf-validator.sh

# 17. Configurar cron para backup automático
log "Configurando backup automático..."
echo "0 2 * * * /opt/backup-pdf-validator.sh >> /var/log/pdf-validator-backup.log 2>&1" | crontab -

# 18. Mostrar resumen de instalación
log "\n=== INSTALACIÓN COMPLETADA ==="
echo -e "${BLUE}Tomcat instalado en: $TOMCAT_HOME${NC}"
echo -e "${BLUE}Usuario Tomcat: $TOMCAT_USER${NC}"
echo -e "${BLUE}Usuario Admin Tomcat: admin${NC}"
echo -e "${BLUE}Password Admin Tomcat: $TOMCAT_ADMIN_PASSWORD${NC}"
echo -e "${BLUE}URL Tomcat Manager: http://$(hostname -I | awk '{print $1}'):8080/manager${NC}"
echo -e "${BLUE}Directorio de almacenamiento: $TOMCAT_HOME/webapps/storage${NC}"
echo -e "${BLUE}Script de despliegue: /opt/deploy-pdf-validator.sh${NC}"
echo -e "${BLUE}Script de backup: /opt/backup-pdf-validator.sh${NC}"

echo -e "\n${YELLOW}=== CREDENCIALES DE LA APLICACIÓN ===${NC}"
echo -e "${BLUE}Admin Username: admin${NC}"
echo -e "${BLUE}Admin Password: $API_ADMIN_PASSWORD${NC}"
echo -e "${BLUE}User Username: user${NC}"
echo -e "${BLUE}User Password: $API_USER_PASSWORD${NC}"
echo -e "${BLUE}JWT Secret: $JWT_SECRET${NC}"

echo -e "\n${YELLOW}=== PRÓXIMOS PASOS ===${NC}"
echo -e "${GREEN}1. Configurar certificado SSL${NC}"
echo -e "${GREEN}2. Configurar proxy reverso (Nginx/Apache)${NC}"
echo -e "${GREEN}3. Desplegar aplicación: /opt/deploy-pdf-validator.sh $WAR_FILE${NC}"
echo -e "${GREEN}4. Configurar variables de entorno si es necesario${NC}"
echo -e "${GREEN}5. Probar la aplicación${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Ver logs: sudo tail -f $TOMCAT_HOME/logs/catalina.out${NC}"
echo -e "${GREEN}Reiniciar Tomcat: sudo systemctl restart tomcat${NC}"
echo -e "${GREEN}Estado Tomcat: sudo systemctl status tomcat${NC}"
echo -e "${GREEN}Backup manual: sudo /opt/backup-pdf-validator.sh${NC}"

# Guardar credenciales en archivo
cat > /root/pdf-validator-credentials.txt << EOF
=== CREDENCIALES PDF VALIDATOR API ===
Fecha instalación: $(date)
Dominio: $DOMAIN

Tomcat Admin:
  Usuario: admin
  Password: $TOMCAT_ADMIN_PASSWORD

API Credentials:
  Admin Username: admin
  Admin Password: $API_ADMIN_PASSWORD
  User Username: user
  User Password: $API_USER_PASSWORD
  JWT Secret: $JWT_SECRET

Directorios:
  Tomcat Home: $TOMCAT_HOME
  Storage: $TOMCAT_HOME/webapps/storage
  Logs: $TOMCAT_HOME/logs

Scripts:
  Deploy: /opt/deploy-pdf-validator.sh
  Backup: /opt/backup-pdf-validator.sh
EOF

chmod 600 /root/pdf-validator-credentials.txt

log "Credenciales guardadas en: /root/pdf-validator-credentials.txt"
log "Instalación completada exitosamente!"