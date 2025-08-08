# 🚀 Guía de Despliegue a Producción - USIV PDF Service

## 📋 Resumen

Esta guía te llevará paso a paso desde el commit local hasta tener la aplicación funcionando en tu VPS de producción.

## 🔧 Prerrequisitos

### En tu máquina local:
- Git configurado
- Maven 3.6+
- Java 11+
- Acceso SSH al VPS

### En el VPS:
- Tomcat 9+ instalado y configurado
- Java 11+ instalado
- Usuario con permisos sudo
- Directorios base creados

## 📁 Estructura de Directorios en el VPS

```
/opt/usiv/
├── storage/
│   ├── pdfs/          # PDFs generados
│   └── temp/          # Archivos temporales
├── certs/             # Certificados de firma
├── logs/              # Logs de la aplicación
└── backups/           # Backups de WAR anteriores

/opt/tomcat/webapps/   # Directorio de despliegue de Tomcat
```

## 🚀 Proceso de Despliegue Completo

### Paso 1: Preparar el Código Local

```bash
# 1. Asegúrate de estar en la rama correcta
git status
git branch

# 2. Agregar todos los cambios
git add .

# 3. Hacer commit con mensaje descriptivo
git commit -m "feat: configuración de producción y limpieza de archivos"

# 4. Subir cambios al repositorio
git push origin main
```

### Paso 2: Opción A - Despliegue Automático (Recomendado)

```bash
# Hacer el script ejecutable
chmod +x deploy-to-production.sh

# Ejecutar despliegue completo
./deploy-to-production.sh

# O ejecutar solo construcción
./deploy-to-production.sh --build-only

# O ejecutar solo despliegue (si ya tienes el WAR)
./deploy-to-production.sh --deploy-only
```

### Paso 2: Opción B - Despliegue Manual

#### 2.1 Construir el WAR localmente

```bash
# Limpiar proyecto anterior
mvn clean

# Construir WAR para producción
mvn package -Pprod -DskipTests

# Verificar que se generó el WAR
ls -la target/pdf-signer-war-1.0.war
```

#### 2.2 Preparar el VPS

```bash
# Conectar al VPS
ssh root@validador.usiv.cl

# Crear directorios necesarios
sudo mkdir -p /opt/usiv/{storage/{pdfs,temp},certs,logs,backups}

# Establecer permisos
sudo chown -R tomcat:tomcat /opt/usiv

# Crear backup del WAR actual (si existe)
if [ -f /opt/tomcat/webapps/pdf-signer.war ]; then
    sudo cp /opt/tomcat/webapps/pdf-signer.war /opt/usiv/backups/pdf-signer-$(date +%Y%m%d_%H%M%S).war
fi

# Detener Tomcat
sudo systemctl stop tomcat

# Limpiar despliegue anterior
sudo rm -rf /opt/tomcat/webapps/pdf-signer /opt/tomcat/webapps/pdf-signer.war
```

#### 2.3 Desplegar el WAR

```bash
# Desde tu máquina local, copiar el WAR al VPS
scp target/pdf-signer-war-1.0.war root@validador.usiv.cl:/opt/tomcat/webapps/pdf-signer.war

# En el VPS, establecer permisos
sudo chown tomcat:tomcat /opt/tomcat/webapps/pdf-signer.war

# Iniciar Tomcat
sudo systemctl start tomcat

# Verificar estado
sudo systemctl status tomcat
```

### Paso 3: Verificación del Despliegue

#### 3.1 Verificar logs

```bash
# En el VPS, monitorear logs de Tomcat
sudo tail -f /opt/tomcat/logs/catalina.out

# Verificar logs de la aplicación
sudo tail -f /opt/usiv/logs/usiv-pdf-service.log
```

#### 3.2 Verificar endpoints

```bash
# Health check
curl https://validador.usiv.cl/pdf-signer/actuator/health

# Info endpoint
curl https://validador.usiv.cl/pdf-signer/actuator/info

# Página principal (debería devolver HTML)
curl -I https://validador.usiv.cl/pdf-signer/
```

#### 3.3 Verificar en el navegador

- **URL Principal**: https://validador.usiv.cl/pdf-signer/
- **Health Check**: https://validador.usiv.cl/pdf-signer/actuator/health
- **API Info**: https://validador.usiv.cl/pdf-signer/actuator/info

## 🔧 Variables de Entorno (Opcional)

Puedes configurar variables de entorno en el VPS para personalizar la configuración:

```bash
# En /opt/tomcat/bin/setenv.sh
export API_ADMIN_USERNAME="admin"
export API_ADMIN_PASSWORD="TuPasswordSeguro123!"
export JWT_SECRET="tu-clave-jwt-muy-segura-para-produccion"
export PDF_STORAGE_PATH="/opt/usiv/storage/pdfs"
export CERT_PATH="/opt/usiv/certs"
export LOG_PATH="/opt/usiv/logs"
```

## 🐛 Solución de Problemas

### Problema: Tomcat no inicia

```bash
# Verificar logs de Tomcat
sudo journalctl -u tomcat -f

# Verificar configuración de Java
java -version
echo $JAVA_HOME
```

### Problema: Aplicación no responde

```bash
# Verificar que el WAR se desplegó
ls -la /opt/tomcat/webapps/

# Verificar logs de la aplicación
sudo tail -100 /opt/usiv/logs/usiv-pdf-service.log

# Verificar puertos
sudo netstat -tlnp | grep :8080
```

### Problema: Errores de permisos

```bash
# Corregir permisos
sudo chown -R tomcat:tomcat /opt/usiv /opt/tomcat/webapps/pdf-signer.war
sudo chmod -R 755 /opt/usiv
```

## 🔄 Rollback (Volver a Versión Anterior)

```bash
# En el VPS
sudo systemctl stop tomcat

# Restaurar backup anterior
sudo cp /opt/usiv/backups/pdf-signer-YYYYMMDD_HHMMSS.war /opt/tomcat/webapps/pdf-signer.war

# Establecer permisos
sudo chown tomcat:tomcat /opt/tomcat/webapps/pdf-signer.war

# Iniciar Tomcat
sudo systemctl start tomcat
```

## 📝 Checklist de Despliegue

- [ ] Código commiteado y pusheado
- [ ] WAR construido exitosamente
- [ ] Backup del WAR anterior creado
- [ ] Tomcat detenido
- [ ] WAR anterior eliminado
- [ ] Nuevo WAR copiado
- [ ] Permisos establecidos
- [ ] Tomcat iniciado
- [ ] Health check exitoso
- [ ] Funcionalidad verificada

## 🎯 URLs Importantes

- **Aplicación**: https://validador.usiv.cl/pdf-signer/
- **Health**: https://validador.usiv.cl/pdf-signer/actuator/health
- **Info**: https://validador.usiv.cl/pdf-signer/actuator/info

---

**¡Listo!** Tu aplicación USIV PDF Service está ahora desplegada en producción. 🎉