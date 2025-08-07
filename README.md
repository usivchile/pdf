# PDF Validator API - Guía de Instalación y Configuración

## Descripción
API REST para validación y firma digital de documentos PDF con generación de códigos QR y gestión de archivos.

## Características
- ✅ Subida de archivos PDF (pública, sin autenticación)
- ✅ Validación y firma digital de PDFs
- ✅ Generación de códigos QR con información de validación
- ✅ API REST segura con autenticación JWT
- ✅ Gestión de archivos y limpieza automática
- ✅ Descarga pública de archivos
- ✅ Documentación Swagger integrada

## Requisitos del Sistema

### VPS Hostinger (CentOS 9)
- Java 17 o superior
- Apache Tomcat 10.x
- Certificado SSL configurado
- Dominio: `validador.usiv.cl`

## Instalación en VPS Hostinger

### 1. Preparación del Sistema

```bash
# Actualizar el sistema
sudo dnf update -y

# Instalar Java 17
sudo dnf install java-17-openjdk java-17-openjdk-devel -y

# Verificar instalación de Java
java -version
```

### 2. Instalación de Tomcat 10

```bash
# Crear usuario para Tomcat
sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat

# Descargar Tomcat 10
cd /tmp
wget https://downloads.apache.org/tomcat/tomcat-10/v10.1.15/bin/apache-tomcat-10.1.15.tar.gz

# Extraer Tomcat
sudo tar -xf apache-tomcat-10.1.15.tar.gz -C /opt/tomcat --strip-components=1

# Configurar permisos
sudo chown -R tomcat: /opt/tomcat
sudo sh -c 'chmod +x /opt/tomcat/bin/*.sh'
```

### 3. Configuración de Tomcat como Servicio

Crear archivo de servicio:
```bash
sudo nano /etc/systemd/system/tomcat.service
```

Contenido del archivo:
```ini
[Unit]
Description=Apache Tomcat Web Application Container
Wants=network.target
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Recargar systemd y habilitar Tomcat
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat
sudo systemctl status tomcat
```

### 4. Configuración de Seguridad de Tomcat

#### Configurar usuarios administrativos
```bash
sudo nano /opt/tomcat/conf/tomcat-users.xml
```

Agregar antes de `</tomcat-users>`:
```xml
<role rolename="manager-gui"/>
<role rolename="manager-script"/>
<role rolename="admin-gui"/>
<user username="admin" password="TU_PASSWORD_SEGURO" roles="manager-gui,manager-script,admin-gui"/>
```

#### Configurar acceso al Manager
```bash
# Permitir acceso desde cualquier IP (solo para configuración inicial)
sudo nano /opt/tomcat/webapps/manager/META-INF/context.xml
```

Comentar la línea del Valve:
```xml
<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
```

#### Configurar HTTPS en Tomcat
```bash
sudo nano /opt/tomcat/conf/server.xml
```

Agregar conector HTTPS (ajustar rutas del certificado):
```xml
<Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
           maxThreads="150" SSLEnabled="true">
    <SSLHostConfig>
        <Certificate certificateKeystoreFile="/path/to/your/keystore.jks"
                     certificateKeystorePassword="your_keystore_password"
                     type="RSA" />
    </SSLHostConfig>
</Connector>
```

### 5. Configuración del Firewall

```bash
# Abrir puertos necesarios
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --reload
```

### 6. Despliegue de la Aplicación

#### Crear directorios necesarios
```bash
sudo mkdir -p /opt/tomcat/webapps/storage/pdfs
sudo mkdir -p /opt/tomcat/webapps/storage/temp
sudo chown -R tomcat:tomcat /opt/tomcat/webapps/storage
```

#### Copiar el archivo WAR
```bash
# Copiar el WAR generado al directorio webapps
sudo cp pdf-signer-war-1.0.war /opt/tomcat/webapps/ROOT.war
sudo chown tomcat:tomcat /opt/tomcat/webapps/ROOT.war

# Reiniciar Tomcat
sudo systemctl restart tomcat
```

## Configuración de la Aplicación

### Variables de Entorno (Opcional)
Puedes sobrescribir la configuración usando variables de entorno:

```bash
sudo nano /etc/systemd/system/tomcat.service
```

