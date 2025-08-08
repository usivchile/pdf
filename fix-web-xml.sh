#!/bin/bash

# Script para corregir el web.xml para Spring Boot

echo "=== CORRIGIENDO WEB.XML PARA SPRING BOOT ==="
echo "Fecha: $(date)"
echo

# Variables
WEB_XML_PATH="src/main/webapp/WEB-INF/web.xml"
BACKUP_PATH="src/main/webapp/WEB-INF/web.xml.backup.$(date +%Y%m%d_%H%M%S)"

# Verificar que estamos en el directorio correcto
if [ ! -f "pom.xml" ]; then
    echo "❌ ERROR: No se encuentra pom.xml"
    echo "   Ejecuta este script desde el directorio raíz del proyecto"
    exit 1
fi

echo "✅ Directorio del proyecto detectado"
echo

# Crear backup del web.xml actual
if [ -f "$WEB_XML_PATH" ]; then
    echo "📋 Creando backup del web.xml actual..."
    cp "$WEB_XML_PATH" "$BACKUP_PATH"
    echo "✅ Backup creado: $BACKUP_PATH"
else
    echo "⚠️ No existe web.xml actual, creando uno nuevo"
fi
echo

# Crear directorio WEB-INF si no existe
mkdir -p "src/main/webapp/WEB-INF"

# Crear web.xml correcto para Spring Boot
echo "🔧 Creando web.xml correcto para Spring Boot..."
cat > "$WEB_XML_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">

    <display-name>PDF Signer Spring Boot Application</display-name>
    <description>USIV PDF Signer Web Application - Spring Boot</description>

    <!-- Spring Boot Context Parameter -->
    <context-param>
        <param-name>contextClass</param-name>
        <param-value>org.springframework.web.context.support.AnnotationConfigWebApplicationContext</param-value>
    </context-param>

    <!-- Spring Boot Servlet Initializer -->
    <context-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>com.usiv.PdfSignerApplication</param-value>
    </context-param>

    <!-- Spring Context Loader Listener -->
    <listener>
        <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
    </listener>

    <!-- Character Encoding Filter -->
    <filter>
        <filter-name>characterEncodingFilter</filter-name>
        <filter-class>org.springframework.web.filter.CharacterEncodingFilter</filter-class>
        <init-param>
            <param-name>encoding</param-name>
            <param-value>UTF-8</param-value>
        </init-param>
        <init-param>
            <param-name>forceEncoding</param-name>
            <param-value>true</param-value>
        </init-param>
    </filter>

    <filter-mapping>
        <filter-name>characterEncodingFilter</filter-name>
        <url-pattern>/*</url-pattern>
    </filter-mapping>

    <!-- Spring Boot Dispatcher Servlet -->
    <servlet>
        <servlet-name>dispatcherServlet</servlet-name>
        <servlet-class>org.springframework.web.servlet.DispatcherServlet</servlet-class>
        <init-param>
            <param-name>contextAttribute</param-name>
            <param-value>org.springframework.web.context.WebApplicationContext.ROOT</param-value>
        </init-param>
        <load-on-startup>1</load-on-startup>
    </servlet>

    <servlet-mapping>
        <servlet-name>dispatcherServlet</servlet-name>
        <url-pattern>/</url-pattern>
    </servlet-mapping>

    <!-- Session Configuration -->
    <session-config>
        <session-timeout>30</session-timeout>
        <cookie-config>
            <http-only>true</http-only>
            <secure>false</secure>
        </cookie-config>
    </session-config>

    <!-- Welcome Files -->
    <welcome-file-list>
        <welcome-file>index.html</welcome-file>
    </welcome-file-list>

    <!-- Error Pages -->
    <error-page>
        <error-code>404</error-code>
        <location>/error</location>
    </error-page>

    <error-page>
        <error-code>500</error-code>
        <location>/error</location>
    </error-page>

</web-app>
EOF

echo "✅ web.xml corregido para Spring Boot"
echo

# Verificar el contenido
echo "📄 Contenido del nuevo web.xml:"
head -20 "$WEB_XML_PATH"
echo "..."
echo

# Recompilar
echo "🔨 Recompilando proyecto..."
mvn clean package -DskipTests

if [ $? -eq 0 ]; then
    echo "✅ Compilación exitosa"
    echo
    
    # Verificar que web.xml está en el WAR
    echo "🔍 Verificando web.xml en el WAR..."
    if unzip -l target/pdf-signer-war-1.0.war | grep -q "WEB-INF/web.xml"; then
        echo "✅ web.xml encontrado en el WAR"
        echo "📄 Contenido en el WAR:"
        unzip -p target/pdf-signer-war-1.0.war WEB-INF/web.xml | head -10
    else
        echo "❌ web.xml NO encontrado en el WAR"
    fi
else
    echo "❌ Error en la compilación"
    exit 1
fi

echo
echo "=== CORRECCIÓN COMPLETADA ==="
echo "🔧 Cambios realizados:"
echo "   - web.xml actualizado para Spring Boot"
echo "   - Configuración correcta de DispatcherServlet"
echo "   - Referencia a PdfSignerApplication como clase principal"
echo
echo "📋 Próximos pasos:"
echo "   1. Subir cambios a Git: git add . && git commit -m 'Fix web.xml for Spring Boot'"
echo "   2. Hacer git pull en el VPS"
echo "   3. Ejecutar deploy-local-vps.sh en el VPS"
echo