#!/bin/bash

# Instalación Simplificada para Producción - PDF Signer
# Elimina todo lo existente e instala desde repositorios oficiales
# Autor: Sistema de Despliegue PDF Signer

set -e  # Salir si hay errores

echo "═══════════════════════════════════════════════════════════════════"
echo "           INSTALACIÓN SIMPLIFICADA PARA PRODUCCIÓN"
echo "              PDF Signer - Repositorios Oficiales"
echo "═══════════════════════════════════════════════════════════════════"
echo

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script debe ejecutarse como root (sudo)"
   exit 1
fi

echo "🧹 PASO 1: LIMPIEZA COMPLETA DEL SISTEMA"
echo "═══════════════════════════════════════════════════════════════════"

# Detener servicios si existen
echo "⏹️  Deteniendo servicios existentes..."
systemctl stop tomcat 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl disable tomcat 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

# Eliminar instalaciones manuales
echo "🗑️  Eliminando instalaciones manuales..."
rm -rf /opt/tomcat* 2>/dev/null || true
rm -f /etc/systemd/system/tomcat.service 2>/dev/null || true

# Desinstalar paquetes existentes
echo "📦 Desinstalando paquetes existentes..."
if command -v dnf &> /dev/null; then
    dnf remove -y tomcat* nginx* java-*-openjdk* maven 2>/dev/null || true
else
    yum remove -y tomcat* nginx* java-*-openjdk* maven 2>/dev/null || true
fi

# Limpiar archivos de configuración
rm -rf /etc/tomcat* /etc/nginx /var/lib/tomcat* /usr/share/tomcat* 2>/dev/null || true

# Recargar systemd
systemctl daemon-reload

echo "✅ Limpieza completa terminada"
echo

echo "📦 PASO 2: INSTALACIÓN DESDE REPOSITORIOS OFICIALES"
echo "═══════════════════════════════════════════════════════════════════"

# Detectar sistema operativo
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "❌ No se puede detectar el sistema operativo"
    exit 1
fi

echo "🖥️  Sistema detectado: $PRETTY_NAME"

# Instalar EPEL si es necesario
echo "📋 Instalando EPEL..."
if command -v dnf &> /dev/null; then
    dnf install -y epel-release
    dnf update -y
else
    yum install -y epel-release
    yum update -y
fi

# Instalar Java
echo "☕ Instalando Java 11..."
if command -v dnf &> /dev/null; then
    dnf install -y java-11-openjdk java-11-openjdk-devel
else
    yum install -y java-11-openjdk java-11-openjdk-devel
fi

# Configurar JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" >> /etc/environment

# Instalar Maven
echo "🔨 Instalando Maven..."
if command -v dnf &> /dev/null; then
    dnf install -y maven
else
    yum install -y maven
fi

# Instalar Tomcat
echo "🐱 Instalando Tomcat desde repositorios..."
if command -v dnf &> /dev/null; then
    dnf install -y tomcat tomcat-webapps tomcat-admin-webapps
else
    yum install -y tomcat tomcat-webapps tomcat-admin-webapps
fi

# Instalar Nginx
echo "🌐 Instalando Nginx..."
if command -v dnf &> /dev/null; then
    dnf install -y nginx
else
    yum install -y nginx
fi

echo "✅ Instalación de paquetes completada"
echo

echo "⚙️  PASO 3: CONFIGURACIÓN DEL SISTEMA"
echo "═══════════════════════════════════════════════════════════════════"

# Configurar Tomcat
echo "🔧 Configurando Tomcat..."

# Configurar memoria JVM para Tomcat
cat > /etc/tomcat/tomcat.conf << 'EOF'
# Configuración de memoria para PDF Signer
JAVA_OPTS="-Djava.awt.headless=true -Xmx1024m -Xms512m -XX:+UseG1GC"
CATALINA_OPTS="-Dfile.encoding=UTF-8 -Duser.timezone=America/Santiago"
EOF

# Configurar Nginx como proxy reverso
echo "🌐 Configurando Nginx..."
cat > /etc/nginx/conf.d/pdf-signer.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Configuración para PDF Signer
    location /pdf-signer/ {
        proxy_pass http://localhost:8080/pdf-signer/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Configuración para archivos grandes
        client_max_body_size 50M;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Página de inicio redirige a la aplicación
    location = / {
        return 301 /pdf-signer/;
    }
    
    # Configuración de logs
    access_log /var/log/nginx/pdf-signer.access.log;
    error_log /var/log/nginx/pdf-signer.error.log;
}
EOF

# Verificar configuración de Nginx
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Error en configuración de Nginx"
    exit 1
fi

echo "✅ Configuración completada"
echo

echo "🔥 PASO 4: CONFIGURACIÓN DEL FIREWALL"
echo "═══════════════════════════════════════════════════════════════════"

# Configurar firewall
echo "🛡️  Configurando firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --reload
    echo "✅ Firewall configurado"
else
    echo "⚠️  Firewalld no está activo, configurar manualmente si es necesario"
fi

echo

echo "🚀 PASO 5: INICIAR SERVICIOS"
echo "═══════════════════════════════════════════════════════════════════"

# Habilitar e iniciar servicios
echo "▶️  Iniciando servicios..."
systemctl enable tomcat
systemctl enable nginx
systemctl start tomcat
systemctl start nginx

# Esperar a que Tomcat inicie
echo "⏳ Esperando a que Tomcat inicie completamente..."
sleep 10

