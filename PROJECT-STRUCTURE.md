# Estructura del Proyecto PDF Validator API

## Archivos del Proyecto Limpio

Este documento describe la estructura final del proyecto después de la limpieza y preparación para despliegue en VPS.

## 📁 Estructura de Directorios

```
pdf/
├── src/                                    # Código fuente de la aplicación
│   └── main/
│       ├── java/
│       │   └── cl/usiv/pdf/
│       │       ├── config/                 # Configuraciones Spring
│       │       ├── controller/             # Controladores REST
│       │       ├── dto/                    # Data Transfer Objects
│       │       ├── exception/              # Manejo de excepciones
│       │       ├── security/               # Configuración de seguridad
│       │       ├── service/                # Lógica de negocio
│       │       └── MainApp.java           # Clase principal
│       └── resources/
│           └── application.properties      # Configuración de la aplicación
├── target/                                 # Archivos compilados
│   └── pdf-signer-war-1.0.war            # WAR file para despliegue
├── pom.xml                                # Configuración Maven
├── README.md                              # Documentación principal
├── DEPLOYMENT-GUIDE.md                    # Guía rápida de despliegue
├── PROJECT-STRUCTURE.md                   # Este archivo
├── test-client.html                       # Cliente de pruebas web
├── deploy-complete.sh                     # Script principal de despliegue
├── install-vps.sh                         # Script de instalación base
├── configure-nginx.sh                     # Script de configuración Nginx
└── security-hardening.sh                  # Script de endurecimiento de seguridad
```

## 📄 Descripción de Archivos

### Código Fuente Java

#### Configuración (`src/main/java/cl/usiv/pdf/config/`)
- **`CorsConfig.java`** - Configuración CORS para permitir acceso desde dominios específicos
- **`SecurityConfig.java`** - Configuración de seguridad Spring (JWT, endpoints públicos)
- **`SwaggerConfig.java`** - Configuración de documentación API con Swagger
- **`WebConfig.java`** - Configuración web general

#### Controladores (`src/main/java/cl/usiv/pdf/controller/`)
- **`AuthController.java`** - Autenticación y manejo de tokens JWT
- **`DownloadController.java`** - Descarga pública de archivos PDF
- **`FileManagementController.java`** - Gestión de archivos (listar, estadísticas, limpieza)
- **`PdfController.java`** - Subida y procesamiento de PDFs

#### DTOs (`src/main/java/cl/usiv/pdf/dto/`)
- **`FileInfoDto.java`** - Información de archivos
- **`FileStatsDto.java`** - Estadísticas de archivos
- **`PdfGenerationResponse.java`** - Respuesta de generación de PDF
- **`PdfUploadRequest.java`** - Request de subida de PDF

#### Excepciones (`src/main/java/cl/usiv/pdf/exception/`)
- **`GlobalExceptionHandler.java`** - Manejo global de excepciones
- **`PdfProcessingException.java`** - Excepción específica para procesamiento PDF

#### Seguridad (`src/main/java/cl/usiv/pdf/security/`)
- **`JwtAuthenticationEntryPoint.java`** - Punto de entrada para autenticación JWT
- **`JwtAuthenticationFilter.java`** - Filtro de autenticación JWT
- **`JwtTokenProvider.java`** - Proveedor y validador de tokens JWT

#### Servicios (`src/main/java/cl/usiv/pdf/service/`)
- **`FileManagementService.java`** - Gestión de archivos del sistema
- **`PdfService.java`** - Procesamiento y validación de PDFs
- **`QrCodeService.java`** - Generación de códigos QR

#### Principal
- **`MainApp.java`** - Clase principal de la aplicación Spring Boot

### Configuración
- **`application.properties`** - Configuración de la aplicación (base de datos, JWT, CORS, almacenamiento)
- **`pom.xml`** - Dependencias Maven y configuración de build

### Documentación
- **`README.md`** - Documentación completa del proyecto
- **`DEPLOYMENT-GUIDE.md`** - Guía rápida de despliegue
- **`PROJECT-STRUCTURE.md`** - Este archivo con la estructura del proyecto

### Cliente de Pruebas
- **`test-client.html`** - Cliente web para probar la API (HTML + JavaScript)

### Scripts de Despliegue
- **`deploy-complete.sh`** - Script principal que ejecuta todo el proceso de despliegue
- **`install-vps.sh`** - Instalación de Java 17, Tomcat 10, configuraciones base
- **`configure-nginx.sh`** - Configuración de Nginx como proxy reverso con SSL
- **`security-hardening.sh`** - Endurecimiento de seguridad del sistema

