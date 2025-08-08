# Despliegue Exitoso de PDF Signer

## Resumen
La aplicación PDF Signer ha sido desplegada exitosamente en el servidor de producción `168.231.91.217` (validador.usiv.cl).

## Configuración Final

### Aplicación
- **Tipo**: Spring Boot standalone (WAR ejecutable)
- **Puerto**: 8080
- **Contexto**: `/usiv-pdf-api`
- **Perfil**: `prod`
- **Archivo**: `/tmp/pdf-signer-boot-fixed.war`

### Servicio Systemd
- **Nombre**: `pdf-signer.service`
- **Estado**: Habilitado y ejecutándose
- **Inicio automático**: Sí
- **Logs**: `journalctl -u pdf-signer`

### Nginx Proxy
- **Configuración**: `/etc/nginx/conf.d/pdf-signer.conf`
- **SSL**: Let's Encrypt (validador.usiv.cl)
- **Rutas disponibles**:
  - `https://validador.usiv.cl/pdf-signer/` → `http://localhost:8080/usiv-pdf-api/`
  - `https://validador.usiv.cl/usiv-pdf-api/` → `http://localhost:8080/usiv-pdf-api/`

## URLs de Verificación

### Health Check
- Local: `http://localhost:8080/usiv-pdf-api/actuator/health`
- Público: `https://validador.usiv.cl/pdf-signer/actuator/health`
- Público: `https://validador.usiv.cl/usiv-pdf-api/actuator/health`

### API Principal
- `https://validador.usiv.cl/pdf-signer/api/sign`
- `https://validador.usiv.cl/usiv-pdf-api/api/sign`

## Comandos de Gestión

### Servicio
```bash
# Verificar estado
sudo systemctl status pdf-signer

# Reiniciar servicio
sudo systemctl restart pdf-signer

# Ver logs
sudo journalctl -u pdf-signer -f

# Detener servicio
sudo systemctl stop pdf-signer
```

### Nginx
```bash
# Verificar configuración
sudo nginx -t

# Recargar configuración
sudo systemctl reload nginx

# Reiniciar nginx
sudo systemctl restart nginx
```

## Configuración de Producción

### Propiedades Principales
- `server.servlet.context-path=/usiv-pdf-api`
- `spring.profiles.active=prod`
- `pdf.signature.p12-path=/tmp/certificado.p12`
- `pdf.signature.password=password123`
- `pdf.storage.download-url=https://validador.usiv.cl/pdf-signer/api/download`

## Estado Actual
✅ **FUNCIONANDO CORRECTAMENTE**

- Aplicación iniciada y respondiendo
- Health checks exitosos en ambas rutas
- SSL configurado correctamente
- Servicio systemd habilitado
- Nginx proxy funcionando

## Fecha de Despliegue
8 de Agosto de 2025