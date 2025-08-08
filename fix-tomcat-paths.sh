#!/bin/bash

# Script para corregir las rutas de Tomcat instalado desde repositorios
# El problema es que CATALINA_HOME y CATALINA_BASE están vacías

echo "═══════════════════════════════════════════════════════════════════"
echo "              CORRECCIÓN DE RUTAS DE TOMCAT"
echo "═══════════════════════════════════════════════════════════════════"
echo

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script debe ejecutarse como root (sudo)"
   exit 1
fi

echo "🔍 Detectando instalación de Tomcat..."

# Buscar directorios de Tomcat
TOMCAT_HOME=""
TOMCAT_BASE=""

# Ubicaciones típicas en instalaciones desde repositorios
if [ -d "/usr/share/tomcat" ]; then
    TOMCAT_HOME="/usr/share/tomcat"
    echo "✅ CATALINA_HOME encontrado: $TOMCAT_HOME"
else
    echo "❌ No se encontró /usr/share/tomcat"
fi

if [ -d "/var/lib/tomcat" ]; then
    TOMCAT_BASE="/var/lib/tomcat"
    echo "✅ CATALINA_BASE encontrado: $TOMCAT_BASE"
else
    echo "❌ No se encontró /var/lib/tomcat"
fi

# Verificar archivos críticos
echo
echo "🔍 Verificando archivos críticos..."

if [ -f "$TOMCAT_HOME/bin/bootstrap.jar" ]; then
    echo "✅ bootstrap.jar encontrado en $TOMCAT_HOME/bin/"
else
    echo "❌ bootstrap.jar NO encontrado"
    echo "📁 Contenido de $TOMCAT_HOME:"
    ls -la "$TOMCAT_HOME" 2>/dev/null || echo "Directorio no existe"
fi

if [ -f "$TOMCAT_HOME/bin/tomcat-juli.jar" ]; then
    echo "✅ tomcat-juli.jar encontrado"
else
    echo "❌ tomcat-juli.jar NO encontrado"
fi

echo
echo "🔧 Corrigiendo configuración de Tomcat..."

# Crear/corregir archivo de configuración
cat > /etc/tomcat/tomcat.conf << EOF
# Configuración corregida para Tomcat desde repositorios
# Rutas específicas para instalación desde paquetes

# Directorios principales
CATALINA_HOME="/usr/share/tomcat"
CATALINA_BASE="/var/lib/tomcat"
CATALINA_TMPDIR="/var/cache/tomcat/temp"

# Configuración de Java
JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
JAVA_OPTS="-Djava.awt.headless=true -Xmx1024m -Xms512m -XX:+UseG1GC"
CATALINA_OPTS="-Dfile.encoding=UTF-8 -Duser.timezone=America/Santiago"

# Usuario y grupo
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"

# Configuración de logs
CATALINA_OUT="/var/log/tomcat/catalina.out"
EOF

echo "✅ Archivo /etc/tomcat/tomcat.conf actualizado"

# Verificar y crear directorios necesarios
echo
echo "📁 Verificando directorios necesarios..."

directories=(
    "/var/lib/tomcat"
    "/var/lib/tomcat/webapps"
    "/var/cache/tomcat"
    "/var/cache/tomcat/temp"
    "/var/log/tomcat"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "✅ Creado: $dir"
    else
        echo "✅ Existe: $dir"
    fi
done

# Configurar permisos
echo
echo "🔒 Configurando permisos..."
chown -R tomcat:tomcat /var/lib/tomcat
chown -R tomcat:tomcat /var/cache/tomcat
chown -R tomcat:tomcat /var/log/tomcat
chmod -R 755 /var/lib/tomcat
chmod -R 755 /var/cache/tomcat

echo "✅ Permisos configurados"

# Verificar instalación de paquetes necesarios
echo
echo "📦 Verificando paquetes de Tomcat..."

if command -v dnf &> /dev/null; then
    MISSING_PACKAGES=$(dnf list installed | grep -E "tomcat|java-11" | wc -l)
    if [ $MISSING_PACKAGES -lt 3 ]; then
        echo "⚠️  Reinstalando paquetes de Tomcat..."
        dnf reinstall -y tomcat tomcat-lib java-11-openjdk
    fi
else
    MISSING_PACKAGES=$(yum list installed | grep -E "tomcat|java-11" | wc -l)
    if [ $MISSING_PACKAGES -lt 3 ]; then
        echo "⚠️  Reinstalando paquetes de Tomcat..."
        yum reinstall -y tomcat tomcat-lib java-11-openjdk
    fi
fi

# Recargar systemd y reiniciar servicio
echo
echo "🔄 Reiniciando servicios..."
systemctl daemon-reload
systemctl stop tomcat 2>/dev/null || true
sleep 2
systemctl start tomcat

# Esperar un momento
echo "⏳ Esperando inicio de Tomcat..."
sleep 5

# Verificar estado
echo
echo "🔍 Verificando estado final..."
if systemctl is-active --quiet tomcat; then
    echo "✅ Tomcat está ejecutándose correctamente"
    echo "📊 Estado del servicio:"
    systemctl status tomcat --no-pager -l
else
    echo "❌ Tomcat sigue fallando"
    echo "📋 Logs recientes:"
    journalctl -u tomcat -n 20 --no-pager
    echo
    echo "🔍 Diagnóstico adicional:"
    echo "JAVA_HOME: $(echo $JAVA_HOME)"
    echo "Java version: $(java -version 2>&1 | head -1)"
    echo "Tomcat config: $(cat /etc/tomcat/tomcat.conf | grep -E 'CATALINA_|JAVA_')"
fi

echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    CORRECCIÓN COMPLETADA"
echo "═══════════════════════════════════════════════════════════════════"