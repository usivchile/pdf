# 📋 Instrucciones de Despliegue - WAR Corregido

## 🚨 Problema Resuelto

El script original `deploy-fixed-war.sh` estaba diseñado para ejecutarse desde tu **máquina local** y hacer SSH al VPS. Por eso te pedía credenciales cuando lo ejecutabas **dentro del VPS**.

## 🛠️ Nuevos Scripts Disponibles

### 1. `deploy-local-vps.sh` ✅ **RECOMENDADO PARA VPS**
**Úsalo cuando estés DENTRO del VPS**
- ✅ No requiere SSH
- ✅ Ejecuta todo localmente en el VPS
- ✅ No pide credenciales
- ✅ Más rápido y directo

### 2. `deploy-smart.sh` 🧠 **SCRIPT INTELIGENTE**
**Detecta automáticamente dónde estás ejecutándolo**
- 🔍 Detecta si estás en VPS o máquina local
- 🏠 Si estás en VPS: ejecuta localmente (sin SSH)
- 💻 Si estás en local: usa SSH al VPS
- 🎯 Un solo script para ambos casos

### 3. `deploy-fixed-war.sh` 💻 **PARA MÁQUINA LOCAL**
**Úsalo desde tu máquina Windows/local**
- 🌐 Hace SSH al VPS
- 📤 Sube el WAR y lo despliega
- 🔑 Requiere credenciales SSH

## 🚀 Cómo Usar (Estás en el VPS)

### Opción A: Script Específico para VPS
```bash
# En el VPS
cd /root/pdf

# Hacer ejecutable
chmod +x deploy-local-vps.sh

# Ejecutar
./deploy-local-vps.sh
```

### Opción B: Script Inteligente
```bash
# En el VPS
cd /root/pdf

# Hacer ejecutable
chmod +x deploy-smart.sh

# Ejecutar (detectará que estás en VPS)
./deploy-smart.sh
```

## 📋 Prerrequisitos

Antes de ejecutar cualquier script, asegúrate de:

### 1. Tener el código actualizado
```bash
# Si tienes problemas con git pull, usa:
./fix-git-pull.sh

# O manualmente:
git pull origin main
```

### 2. Compilar el proyecto
```bash
# Compilar con las correcciones
mvn clean package -DskipTests
```

### 3. Verificar que el WAR tiene web.xml
```bash
# Verificar contenido del WAR
unzip -l target/pdf-signer-war-1.0.war | grep web.xml
```

## 🔍 Verificaciones que Hacen los Scripts

### ✅ Verificaciones Previas
- Existencia del archivo WAR
- Presencia de web.xml en el WAR
- Tamaño del archivo WAR

### 🔧 Proceso de Despliegue
1. **Detener Tomcat** - Para evitar conflictos
2. **Limpiar despliegue anterior** - Elimina archivos viejos
3. **Copiar nuevo WAR** - Con permisos correctos
4. **Iniciar Tomcat** - Reinicia el servicio
5. **Esperar despliegue** - 15 segundos para que se despliegue

### 🧪 Verificaciones Post-Despliegue
- ✅ Directorio de aplicación creado
- ✅ web.xml presente en el despliegue
- ✅ Estado de servicios (Tomcat y Nginx)
- ✅ Logs de Tomcat
- ✅ Pruebas de conectividad:
  - Puerto 8080 (Tomcat directo)
  - Puerto 80 (Nginx HTTP)
  - Puerto 443 (Nginx HTTPS)

## 🌐 URLs para Probar

Después del despliegue exitoso:

```
https://validador.usiv.cl/pdf-signer/
https://validador.usiv.cl/pdf-signer/api/health
https://validador.usiv.cl/pdf-signer/swagger-ui/
```

## 🐛 Solución de Problemas

### Si el script falla:

1. **Verificar logs de Tomcat:**
```bash
tail -f /var/lib/tomcat/logs/catalina.out
```

2. **Verificar estado de servicios:**
```bash
systemctl status tomcat
systemctl status nginx
```

3. **Verificar puertos:**
```bash
netstat -tlnp | grep -E ':(80|443|8080)'
```

4. **Reiniciar servicios si es necesario:**
```bash
sudo systemctl restart tomcat
sudo systemctl restart nginx
```

### Si web.xml no está presente:

1. **Verificar que se creó correctamente:**
```bash
ls -la src/main/webapp/WEB-INF/web.xml
```

2. **Recompilar:**
```bash
mvn clean package -DskipTests
```

3. **Verificar en el WAR:**
```bash
unzip -l target/pdf-signer-war-1.0.war | grep web.xml
```

## 📊 Diferencias entre Scripts

| Script | Ubicación de Ejecución | SSH Requerido | Detección Automática |
|--------|----------------------|---------------|---------------------|
| `deploy-fixed-war.sh` | Máquina Local | ✅ Sí | ❌ No |
| `deploy-local-vps.sh` | VPS | ❌ No | ❌ No |
| `deploy-smart.sh` | Cualquiera | 🔄 Automático | ✅ Sí |

## 💡 Recomendación

**Para tu caso (ejecutando en el VPS):**
- Usa `deploy-local-vps.sh` o `deploy-smart.sh`
- Ambos funcionarán sin pedir credenciales
- `deploy-smart.sh` es más versátil para el futuro

¡El problema de las credenciales está resuelto! 🎉