### Archivos Compilados
- **`target/pdf-signer-war-1.0.war`** - Archivo WAR listo para despliegue en Tomcat

## 🚀 Flujo de Despliegue

### 1. Preparación Local
```bash
# Compilar el proyecto
mvn clean package -DskipTests

# Verificar que se generó el WAR
ls -la target/pdf-signer-war-1.0.war
```

### 2. Transferencia al Servidor
```bash
# Copiar archivos necesarios
scp *.sh target/pdf-signer-war-1.0.war test-client.html root@servidor:/opt/pdf-validator-deploy/
```

### 3. Despliegue Automático
```bash
# En el servidor
cd /opt/pdf-validator-deploy
chmod +x deploy-complete.sh
./deploy-complete.sh
```

## 🔧 Configuraciones Importantes

### Variables de Entorno Soportadas
```bash
# Configuración de base de datos
SPRING_DATASOURCE_URL
SPRING_DATASOURCE_USERNAME
SPRING_DATASOURCE_PASSWORD

# Configuración JWT
JWT_SECRET
JWT_EXPIRATION

# Credenciales API
API_ADMIN_USERNAME
API_ADMIN_PASSWORD
API_USER_USERNAME
API_USER_PASSWORD

# Configuración de almacenamiento
FILE_STORAGE_BASE_PATH
FILE_DOWNLOAD_BASE_URL

# Configuración CORS
CORS_ALLOWED_ORIGINS
```

### Endpoints de la API

#### Públicos (Sin JWT)
- `POST /api/pdf/upload` - Subir PDF para validación
- `GET /api/download/{token}` - Descargar PDF procesado
- `GET /public/download/{filename}` - Descarga pública directa

#### Protegidos (Requieren JWT)
- `POST /api/auth/login` - Obtener token JWT
- `GET /api/auth/validate` - Validar token JWT
- `GET /api/files` - Listar archivos
- `GET /api/files/stats` - Estadísticas de archivos
- `DELETE /api/files/cleanup` - Limpiar archivos antiguos

## 📊 Características de Seguridad

### Implementadas en el Código
- ✅ Autenticación JWT
- ✅ Configuración CORS restrictiva
- ✅ Validación de tipos de archivo
- ✅ Sanitización de nombres de archivo
- ✅ Manejo seguro de excepciones
- ✅ Headers de seguridad

### Implementadas en el Despliegue
- ✅ SSH endurecido
- ✅ fail2ban con reglas personalizadas
- ✅ Firewall configurado
- ✅ SSL/TLS con Let's Encrypt
- ✅ Nginx con headers de seguridad
- ✅ Rate limiting
- ✅ Auditoría del sistema
- ✅ Actualizaciones automáticas

## 🔍 Monitoreo y Logs

### Logs de Aplicación
- `/opt/tomcat/logs/catalina.out` - Log principal de Tomcat
- `/opt/tomcat/logs/localhost.log` - Log específico de la aplicación

### Logs del Sistema
- `/var/log/nginx/validador.usiv.cl.access.log` - Accesos web
- `/var/log/nginx/validador.usiv.cl.error.log` - Errores web
- `/var/log/security-check.log` - Verificaciones de seguridad
- `/var/log/pdf-validator-deploy.log` - Log de despliegue

### Scripts de Monitoreo
- `/opt/monitor-pdf-validator.sh` - Monitoreo cada 5 minutos
- `/opt/security-check.sh` - Verificación diaria de seguridad
- `/opt/backup-configs.sh` - Backup diario de configuraciones

## 📝 Notas Importantes

1. **Archivos Eliminados**: Se removieron todos los archivos relacionados con Docker, CI/CD y scripts innecesarios
2. **Configuración de Producción**: `application.properties` está configurado para producción
3. **Seguridad**: El proyecto incluye múltiples capas de seguridad tanto a nivel de aplicación como de sistema
4. **Monitoreo**: Se incluyen scripts automáticos para monitoreo y mantenimiento
5. **Backups**: Configuración automática de backups de configuraciones importantes
6. **SSL**: Configuración automática de certificados SSL con Let's Encrypt
7. **Dominio**: Configurado específicamente para `validador.usiv.cl`

## 🎯 Próximos Pasos Después del Despliegue

1. Verificar que el dominio apunte correctamente al servidor
2. Probar todos los endpoints de la API
3. Cambiar las credenciales por defecto
4. Configurar monitoreo adicional si es necesario
5. Revisar logs regularmente
6. Mantener el sistema actualizado

---

**Proyecto listo para despliegue en producción** ✅