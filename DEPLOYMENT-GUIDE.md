# Guía Rápida de Despliegue - PDF Validator API

## Resumen
Esta guía te permitirá desplegar la API PDF Validator en tu VPS Hostinger (CentOS 9) de forma rápida y segura.

## Requisitos Previos

### En tu VPS Hostinger:
- CentOS 9 instalado
- Acceso root via SSH
- Mínimo 2GB RAM, 10GB espacio libre
- Dominio `validador.usiv.cl` apuntando a la IP del VPS

### Archivos necesarios:
- `pdf-signer-war-1.0.war` (aplicación compilada)
- `deploy-complete.sh` (script principal)
- `install-vps.sh` (instalación base)
- `configure-nginx.sh` (configuración web)
- `security-hardening.sh` (seguridad)
- `test-client.html` (cliente de pruebas)

## Despliegue Automático (Recomendado)

### Paso 1: Copiar archivos al servidor
```bash
# Desde tu máquina local, copiar todos los archivos
scp *.sh pdf-signer-war-1.0.war test-client.html root@TU_IP_VPS:/opt/pdf-validator-deploy/
```

### Paso 2: Ejecutar despliegue automático
```bash
# Conectar al VPS
ssh root@TU_IP_VPS

# Ir al directorio de despliegue
cd /opt/pdf-validator-deploy

# Ejecutar script principal
chmod +x deploy-complete.sh
./deploy-complete.sh
```

### Paso 3: Seguir las instrucciones en pantalla
El script te guiará a través de:
- ✅ Verificación de requisitos
- ✅ Instalación de Java 17 y Tomcat 10
- ✅ Configuración de Nginx con SSL
- ✅ Aplicación de medidas de seguridad
- ✅ Despliegue de la aplicación
- ✅ Configuración de monitoreo automático

## Verificación del Despliegue

### URLs de Acceso:
- **Aplicación Principal:** https://validador.usiv.cl
- **Cliente de Pruebas:** https://validador.usiv.cl/test-client.html
- **API Base:** https://validador.usiv.cl/api

### Credenciales por Defecto:
```
Admin: admin / [generada automáticamente]
User: user / [generada automáticamente]
```
*Las credenciales exactas se guardan en: `/opt/pdf-validator-credentials.txt`*

### Verificar Servicios:
```bash
# Verificar que todos los servicios estén funcionando
sudo systemctl status tomcat nginx fail2ban

# Probar la API
curl -k https://validador.usiv.cl/api/auth/validate
```

## Pruebas Básicas

### 1. Probar Subida de PDF (Público - Sin JWT)
```bash
curl -X POST -F "file=@documento.pdf" https://validador.usiv.cl/api/pdf/upload
```

### 2. Obtener Token JWT
```bash
curl -X POST https://validador.usiv.cl/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"TU_PASSWORD"}'
```

### 3. Listar Archivos (Requiere JWT)
```bash
curl -X GET https://validador.usiv.cl/api/files \
  -H "Authorization: Bearer TU_TOKEN_JWT"
```

## Cambiar Credenciales

### Método 1: Editar archivo de propiedades
```bash
# Editar configuración
sudo nano /opt/tomcat/webapps/ROOT/WEB-INF/classes/application.properties

# Cambiar estas líneas:
api.admin.password=nueva_password_admin
api.user.password=nueva_password_user

# Reiniciar Tomcat
sudo systemctl restart tomcat
```

### Método 2: Variables de entorno
```bash
# Editar archivo de servicio
sudo nano /etc/systemd/system/tomcat.service

# Agregar en la sección [Service]:
Environment="API_ADMIN_PASSWORD=nueva_password_admin"
Environment="API_USER_PASSWORD=nueva_password_user"

# Recargar y reiniciar
sudo systemctl daemon-reload
sudo systemctl restart tomcat
```

## Monitoreo y Mantenimiento

### Scripts de Monitoreo Automático:
- **Verificación de seguridad:** `/opt/security-check.sh` (diario a las 6:00 AM)
- **Monitoreo de servicios:** `/opt/monitor-pdf-validator.sh` (cada 5 minutos)
- **Backup de configuraciones:** `/opt/backup-configs.sh` (diario a las 2:00 AM)

### Comandos Útiles:
```bash
# Ver logs de aplicación
sudo tail -f /opt/tomcat/logs/catalina.out

# Ver logs de Nginx
sudo tail -f /var/log/nginx/validador.usiv.cl.access.log

# Verificar seguridad manualmente
sudo /opt/security-check.sh

# Ver estado de fail2ban
sudo fail2ban-client status

# Reiniciar servicios
sudo systemctl restart tomcat nginx
```

### Ubicaciones Importantes:
- **Aplicación:** `/opt/tomcat/webapps/ROOT/`
- **Almacenamiento PDFs:** `/opt/tomcat/webapps/storage/pdfs/`
- **Logs aplicación:** `/opt/tomcat/logs/`
- **Logs Nginx:** `/var/log/nginx/`
- **Configuraciones:** `/opt/tomcat/conf/`
- **Credenciales:** `/opt/pdf-validator-credentials.txt`

## Solución de Problemas Comunes

### Problema: La aplicación no responde
```bash
# Verificar servicios
sudo systemctl status tomcat nginx

# Reiniciar servicios
sudo systemctl restart tomcat
sudo systemctl restart nginx

# Verificar logs
sudo tail -f /opt/tomcat/logs/catalina.out
```

### Problema: Error de SSL/Certificado
```bash
# Renovar certificado manualmente
sudo certbot renew

# Verificar configuración de Nginx
sudo nginx -t

# Recargar Nginx
sudo systemctl reload nginx
```

### Problema: Espacio en disco lleno
```bash
# Limpiar logs antiguos
sudo find /opt/tomcat/logs -name "*.log" -mtime +30 -delete
sudo find /var/log/nginx -name "*.log" -mtime +30 -delete

# Limpiar PDFs antiguos (opcional)
sudo find /opt/tomcat/webapps/storage/pdfs -name "*.pdf" -mtime +90 -delete
```

### Problema: Acceso denegado a archivos
```bash
# Corregir permisos
sudo chown -R tomcat:tomcat /opt/tomcat/webapps/
sudo chmod -R 755 /opt/tomcat/webapps/storage/
```

## Seguridad

### Configuraciones Aplicadas Automáticamente:
- ✅ SSH endurecido (sin root, sin passwords)
- ✅ fail2ban con reglas personalizadas
- ✅ Firewall configurado (solo HTTP/HTTPS)
- ✅ Tomcat asegurado (manager deshabilitado)
- ✅ Nginx con headers de seguridad
- ✅ SSL/TLS con Let's Encrypt
- ✅ Rate limiting para API
- ✅ Auditoría del sistema
- ✅ Actualizaciones automáticas de seguridad

### Verificar Seguridad:
```bash
# Ejecutar verificación completa
sudo /opt/security-check.sh

# Ver intentos de acceso bloqueados
sudo fail2ban-client status nginx-limit-req

# Verificar logs de auditoría
sudo ausearch -k tomcat-config
```

## Contacto y Soporte

- **Documentación completa:** `README.md`
- **Logs de despliegue:** `/var/log/pdf-validator-deploy.log`
- **Logs de seguridad:** `/var/log/security-check.log`
- **Cliente de pruebas:** https://validador.usiv.cl/test-client.html

---

**¡Importante!** Después del despliegue:
1. Cambia las credenciales por defecto
2. Configura backups externos si es necesario
3. Revisa los logs regularmente
4. Mantén el sistema actualizado

**URL Final:** https://validador.usiv.cl