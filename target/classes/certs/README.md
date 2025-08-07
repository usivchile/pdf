# Certificados para Firma Digital

Este directorio contiene los certificados necesarios para la firma digital de documentos PDF.

## Archivos Requeridos

### 1. Certificado de Firma (signer.p12)

**Ubicación:** `src/main/resources/certs/signer.p12`

**Descripción:** Certificado PKCS#12 utilizado para firmar digitalmente los documentos PDF generados.

**Configuración en application.properties:**
```properties
pdf.signature.keystore-path=certificates/signer.p12
pdf.signature.keystore-password=changeit
pdf.signature.key-alias=usiv-signer
```

### 2. Certificado SSL (keystore.p12) - Solo Producción

**Ubicación:** `certificates/keystore.p12` (fuera del JAR)

**Descripción:** Certificado SSL para HTTPS en producción.

**Configuración en application.properties (perfil prod):**
```properties
server.ssl.key-store=certificates/keystore.p12
server.ssl.key-store-password=${SSL_KEYSTORE_PASSWORD}
server.ssl.key-store-type=PKCS12
server.ssl.key-alias=usiv-ssl
```

## Generación de Certificados

### Certificado de Prueba (Desarrollo)

```bash
# Generar certificado de prueba para desarrollo
keytool -genkeypair \
  -alias usiv-signer \
  -keyalg RSA \
  -keysize 2048 \
  -keystore signer.p12 \
  -storetype PKCS12 \
  -storepass changeit \
  -keypass changeit \
  -dname "CN=USIV Test Signer,OU=IT Department,O=Universidad de Santiago de Chile,L=Santiago,ST=Región Metropolitana,C=CL" \
  -validity 365
```

### Certificado SSL de Prueba

```bash
# Generar certificado SSL de prueba
keytool -genkeypair \
  -alias usiv-ssl \
  -keyalg RSA \
  -keysize 2048 \
  -keystore keystore.p12 \
  -storetype PKCS12 \
  -storepass changeit \
  -keypass changeit \
  -dname "CN=localhost,OU=IT Department,O=Universidad de Santiago de Chile,L=Santiago,ST=Región Metropolitana,C=CL" \
  -ext SAN=dns:localhost,ip:127.0.0.1 \
  -validity 365
```

## Certificados de Producción

### Obtención de Certificado Oficial

Para producción, debe obtener un certificado oficial de una Autoridad Certificadora (CA) reconocida:

1. **Certificado de Firma Digital:**
   - Contactar a una CA chilena (ej: E-Certchile, Acepta)
   - Solicitar certificado de persona jurídica para USIV
   - Formato: PKCS#12 (.p12)

2. **Certificado SSL:**
   - Obtener certificado SSL para el dominio (ej: pdf.usiv.cl)
   - Puede usar Let's Encrypt para certificados gratuitos
   - Formato: PKCS#12 (.p12)

### Conversión de Formatos

```bash
# Convertir de PEM a PKCS#12
openssl pkcs12 -export \
  -in certificate.crt \
  -inkey private.key \
  -out certificate.p12 \
  -name "usiv-signer" \
  -passout pass:changeit

# Convertir de JKS a PKCS#12
keytool -importkeystore \
  -srckeystore keystore.jks \
  -destkeystore keystore.p12 \
  -deststoretype PKCS12 \
  -srcalias mykey \
  -destalias usiv-signer
```

## Verificación de Certificados

### Listar contenido del certificado

```bash
# Ver información del certificado
keytool -list -v -keystore signer.p12 -storetype PKCS12

# Ver detalles específicos
openssl pkcs12 -in signer.p12 -info -noout
```

### Validar certificado

```bash
# Verificar validez del certificado
keytool -list -keystore signer.p12 -storetype PKCS12 -alias usiv-signer

# Verificar cadena de certificación
openssl verify -CAfile ca-bundle.crt certificate.crt
```

## Configuración de Seguridad

### Variables de Entorno

```bash
# Configurar contraseñas como variables de entorno
export KEYSTORE_PASSWORD="contraseña-segura"
export SSL_KEYSTORE_PASSWORD="contraseña-ssl-segura"
```

### Permisos de Archivos

```bash
# Configurar permisos restrictivos
chmod 600 *.p12
chown app:app *.p12
```

## Renovación de Certificados

### Proceso de Renovación

1. **Monitoreo de Expiración:**
   - Configurar alertas 30 días antes del vencimiento
   - Verificar fechas regularmente

2. **Renovación:**
   - Obtener nuevo certificado de la CA
   - Actualizar archivo .p12
   - Reiniciar aplicación

3. **Validación:**
   - Verificar que la firma funciona correctamente
   - Probar descarga de PDFs
   - Validar en diferentes navegadores

### Script de Verificación

```bash
#!/bin/bash
# check-certificates.sh

CERT_FILE="signer.p12"
DAYS_WARNING=30

if [ -f "$CERT_FILE" ]; then
    EXPIRY_DATE=$(keytool -list -keystore "$CERT_FILE" -storetype PKCS12 -storepass changeit | grep "Valid until" | cut -d: -f2-)
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
    
    if [ $DAYS_LEFT -lt $DAYS_WARNING ]; then
        echo "WARNING: Certificate expires in $DAYS_LEFT days!"
        exit 1
    else
        echo "Certificate is valid for $DAYS_LEFT more days"
    fi
else
    echo "ERROR: Certificate file not found: $CERT_FILE"
    exit 1
fi
```

## Troubleshooting

### Problemas Comunes

1. **Error: "Keystore was tampered with, or password was incorrect"**
   - Verificar contraseña del keystore
   - Verificar integridad del archivo .p12

2. **Error: "Alias not found"**
   - Listar aliases disponibles: `keytool -list -keystore signer.p12`
   - Verificar configuración del alias en application.properties

3. **Error: "Certificate chain not found"**
   - Verificar que el certificado incluye la cadena completa
   - Importar certificados intermedios si es necesario

### Logs de Depuración

```properties
# Habilitar logs de SSL/TLS
logging.level.javax.net.ssl=DEBUG
logging.level.org.springframework.security=DEBUG
```

## Contacto

Para problemas relacionados con certificados:
- **IT Support:** it-support@usiv.cl
- **Security Team:** security@usiv.cl
- **Development Team:** dev@usiv.cl

---

**IMPORTANTE:** 
- Nunca commitear certificados reales al repositorio
- Usar variables de entorno para contraseñas
- Mantener backups seguros de los certificados
- Renovar certificados antes del vencimiento