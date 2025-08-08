# 🔒 CONFIGURACIÓN SSL CON LET'S ENCRYPT

## 📋 Configuración SSL para PDF Signer en VPS (validador.usiv.cl)

Este documento proporciona instrucciones completas para configurar SSL/HTTPS en tu VPS usando Let's Encrypt.

### Requisitos Previos

- VPS con Linux (CentOS/RHEL/Rocky Linux recomendado)
- Dominio `validador.usiv.cl` apuntando a tu VPS
- Puertos 80 y 443 abiertos en el firewall
- Nginx y Tomcat instalados y funcionando
- Acceso root al VPS
- Git configurado en el VPS

## 🚀 FLUJO COMPLETO DE DESPLIEGUE

### 1. Desde tu máquina local

```bash
# Hacer commit de tus cambios
git add .
git commit -m "Preparando despliegue con SSL"

# Subir cambios al repositorio
git push origin main
```

### 2. En tu VPS

```bash
# Conectarse al VPS
ssh root@validador.usiv.cl

# Ejecutar el script de despliegue completo
sudo ./deploy-to-vps.sh
```

**¡Eso es todo!** El script `deploy-to-vps.sh` se encarga de:
- Hacer `git pull` para obtener los últimos cambios
- Limpiar archivos de desarrollo
- Compilar la aplicación
- Desplegar en Tomcat
- Configurar SSL automáticamente
- Configurar Nginx con HTTPS
- Verificar que todo funcione

### 3. Verificación

Después del despliegue, verifica que todo funcione:

```bash
# En el VPS, ejecutar verificación
sudo ./check-ssl-status.sh
```

**URLs de acceso:**
- Aplicación: https://validador.usiv.cl/pdf-signer/
- Health Check: https://validador.usiv.cl/pdf-signer/api/health
- Swagger UI: https://validador.usiv.cl/pdf-signer/swagger-ui/

### 🎯 **¿Por qué configurar SSL?**

- ✅ **Evita problemas de firewall corporativo** (HTTPS suele estar permitido)
- ✅ **Seguridad mejorada** (datos encriptados)
- ✅ **Confianza del usuario** (certificado válido)
- ✅ **SEO mejorado** (Google favorece HTTPS)
- ✅ **Funcionalidades modernas** (muchas APIs requieren HTTPS)

---

## 🚀 **OPCIÓN 1: Configuración Automática (Recomendada)**

### Paso 1: Subir el script a tu VPS

```bash
# En tu máquina local, actualizar repositorio
git add .
git commit -m "Agregar configuración SSL automática"
git push origin main

# En tu VPS, actualizar código
cd /ruta/a/tu/proyecto
git pull origin main
```

### Paso 2: Ejecutar configuración SSL

```bash
# Hacer ejecutable el script
chmod +x setup-ssl-letsencrypt.sh

# Para DOMINIO (certificado Let's Encrypt gratuito)
sudo ./setup-ssl-letsencrypt.sh validador.usiv.cl usiv@usiv.cl

# Para IP (certificado autofirmado)
sudo ./setup-ssl-letsencrypt.sh 168.231.91.217
```

### ✅ **¡Listo!** Tu aplicación estará disponible en:
- 🔒 **HTTPS:** https://tu-dominio/pdf-signer/
- 📚 **Swagger:** https://tu-dominio/pdf-signer/swagger-ui/index.html

---

## 🛠️ **OPCIÓN 2: Configuración Manual**

### Paso 1: Instalar Certbot

```bash
# CentOS/RHEL/Rocky Linux
sudo dnf install -y epel-release
sudo dnf install -y certbot python3-certbot-nginx

# Ubuntu/Debian
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### Paso 2: Obtener Certificado SSL

```bash
# Para dominio (reemplaza con tu dominio)
sudo certbot --nginx -d tu-dominio.com --email tu-email@dominio.com --agree-tos --non-interactive --redirect

# Verificar certificado
sudo certbot certificates
```

### Paso 3: Configurar Renovación Automática

```bash
# Crear script de renovación
sudo tee /etc/cron.daily/certbot-renew << 'EOF'
#!/bin/bash
certbot renew --quiet
if [ $? -eq 0 ]; then
    systemctl reload nginx
fi
EOF

# Hacer ejecutable
sudo chmod +x /etc/cron.daily/certbot-renew

# Probar renovación
sudo certbot renew --dry-run
```

---

## 🔧 **CONFIGURACIÓN PARA IP (Sin Dominio)**

Si solo tienes una IP y no un dominio, puedes usar un certificado autofirmado:

```bash
# Crear certificado autofirmado
sudo mkdir -p /etc/ssl/private /etc/ssl/certs
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/pdf-signer.key \
    -out /etc/ssl/certs/pdf-signer.crt \
    -subj "/C=CL/ST=Santiago/L=Santiago/O=USIV/OU=IT/CN=168.231.91.217"
