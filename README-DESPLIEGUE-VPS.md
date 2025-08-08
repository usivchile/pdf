# 🚀 DESPLIEGUE EN VPS - PDF Signer

## Configuración SSL para validador.usiv.cl

Este documento describe el proceso completo para desplegar PDF Signer en tu VPS con SSL configurado automáticamente.

## 📋 ARCHIVOS CREADOS PARA EL DESPLIEGUE

### Scripts de Despliegue
- **`deploy-to-vps.sh`** - Script principal de despliegue completo
- **`setup-ssl-letsencrypt.sh`** - Configuración automática de SSL con Let's Encrypt
- **`cleanup-dev-files.sh`** - Limpieza de archivos de desarrollo
- **`check-ssl-status.sh`** - Verificación del estado SSL (Linux)
- **`ssl-check.ps1`** - Verificación del estado SSL (Windows)

### Documentación
- **`INSTRUCCIONES-SSL.md`** - Guía completa de configuración SSL
- **`README-DESPLIEGUE-VPS.md`** - Este archivo

### Archivos de Prueba (se eliminan en producción)
- **`test-internet-access.html`** - Página de prueba de conectividad
- **`test-client.html`** - Cliente de prueba de la API

## 🎯 PROCESO DE DESPLIEGUE SIMPLIFICADO

### 1. Preparación Local

```bash
# En tu máquina local
git add .
git commit -m "Preparando despliegue con SSL para validador.usiv.cl"
git push origin main
```

### 2. Despliegue en VPS

```bash
# Conectarse al VPS
ssh root@validador.usiv.cl

# Ir al directorio del proyecto
cd /ruta/a/tu/proyecto

# Actualizar código manualmente
git pull origin main

# Ejecutar el script de despliegue
sudo ./deploy-to-vps.sh
```

**El script se encarga del resto automáticamente.**

## 🔧 QUÉ HACE EL SCRIPT DE DESPLIEGUE

1. **Verificación**: Confirma que el código esté actualizado
2. **Limpieza**: Elimina archivos de desarrollo
3. **Compilación**: `mvn clean package`
4. **Despliegue**: Copia WAR a Tomcat
5. **SSL**: Configura Let's Encrypt automáticamente
6. **Nginx**: Configura proxy reverso con HTTPS
7. **Firewall**: Abre puertos necesarios
8. **Verificación**: Prueba todas las URLs

## 🌐 URLS DE ACCESO DESPUÉS DEL DESPLIEGUE

- **Aplicación Principal**: https://validador.usiv.cl/pdf-signer/
- **Health Check**: https://validador.usiv.cl/pdf-signer/api/health
- **Swagger UI**: https://validador.usiv.cl/pdf-signer/swagger-ui/
- **Tomcat Directo**: http://validador.usiv.cl:8080/pdf-signer/

## 🔍 VERIFICACIÓN Y DIAGNÓSTICO

### En el VPS (Linux)
```bash
# Verificar estado SSL
sudo ./check-ssl-status.sh

# Ver logs en tiempo real
sudo journalctl -u tomcat -f
sudo journalctl -u nginx -f

# Estado de servicios
sudo systemctl status tomcat
sudo systemctl status nginx

# Verificar certificados
sudo certbot certificates
```

### Desde Windows (tu máquina)
```powershell
# Ejecutar diagnóstico desde tu máquina
.\ssl-check.ps1
```

## 🛠️ COMANDOS ÚTILES

### Gestión de Servicios
```bash
# Reiniciar servicios
sudo systemctl restart tomcat
sudo systemctl restart nginx

# Ver estado
sudo systemctl status tomcat nginx

# Habilitar inicio automático
sudo systemctl enable tomcat nginx
```

### Gestión de SSL
```bash
# Renovar certificados manualmente
sudo certbot renew

# Probar renovación
sudo certbot renew --dry-run

# Ver certificados instalados
sudo certbot certificates
```

### Logs y Diagnóstico
```bash
# Logs de Tomcat
sudo tail -f /var/log/tomcat/catalina.out
sudo journalctl -u tomcat --no-pager -n 50

# Logs de Nginx
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Logs de SSL
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## 🔒 CONFIGURACIÓN DE SEGURIDAD

El despliegue incluye automáticamente:

- **SSL/TLS**: Certificados Let's Encrypt con renovación automática
- **HTTPS Redirect**: Todo el tráfico HTTP se redirige a HTTPS
- **Security Headers**: HSTS, X-Frame-Options, etc.
- **Rate Limiting**: Protección contra ataques DDoS
- **Firewall**: Solo puertos necesarios abiertos

## 🚨 SOLUCIÓN DE PROBLEMAS

### Problema: SSL no funciona
```bash
# Verificar configuración
sudo nginx -t
sudo ./check-ssl-status.sh

# Reconfigurar SSL
sudo ./setup-ssl-letsencrypt.sh validador.usiv.cl
```

### Problema: Aplicación no responde
```bash
# Verificar Tomcat
sudo systemctl status tomcat
sudo journalctl -u tomcat --no-pager -n 20

# Redesplegar aplicación
sudo systemctl stop tomcat
sudo rm -rf /var/lib/tomcat/webapps/pdf-signer*
sudo cp target/pdf-signer-war-1.0.war /var/lib/tomcat/webapps/pdf-signer.war
sudo systemctl start tomcat
```

### Problema: Nginx no funciona
```bash
# Verificar configuración
sudo nginx -t
sudo systemctl status nginx

# Reiniciar Nginx
sudo systemctl restart nginx
```

## 📁 ESTRUCTURA DEL PROYECTO EN VPS

```
/opt/pdf-signer/
├── src/                          # Código fuente
├── target/                       # Archivos compilados
├── pom.xml                       # Configuración Maven
├── deploy-to-vps.sh             # Script de despliegue
├── setup-ssl-letsencrypt.sh     # Configuración SSL
├── check-ssl-status.sh          # Verificación SSL
└── cleanup-dev-files.sh         # Limpieza de desarrollo
```

## 🎉 BENEFICIOS DEL DESPLIEGUE AUTOMATIZADO

- **Simplicidad**: Un solo comando para todo el despliegue
- **Consistencia**: Mismo proceso cada vez
- **Seguridad**: SSL configurado automáticamente
- **Limpieza**: Archivos de desarrollo eliminados automáticamente
- **Verificación**: Pruebas automáticas de funcionamiento
- **Documentación**: Logs detallados de cada paso

## 📞 SOPORTE

Si tienes problemas:

1. Ejecuta `sudo ./check-ssl-status.sh` para diagnóstico
2. Revisa los logs con `sudo journalctl -u tomcat -f`
3. Verifica la configuración de Nginx con `sudo nginx -t`
4. Consulta este README para comandos útiles

---

**¡Tu aplicación PDF Signer estará disponible en https://validador.usiv.cl/pdf-signer/ después del despliegue!**