Agregar en la sección `[Service]`:
```ini
Environment="API_ADMIN_USERNAME=tu_admin_usuario"
Environment="API_ADMIN_PASSWORD=tu_admin_password_seguro"
Environment="API_USER_USERNAME=tu_user_usuario"
Environment="API_USER_PASSWORD=tu_user_password_seguro"
Environment="JWT_SECRET=tu_jwt_secret_muy_largo_y_seguro_de_al_menos_64_caracteres"
```

### Configuración de Proxy Reverso (Nginx)

Si usas Nginx como proxy reverso:

```nginx
server {
    listen 80;
    server_name validador.usiv.cl;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name validador.usiv.cl;

    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    client_max_body_size 50M;
}
```

## Uso de la API

### Endpoints Principales

#### 1. Autenticación (Requiere JWT)
```bash
# Login
curl -X POST https://validador.usiv.cl/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Validar token
curl -X GET https://validador.usiv.cl/api/auth/validate \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### 2. Subida de PDF (Público - No requiere JWT)
```bash
curl -X POST https://validador.usiv.cl/api/pdf/upload \
  -F "file=@documento.pdf" \
  -F "signerName=Juan Pérez" \
  -F "signerRut=12345678-9"
```

#### 3. Gestión de Archivos (Requiere JWT)
```bash
# Listar archivos
curl -X GET https://validador.usiv.cl/api/pdf/files \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Estadísticas
curl -X GET https://validador.usiv.cl/api/pdf/stats \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Limpieza manual
curl -X POST https://validador.usiv.cl/api/pdf/cleanup \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### 4. Descarga de Archivos (Público)
```bash
# Descargar archivo
curl -X GET https://validador.usiv.cl/api/download/nombre_archivo.pdf \
  -o archivo_descargado.pdf
```

### Documentación Swagger
Accede a la documentación interactiva en:
- **URL:** https://validador.usiv.cl/swagger-ui/index.html

## Cliente de Pruebas

Se incluye un cliente HTML (`test-client.html`) para probar todas las funcionalidades:

1. Abrir `test-client.html` en un navegador
2. Configurar la URL de la API: `https://validador.usiv.cl/api`
3. Probar autenticación, subida de archivos, gestión y descarga

## Cambio de Credenciales

### Método 1: Variables de Entorno (Recomendado)
```bash
sudo systemctl edit tomcat
```

Agregar:
```ini
[Service]
Environment="API_ADMIN_USERNAME=nuevo_admin"
Environment="API_ADMIN_PASSWORD=nueva_password_segura"
Environment="API_USER_USERNAME=nuevo_user"
Environment="API_USER_PASSWORD=nueva_user_password"
Environment="JWT_SECRET=nuevo_jwt_secret_muy_largo_y_seguro"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart tomcat
```

### Método 2: Modificar application.properties
```bash
sudo nano /opt/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
```

Cambiar:
```properties
api.admin.username=nuevo_admin
api.admin.password=nueva_password_segura
api.user.username=nuevo_user
api.user.password=nueva_user_password
jwt.secret=nuevo_jwt_secret_muy_largo_y_seguro
```

```bash
sudo systemctl restart tomcat
```

## Seguridad y Hardening

### 1. Seguridad de Tomcat

#### Ocultar información del servidor
```bash
sudo nano /opt/tomcat/conf/server.xml
```

Modificar el conector:
```xml
<Connector port="8080" protocol="HTTP/1.1"
           connectionTimeout="20000"
           redirectPort="8443"
           server="Apache" />
```

#### Deshabilitar aplicaciones innecesarias
```bash
sudo rm -rf /opt/tomcat/webapps/examples
sudo rm -rf /opt/tomcat/webapps/docs
sudo rm -rf /opt/tomcat/webapps/ROOT
```

#### Configurar límites de recursos
```bash
sudo nano /opt/tomcat/conf/web.xml
```

Agregar antes de `</web-app>`:
```xml
<security-constraint>
    <web-resource-collection>
        <web-resource-name>Protected Context</web-resource-name>
        <url-pattern>/manager/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
        <role-name>manager-gui</role-name>
    </auth-constraint>
</security-constraint>
```

### 2. Seguridad del Sistema

#### Configurar fail2ban
```bash
sudo dnf install epel-release -y
sudo dnf install fail2ban -y

# Configurar jail para Tomcat
sudo nano /etc/fail2ban/jail.local
```

