# Automatización de Despliegue - PDF Signer

## 🚀 Scripts de Despliegue Automatizado

Este proyecto incluye scripts automatizados para facilitar el despliegue en producción.

### 📁 Estructura de Scripts

```
├── cleanup-production.sh    # Limpieza del servidor
├── deploy-production.sh     # Despliegue de la aplicación
└── deploy-master.sh         # Script maestro (ejecuta todo)
```

## 🔧 Configuración Inicial

### En el Servidor de Producción

1. **Clonar el repositorio** (solo la primera vez):
   ```bash
   mkdir -p /opt/pdf-signer
   cd /opt/pdf-signer
   git clone <URL_DEL_REPOSITORIO> pdf
   cd pdf
   ```

2. **Otorgar permisos a los scripts**:
   ```bash
   chmod +x *.sh
   ```

## 🚀 Uso de los Scripts

### Opción 1: Script Maestro (Recomendado)

```bash
cd /opt/pdf-signer/pdf
sudo ./deploy-master.sh
```

Este script ejecuta automáticamente:
1. ✅ Limpieza del servidor
2. ✅ Git pull
3. ✅ Configuración de permisos
4. ✅ Compilación con Maven
5. ✅ Despliegue del WAR
6. ✅ Verificaciones finales

### Opción 2: Scripts Individuales

#### 1. Limpiar el servidor
```bash
sudo ./cleanup-production.sh
```

#### 2. Actualizar código y desplegar
```bash
git pull
sudo ./deploy-production.sh
```

## 📋 Proceso de Despliegue Detallado

### 1. Limpieza (`cleanup-production.sh`)
- Detiene y deshabilita Tomcat
- Elimina archivos temporales antiguos
- Limpia logs antiguos
- Verifica estructura de directorios
- Limpia archivos de compilación
- Verifica servicios necesarios

### 2. Despliegue (`deploy-production.sh`)
- Actualiza código con `git pull`
- Otorga permisos a scripts .sh
- Limpia compilaciones anteriores
- Compila con `mvn package -DskipTests`
- Detiene servicio actual
- Hace backup del WAR anterior
- Despliega nuevo WAR
- Inicia servicio
- Verifica health checks

### 3. Script Maestro (`deploy-master.sh`)
- Ejecuta todo el proceso de manera interactiva
- Incluye verificaciones de seguridad
- Muestra información detallada del progreso
- Realiza verificaciones finales

## 🔍 Verificaciones Automáticas

Los scripts incluyen verificaciones automáticas:

- ✅ **Servicio activo**: `systemctl is-active pdf-signer`
- ✅ **Health check local**: `http://localhost:8080/usiv-pdf-api/actuator/health`
- ✅ **Acceso público**: `https://validador.usiv.cl/pdf-signer/actuator/health`
- ✅ **Nginx funcionando**: `systemctl is-active nginx`

## 📊 Información del Sistema

### URLs de Acceso
- **Health Check**: `https://validador.usiv.cl/pdf-signer/actuator/health`
- **API Principal**: `https://validador.usiv.cl/pdf-signer/api/sign`
- **Documentación**: `https://validador.usiv.cl/pdf-signer/swagger-ui.html`

### Comandos Útiles
```bash
# Ver logs en tiempo real
journalctl -u pdf-signer -f

# Estado del servicio
systemctl status pdf-signer

# Reiniciar servicio
systemctl restart pdf-signer

# Verificar configuración de Nginx
nginx -t

# Recargar Nginx
systemctl reload nginx
```

### Archivos Importantes
- **Proyecto**: `/opt/pdf-signer/pdf`
- **WAR actual**: `/tmp/pdf-signer-boot-fixed.war`
- **Servicio**: `/etc/systemd/system/pdf-signer.service`
- **Nginx config**: `/etc/nginx/conf.d/pdf-signer.conf`
- **SSL certs**: `/etc/letsencrypt/live/validador.usiv.cl/`

## 🚨 Solución de Problemas

### Si el despliegue falla:

1. **Verificar logs**:
   ```bash
   journalctl -u pdf-signer --no-pager -n 50
   ```

2. **Verificar estado de Git**:
   ```bash
   cd /opt/pdf-signer/pdf
   git status
   git log -1 --oneline
   ```

3. **Verificar compilación**:
   ```bash
   mvn clean package -DskipTests
   ```

4. **Reiniciar servicios**:
   ```bash
   systemctl restart pdf-signer
   systemctl restart nginx
   ```

### Si hay cambios locales no confirmados:

El script maestro detectará cambios locales y preguntará si deseas descartarlos.

```bash
# Descartar cambios manualmente
git reset --hard HEAD
git clean -fd
```

## 🔐 Seguridad

- Los scripts requieren permisos de root
- Se realizan backups automáticos del WAR anterior
- Se verifican los cambios locales antes de hacer git pull
- Se incluyen verificaciones de integridad

## 📅 Mantenimiento

### Limpieza Periódica
Ejecuta el script de limpieza semanalmente:
```bash
sudo ./cleanup-production.sh
```

### Actualización de Scripts
Cuando actualices los scripts de despliegue:
```bash
cd /opt/pdf-signer/pdf
git pull
chmod +x *.sh
```

---

**Nota**: Siempre ejecuta los scripts desde el directorio `/opt/pdf-signer/pdf` y con permisos de root.