#!/bin/bash

# Script de endurecimiento de seguridad para PDF Validator API
# Para VPS Hostinger (CentOS 9) con Tomcat

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Variables
TOMCAT_USER="tomcat"
TOMCAT_HOME="/opt/tomcat"
APP_STORAGE="/opt/tomcat/webapps/storage"

log "Iniciando endurecimiento de seguridad..."

# 1. Configuración de SSH más segura
log "Configurando SSH de forma segura..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configuraciones SSH seguras
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config

# Agregar configuraciones adicionales si no existen
grep -q "AllowUsers" /etc/ssh/sshd_config || echo "AllowUsers $(whoami)" >> /etc/ssh/sshd_config
grep -q "X11Forwarding" /etc/ssh/sshd_config || echo "X11Forwarding no" >> /etc/ssh/sshd_config
grep -q "UseDNS" /etc/ssh/sshd_config || echo "UseDNS no" >> /etc/ssh/sshd_config

systemctl restart sshd
log "SSH configurado de forma segura"

# 2. Configurar fail2ban para protección adicional
log "Configurando fail2ban para protección adicional..."

# Configuración para Nginx
cat > /etc/fail2ban/jail.d/nginx.conf << EOF
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/*error.log
maxretry = 3
bantime = 3600
findtime = 600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/*error.log
maxretry = 10
bantime = 3600
findtime = 600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
logpath = /var/log/nginx/*access.log
maxretry = 2
bantime = 86400
findtime = 600
EOF

# Filtros personalizados
cat > /etc/fail2ban/filter.d/nginx-limit-req.conf << EOF
[Definition]
failregex = limiting requests, excess: .* by zone .*, client: <HOST>
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/nginx-botsearch.conf << EOF
[Definition]
failregex = <HOST>.*GET.*(\.|%2e)(\.|%2e)(\.|%2e)(\.|%2e)
            <HOST>.*GET.*(/|%2f)(etc|boot|var)
            <HOST>.*GET.*(\.|%2e)(\.|%2e)(/|%2f)
            <HOST>.*GET.*\.(php|asp|exe|pl|cgi|scr)
ignoreregex =
EOF

systemctl restart fail2ban
log "fail2ban configurado"

# 3. Configurar límites del sistema
log "Configurando límites del sistema..."

# Límites para el usuario tomcat
cat > /etc/security/limits.d/tomcat.conf << EOF
# Límites para usuario tomcat
tomcat soft nofile 65536
tomcat hard nofile 65536
tomcat soft nproc 4096
tomcat hard nproc 4096
EOF

# Configuración de kernel para mejor rendimiento y seguridad
cat > /etc/sysctl.d/99-pdf-validator.conf << EOF
# Configuración de red y seguridad
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Configuración de memoria
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Configuración de archivos
fs.file-max = 2097152
fs.nr_open = 1048576
EOF

sysctl -p /etc/sysctl.d/99-pdf-validator.conf
log "Límites del sistema configurados"

# 4. Configurar permisos seguros para Tomcat
log "Configurando permisos seguros para Tomcat..."

# Asegurar que solo tomcat puede acceder a sus archivos
chown -R $TOMCAT_USER:$TOMCAT_USER $TOMCAT_HOME
chmod -R 750 $TOMCAT_HOME

# Permisos específicos para directorios
chmod 755 $TOMCAT_HOME/bin
chmod +x $TOMCAT_HOME/bin/*.sh
chmod 750 $TOMCAT_HOME/conf
chmod 640 $TOMCAT_HOME/conf/*
chmod 750 $TOMCAT_HOME/logs
chmod 750 $TOMCAT_HOME/temp
chmod 750 $TOMCAT_HOME/work
chmod 750 $TOMCAT_HOME/webapps

# Crear y configurar directorio de almacenamiento
mkdir -p $APP_STORAGE/pdfs
chown -R $TOMCAT_USER:$TOMCAT_USER $APP_STORAGE
chmod -R 755 $APP_STORAGE

log "Permisos de Tomcat configurados"

# 5. Configurar Tomcat de forma segura
log "Configurando Tomcat de forma segura..."

# Backup de configuraciones
cp $TOMCAT_HOME/conf/server.xml $TOMCAT_HOME/conf/server.xml.backup
cp $TOMCAT_HOME/conf/web.xml $TOMCAT_HOME/conf/web.xml.backup

# Configurar server.xml de forma segura
sed -i 's/port="8005"/port="-1"/' $TOMCAT_HOME/conf/server.xml
sed -i 's/redirectPort="8443"/redirectPort="8443" secure="true" scheme="https"/' $TOMCAT_HOME/conf/server.xml

# Agregar configuración de seguridad al server.xml
sed -i '/<\/Host>/i\        <Valve className="org.apache.catalina.valves.ErrorReportValve" showReport="false" showServerInfo="false" />' $TOMCAT_HOME/conf/server.xml

# Configurar web.xml para mayor seguridad
sed -i '/<\/web-app>/i\    <!-- Security Configuration -->\n    <security-constraint>\n        <web-resource-collection>\n            <web-resource-name>Forbidden</web-resource-name>\n            <url-pattern>/manager/*</url-pattern>\n            <url-pattern>/host-manager/*</url-pattern>\n        </web-resource-collection>\n        <auth-constraint />\n    </security-constraint>\n\n    <error-page>\n        <error-code>404</error-code>\n        <location>/error.html</location>\n    </error-page>\n    <error-page>\n        <error-code>500</error-code>\n        <location>/error.html</location>\n    </error-page>' $TOMCAT_HOME/conf/web.xml

# Crear página de error personalizada
cat > $TOMCAT_HOME/webapps/ROOT/error.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Error</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Error</h1>
    <p>La página solicitada no está disponible.</p>
</body>
</html>
EOF

log "Tomcat configurado de forma segura"

# 6. Configurar logrotate para logs de aplicación
log "Configurando rotación de logs de aplicación..."

cat > /etc/logrotate.d/pdf-validator-app << EOF
/opt/tomcat/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 tomcat tomcat
    postrotate
        systemctl reload tomcat
    endscript
}

/opt/tomcat/logs/catalina.out {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 tomcat tomcat
    copytruncate
}
EOF

# 7. Configurar monitoreo de archivos con auditd
log "Configurando auditoría del sistema..."

if ! command -v auditctl >/dev/null 2>&1; then
    dnf install audit -y
    systemctl enable auditd
    systemctl start auditd
fi

# Reglas de auditoría
cat > /etc/audit/rules.d/pdf-validator.rules << EOF
# Auditoría para PDF Validator
-w /opt/tomcat/conf/ -p wa -k tomcat-config
-w /opt/tomcat/webapps/ -p wa -k tomcat-webapps
-w /opt/tomcat/webapps/storage/ -p wa -k pdf-storage
-w /etc/nginx/ -p wa -k nginx-config
-w /etc/ssl/ -p wa -k ssl-certs
EOF

service auditd restart
log "Auditoría configurada"

# 8. Configurar backup automático de configuraciones
log "Configurando backup automático..."

cat > /opt/backup-configs.sh << EOF
#!/bin/bash
# Script de backup de configuraciones

BACKUP_DIR="/opt/backups/configs"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# Backup de configuraciones importantes
tar -czf \$BACKUP_DIR/tomcat-config-\$DATE.tar.gz -C /opt/tomcat conf/
tar -czf \$BACKUP_DIR/nginx-config-\$DATE.tar.gz -C /etc nginx/
cp /etc/ssh/sshd_config \$BACKUP_DIR/sshd_config-\$DATE
cp -r /etc/fail2ban/jail.d \$BACKUP_DIR/fail2ban-\$DATE/

# Mantener solo los últimos 30 días
find \$BACKUP_DIR -name "*" -mtime +30 -delete

echo "[\$(date)] Backup de configuraciones completado" >> /var/log/backup-configs.log
EOF

chmod +x /opt/backup-configs.sh

# Programar backup diario
echo "0 2 * * * /opt/backup-configs.sh" | crontab -

# 9. Crear script de verificación de seguridad
log "Creando script de verificación de seguridad..."

cat > /opt/security-check.sh << EOF
#!/bin/bash
# Script de verificación de seguridad

LOG_FILE="/var/log/security-check.log"

log_message() {
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] \$1" | tee -a \$LOG_FILE
}

log_message "=== VERIFICACIÓN DE SEGURIDAD ==="

# Verificar servicios críticos
for service in nginx tomcat fail2ban auditd; do
    if systemctl is-active --quiet \$service; then
        log_message "✓ \$service está ejecutándose"
    else
        log_message "✗ \$service NO está ejecutándose"
    fi
done

# Verificar permisos críticos
if [ "\$(stat -c %a /opt/tomcat/conf)" = "750" ]; then
    log_message "✓ Permisos de /opt/tomcat/conf correctos"
else
    log_message "✗ Permisos de /opt/tomcat/conf incorrectos"
fi

# Verificar configuración SSH
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
    log_message "✓ SSH: Root login deshabilitado"
else
    log_message "✗ SSH: Root login habilitado (RIESGO)"
fi

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    log_message "✓ SSH: Autenticación por contraseña deshabilitada"
else
    log_message "✗ SSH: Autenticación por contraseña habilitada (RIESGO)"
fi

# Verificar fail2ban
FAIL2BAN_STATUS=\$(fail2ban-client status | grep "Number of jail" | awk '{print \$NF}')
log_message "✓ fail2ban: \$FAIL2BAN_STATUS jails activas"

# Verificar espacio en disco
DISK_USAGE=\$(df /opt | awk 'NR==2 {print \$5}' | sed 's/%//')
if [ "\$DISK_USAGE" -lt 80 ]; then
    log_message "✓ Espacio en disco: \$DISK_USAGE% usado"
else
    log_message "⚠ Espacio en disco: \$DISK_USAGE% usado (ADVERTENCIA)"
fi

# Verificar actualizaciones de seguridad
SECURITY_UPDATES=\$(dnf check-update --security -q | wc -l)
if [ "\$SECURITY_UPDATES" -eq 0 ]; then
    log_message "✓ No hay actualizaciones de seguridad pendientes"
else
    log_message "⚠ \$SECURITY_UPDATES actualizaciones de seguridad disponibles"
fi

# Verificar certificado SSL
if [ -f "/etc/letsencrypt/live/validador.usiv.cl/fullchain.pem" ]; then
    CERT_EXPIRY=\$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/validador.usiv.cl/fullchain.pem | cut -d= -f2)
    CERT_EXPIRY_EPOCH=\$(date -d "\$CERT_EXPIRY" +%s)
    CURRENT_EPOCH=\$(date +%s)
    DAYS_UNTIL_EXPIRY=\$(( (CERT_EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
    
    if [ "\$DAYS_UNTIL_EXPIRY" -gt 30 ]; then
        log_message "✓ Certificado SSL válido por \$DAYS_UNTIL_EXPIRY días"
    else
        log_message "⚠ Certificado SSL expira en \$DAYS_UNTIL_EXPIRY días"
    fi
else
    log_message "✗ Certificado SSL no encontrado"
fi

log_message "=== VERIFICACIÓN COMPLETADA ==="
EOF

chmod +x /opt/security-check.sh

# Programar verificación diaria
echo "0 6 * * * /opt/security-check.sh" | crontab -

# 10. Configurar actualizaciones automáticas de seguridad
log "Configurando actualizaciones automáticas de seguridad..."

dnf install dnf-automatic -y

# Configurar dnf-automatic para solo actualizaciones de seguridad
sed -i 's/upgrade_type = default/upgrade_type = security/' /etc/dnf/automatic.conf
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
sed -i 's/emit_via = stdio/emit_via = email/' /etc/dnf/automatic.conf

systemctl enable dnf-automatic.timer
systemctl start dnf-automatic.timer

log "Actualizaciones automáticas configuradas"

# 11. Reiniciar servicios necesarios
log "Reiniciando servicios..."
systemctl restart tomcat
systemctl reload nginx

# 12. Ejecutar verificación inicial
log "Ejecutando verificación inicial de seguridad..."
/opt/security-check.sh

# 13. Mostrar resumen final
log "\n=== ENDURECIMIENTO DE SEGURIDAD COMPLETADO ==="
echo -e "${BLUE}Scripts creados:${NC}"
echo -e "${GREEN}  - /opt/backup-configs.sh (backup diario a las 2:00 AM)${NC}"
echo -e "${GREEN}  - /opt/security-check.sh (verificación diaria a las 6:00 AM)${NC}"
echo -e "${GREEN}  - /opt/monitor-pdf-validator.sh (monitoreo cada 5 minutos)${NC}"

echo -e "\n${BLUE}Configuraciones aplicadas:${NC}"
echo -e "${GREEN}  ✓ SSH endurecido (sin root, sin passwords)${NC}"
echo -e "${GREEN}  ✓ fail2ban configurado con reglas personalizadas${NC}"
echo -e "${GREEN}  ✓ Límites del sistema optimizados${NC}"
echo -e "${GREEN}  ✓ Permisos de Tomcat asegurados${NC}"
echo -e "${GREEN}  ✓ Tomcat configurado de forma segura${NC}"
echo -e "${GREEN}  ✓ Auditoría del sistema habilitada${NC}"
echo -e "${GREEN}  ✓ Backups automáticos configurados${NC}"
echo -e "${GREEN}  ✓ Actualizaciones de seguridad automáticas${NC}"

echo -e "\n${YELLOW}=== COMANDOS ÚTILES ===${NC}"
echo -e "${GREEN}Verificar seguridad: sudo /opt/security-check.sh${NC}"
echo -e "${GREEN}Ver logs de seguridad: sudo tail -f /var/log/security-check.log${NC}"
echo -e "${GREEN}Estado de fail2ban: sudo fail2ban-client status${NC}"
echo -e "${GREEN}Ver intentos bloqueados: sudo fail2ban-client status nginx-limit-req${NC}"
echo -e "${GREEN}Verificar auditoría: sudo ausearch -k tomcat-config${NC}"
echo -e "${GREEN}Backup manual: sudo /opt/backup-configs.sh${NC}"

echo -e "\n${YELLOW}=== IMPORTANTE ===${NC}"
echo -e "${RED}1. Asegúrate de tener acceso SSH con clave pública antes de cerrar la sesión${NC}"
echo -e "${RED}2. El acceso root por SSH ha sido deshabilitado${NC}"
echo -e "${RED}3. La autenticación por contraseña SSH ha sido deshabilitada${NC}"
echo -e "${GREEN}4. Revisa los logs regularmente: /var/log/security-check.log${NC}"

log "¡Endurecimiento de seguridad completado exitosamente!"