Contenido:
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[tomcat-auth]
enabled = true
port = 8080,8443
filter = tomcat-auth
logpath = /opt/tomcat/logs/catalina.out
maxretry = 3
bantime = 3600
```

#### Configurar actualizaciones automáticas
```bash
sudo dnf install dnf-automatic -y
sudo systemctl enable --now dnf-automatic.timer
```

### 3. Monitoreo y Logs

#### Configurar rotación de logs
```bash
sudo nano /etc/logrotate.d/tomcat
```

Contenido:
```
/opt/tomcat/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 tomcat tomcat
    postrotate
        systemctl reload tomcat
    endscript
}
```

## Mantenimiento

### Comandos Útiles

```bash
# Ver logs de Tomcat
sudo tail -f /opt/tomcat/logs/catalina.out

# Ver logs de la aplicación
sudo tail -f /opt/tomcat/logs/localhost.*.log

# Reiniciar Tomcat
sudo systemctl restart tomcat

# Ver estado de Tomcat
sudo systemctl status tomcat

# Ver uso de espacio en disco
df -h
du -sh /opt/tomcat/webapps/storage/*
```

### Backup

```bash
# Script de backup
#!/bin/bash
BACKUP_DIR="/backup/pdf-validator"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup de archivos
tar -czf $BACKUP_DIR/storage_$DATE.tar.gz /opt/tomcat/webapps/storage/

# Backup de configuración
cp /opt/tomcat/webapps/ROOT/WEB-INF/classes/application.properties $BACKUP_DIR/config_$DATE.properties

# Limpiar backups antiguos (más de 30 días)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
```

## Solución de Problemas

### Problemas Comunes

1. **Error 404 al acceder a la aplicación**
   - Verificar que el WAR se desplegó correctamente
   - Revisar logs: `sudo tail -f /opt/tomcat/logs/catalina.out`

2. **Error de permisos en archivos**
   ```bash
   sudo chown -R tomcat:tomcat /opt/tomcat/webapps/storage
   sudo chmod -R 755 /opt/tomcat/webapps/storage
   ```

3. **Problemas de memoria**
   - Aumentar memoria en `/etc/systemd/system/tomcat.service`
   - Cambiar `-Xmx1024M` por `-Xmx2048M`

4. **Problemas de SSL**
   - Verificar certificados
   - Revisar configuración de Nginx/Apache

### Logs Importantes

- **Tomcat:** `/opt/tomcat/logs/catalina.out`
- **Aplicación:** `/opt/tomcat/logs/localhost.*.log`
- **Sistema:** `/var/log/messages`
- **Nginx:** `/var/log/nginx/error.log`

## Scripts de Instalación y Configuración

Se incluyen varios scripts automatizados para facilitar el despliegue:

### Scripts Principales
- `deploy-complete.sh`: **Script principal** - Ejecuta todo el proceso de despliegue automáticamente
- `install-vps.sh`: Instalación base de Java 17, Tomcat 10 y configuraciones iniciales
- `configure-nginx.sh`: Configuración de Nginx como proxy reverso con SSL
- `security-hardening.sh`: Endurecimiento de seguridad del sistema y aplicación

### Uso Recomendado

**Opción 1: Despliegue Automático Completo (Recomendado)**
```bash
# Copiar todos los archivos al servidor
scp *.sh pdf-signer-war-1.0.war root@tu-servidor:/opt/pdf-validator-deploy/
scp test-client.html root@tu-servidor:/opt/pdf-validator-deploy/

# Conectar al servidor y ejecutar
ssh root@tu-servidor
cd /opt/pdf-validator-deploy
chmod +x deploy-complete.sh
./deploy-complete.sh
```

**Opción 2: Despliegue Manual por Pasos**
```bash
# 1. Instalación base
chmod +x install-vps.sh
./install-vps.sh

# 2. Configurar Nginx
chmod +x configure-nginx.sh
./configure-nginx.sh

# 3. Aplicar seguridad
chmod +x security-hardening.sh
./security-hardening.sh
```

## Contacto y Soporte

Para soporte técnico o consultas:
- **Dominio:** validador.usiv.cl
- **Documentación API:** https://validador.usiv.cl/swagger-ui/index.html

---

**Nota:** Recuerda cambiar todas las contraseñas por defecto y mantener el sistema actualizado regularmente.