```

Luego configurar Nginx:

```bash
sudo tee /etc/nginx/conf.d/pdf-signer.conf << 'EOF'
server {
    listen 80;
    server_name 168.231.91.217;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name 168.231.91.217;
    
    ssl_certificate /etc/ssl/certs/pdf-signer.crt;
    ssl_certificate_key /etc/ssl/private/pdf-signer.key;
    
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        client_max_body_size 50M;
    }
    
    location = / {
        return 301 /pdf-signer/;
    }
}
EOF

# Verificar y recargar
sudo nginx -t && sudo systemctl reload nginx
```

---

## 🔍 **VERIFICACIÓN Y TROUBLESHOOTING**

### Verificar que SSL funciona:

```bash
# Probar HTTPS
curl -k -I https://tu-dominio/pdf-signer/

# Verificar redirección HTTP → HTTPS
curl -I http://tu-dominio/

# Ver certificados instalados
sudo certbot certificates

# Verificar configuración Nginx
sudo nginx -t

# Ver logs
sudo tail -f /var/log/nginx/error.log
```

### Problemas Comunes:

#### ❌ **Error: "Connection refused"**
```bash
# Verificar que Nginx esté ejecutándose
sudo systemctl status nginx
sudo systemctl start nginx

# Verificar firewall
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

#### ❌ **Error: "Certificate not found"**
```bash
# Verificar que el dominio apunte al servidor
nslookup tu-dominio.com

# Verificar que los puertos estén abiertos
sudo ss -tlnp | grep :443

# Intentar obtener certificado manualmente
sudo certbot certonly --webroot -w /var/www/html -d tu-dominio.com
```

#### ❌ **Error: "SSL handshake failed"**
```bash
# Verificar configuración SSL
sudo openssl s_client -connect tu-dominio.com:443 -servername tu-dominio.com

# Verificar permisos de certificados
sudo ls -la /etc/letsencrypt/live/tu-dominio.com/
```

---

## 📱 **ACTUALIZAR APLICACIÓN PARA HTTPS**

### 1. Actualizar archivo de pruebas

Abre `test-internet-access.html` y:
- Cambia todas las URLs de `http://` a `https://`
- Usa el selector de protocolo para alternar entre HTTP/HTTPS

### 2. Actualizar configuración de aplicación

En `application.properties`:
```properties
# Para producción con HTTPS
server.use-forward-headers=true
server.forward-headers-strategy=native
```

### 3. Actualizar enlaces en documentación

Cambia todos los enlaces en:
- README.md
- Documentación de API
- Enlaces compartidos

---

## 🎉 **RESULTADO FINAL**

Después de configurar SSL correctamente:

### ✅ **URLs Disponibles:**
- 🔒 **Aplicación:** https://tu-dominio/pdf-signer/
- 📚 **Swagger UI:** https://tu-dominio/pdf-signer/swagger-ui/index.html
- ❤️ **Health Check:** https://tu-dominio/pdf-signer/api/health
- 📥 **Descargas:** https://tu-dominio/pdf-signer/download/

### ✅ **Características Habilitadas:**
- 🔄 Redirección automática HTTP → HTTPS
- 🛡️ Headers de seguridad (HSTS, XSS Protection, etc.)
- 🚦 Rate limiting para API
- 🔒 Cifrado TLS 1.2+ moderno
- 🔄 Renovación automática de certificados (Let's Encrypt)

### ✅ **Beneficios Obtenidos:**
- 🚫 **Evita bloqueos de firewall corporativo**
- 🔐 **Datos encriptados en tránsito**
- ✅ **Certificado confiable (sin advertencias)**
- 🚀 **Mejor rendimiento (HTTP/2)**
- 📈 **SEO mejorado**

---

## 📞 **SOPORTE**

Si tienes problemas:

1. **Ejecuta el script de diagnóstico:**
   ```bash
   ./check-deployment.sh
   ```

2. **Revisa los logs:**
   ```bash
   sudo tail -f /var/log/nginx/error.log
   sudo journalctl -u nginx -f
   ```

3. **Verifica la configuración:**
   ```bash
   sudo nginx -t
   sudo certbot certificates
   ```

4. **Contacta soporte** con la salida de los comandos anteriores.

---

## 🔄 **MANTENIMIENTO**

### Renovación de Certificados:
- ✅ **Automática:** Los certificados se renuevan automáticamente cada 60 días
- 🔍 **Manual:** `sudo certbot renew`
- 📅 **Verificar:** `sudo certbot certificates`

### Actualizaciones de Seguridad:
```bash
# Actualizar sistema
sudo dnf update  # o sudo apt update && sudo apt upgrade

# Actualizar certbot
sudo dnf update certbot  # o sudo apt update certbot
```

### Monitoreo:
```bash
# Verificar estado SSL
echo | openssl s_client -servername tu-dominio.com -connect tu-dominio.com:443 2>/dev/null | openssl x509 -noout -dates

# Verificar redirección
curl -I http://tu-dominio.com/
```

---

**🎯 ¡Con SSL configurado, tu aplicación será más segura y accesible desde cualquier red!**