# Verificar servicios
echo "🔍 Verificando servicios..."
if systemctl is-active --quiet tomcat; then
    echo "✅ Tomcat está ejecutándose"
else
    echo "❌ Tomcat no está ejecutándose"
    systemctl status tomcat
    exit 1
fi

if systemctl is-active --quiet nginx; then
    echo "✅ Nginx está ejecutándose"
else
    echo "❌ Nginx no está ejecutándose"
    systemctl status nginx
    exit 1
fi

echo

echo "📁 PASO 6: COMPILAR Y DESPLEGAR APLICACIÓN"
echo "═══════════════════════════════════════════════════════════════════"

# Buscar el directorio del proyecto
PROJECT_DIR=$(pwd)
if [ ! -f "$PROJECT_DIR/pom.xml" ]; then
    echo "❌ No se encuentra pom.xml en el directorio actual"
    echo "📍 Directorio actual: $PROJECT_DIR"
    echo "💡 Ejecuta este script desde el directorio del proyecto"
    exit 1
fi

echo "📂 Directorio del proyecto: $PROJECT_DIR"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
mvn clean

# Compilar aplicación
echo "🔨 Compilando aplicación..."
mvn package -DskipTests

if [ $? -ne 0 ]; then
    echo "❌ Error en la compilación"
    exit 1
fi

# Buscar el archivo WAR
WAR_FILE=$(find target -name "*.war" | head -1)
if [ -z "$WAR_FILE" ]; then
    echo "❌ No se encontró archivo WAR en target/"
    ls -la target/
    exit 1
fi

echo "📦 Archivo WAR encontrado: $WAR_FILE"

# Detener Tomcat para despliegue
echo "⏹️  Deteniendo Tomcat para despliegue..."
systemctl stop tomcat

# Limpiar webapps anteriores
echo "🗑️  Limpiando despliegues anteriores..."
rm -rf /var/lib/tomcat/webapps/pdf-signer*

# Copiar WAR
echo "📋 Desplegando aplicación..."
cp "$WAR_FILE" /var/lib/tomcat/webapps/pdf-signer.war
chown tomcat:tomcat /var/lib/tomcat/webapps/pdf-signer.war

# Iniciar Tomcat
echo "▶️  Iniciando Tomcat..."
systemctl start tomcat

# Esperar despliegue
echo "⏳ Esperando despliegue de la aplicación..."
sleep 15

echo "✅ Despliegue completado"
echo

echo "🔍 PASO 7: VERIFICACIÓN FINAL"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar despliegue
echo "📋 Verificando despliegue..."
if [ -d "/var/lib/tomcat/webapps/pdf-signer" ]; then
    echo "✅ Aplicación desplegada correctamente"
else
    echo "❌ La aplicación no se desplegó"
    echo "📁 Contenido de webapps:"
    ls -la /var/lib/tomcat/webapps/
    echo "📋 Logs de Tomcat:"
    tail -20 /var/log/tomcat/catalina.out
    exit 1
fi

# Verificar conectividad
echo "🌐 Verificando conectividad..."

# Probar Tomcat directo
echo "🔗 Probando Tomcat (puerto 8080)..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/pdf-signer/ | grep -q "200\|302\|404"; then
    echo "✅ Tomcat responde correctamente"
else
    echo "❌ Tomcat no responde"
    echo "📋 Estado del servicio:"
    systemctl status tomcat
fi

# Probar Nginx
echo "🔗 Probando Nginx (puerto 80)..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/pdf-signer/ | grep -q "200\|302\|404"; then
    echo "✅ Nginx responde correctamente"
else
    echo "❌ Nginx no responde"
    echo "📋 Estado del servicio:"
    systemctl status nginx
fi

# Verificar puertos
echo "🔌 Verificando puertos..."
ss -tlnp | grep :80 && echo "✅ Puerto 80 (Nginx) abierto" || echo "❌ Puerto 80 no disponible"
ss -tlnp | grep :8080 && echo "✅ Puerto 8080 (Tomcat) abierto" || echo "❌ Puerto 8080 no disponible"

echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    🎉 INSTALACIÓN COMPLETADA"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "📍 ACCESO A LA APLICACIÓN:"
echo "   🌐 Nginx (recomendado): http://$(hostname -I | awk '{print $1}')/pdf-signer/"
echo "   🐱 Tomcat directo:      http://$(hostname -I | awk '{print $1}'):8080/pdf-signer/"
echo
echo "🔧 SERVICIOS INSTALADOS:"
echo "   ✅ Java 11 OpenJDK"
echo "   ✅ Apache Tomcat (desde repositorios)"
echo "   ✅ Nginx (proxy reverso)"
echo "   ✅ Maven"
echo "   ✅ PDF Signer desplegado"
echo
echo "📋 COMANDOS ÚTILES:"
echo "   sudo systemctl status tomcat nginx    # Ver estado"
echo "   sudo systemctl restart tomcat nginx  # Reiniciar"
echo "   sudo journalctl -u tomcat -f         # Logs Tomcat"
echo "   sudo journalctl -u nginx -f          # Logs Nginx"
echo
echo "🔄 ACTUALIZACIONES:"
echo "   sudo yum update    # o sudo dnf update"
echo "   (Los paquetes se actualizarán automáticamente)"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                        ¡LISTO PARA USAR!"
echo "═══════════════════════════════════════════════════════════════════"