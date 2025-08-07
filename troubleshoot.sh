#!/bin/bash

# Script de solución de problemas para PDF Validator API
# Diagnostica y resuelve errores comunes de Maven y Java

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Banner
echo -e "${CYAN}"
echo "═══════════════════════════════════════════════════════════════════"
echo "                PDF VALIDATOR API - TROUBLESHOOT                   "
echo "                   Diagnóstico y Solución de Problemas             "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Verificar si estamos en el directorio correcto
if [ ! -f "pom.xml" ]; then
    log_error "No se encontró pom.xml en el directorio actual"
    log_info "Asegúrate de estar en el directorio raíz del proyecto"
    exit 1
fi

log_info "Iniciando diagnóstico del sistema..."

# 1. Verificar versión de Java
echo -e "\n${PURPLE}1. VERIFICANDO JAVA${NC}"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    log_success "Java encontrado: $JAVA_VERSION"
    
    # Verificar si es Java 17 o superior
    JAVA_MAJOR=$(echo $JAVA_VERSION | cut -d'.' -f1)
    if [ "$JAVA_MAJOR" -ge 17 ]; then
        log_success "Versión de Java compatible (17+)"
    else
        log_error "Java $JAVA_VERSION no es compatible. Se requiere Java 17+"
        log_info "Instala Java 17: sudo yum install java-17-openjdk-devel"
    fi
else
    log_error "Java no encontrado"
    log_info "Instala Java 17: sudo yum install java-17-openjdk-devel"
fi

# 2. Verificar JAVA_HOME
echo -e "\n${PURPLE}2. VERIFICANDO JAVA_HOME${NC}"
if [ -n "$JAVA_HOME" ]; then
    log_success "JAVA_HOME configurado: $JAVA_HOME"
else
    log_warn "JAVA_HOME no configurado"
    log_info "Configura JAVA_HOME: export JAVA_HOME=/usr/lib/jvm/java-17-openjdk"
fi

# 3. Verificar Maven
echo -e "\n${PURPLE}3. VERIFICANDO MAVEN${NC}"
if command -v mvn &> /dev/null; then
    MAVEN_VERSION=$(mvn -version | head -n 1 | cut -d' ' -f3)
    log_success "Maven encontrado: $MAVEN_VERSION"
else
    log_error "Maven no encontrado"
    log_info "Instala Maven: sudo yum install maven"
fi

# 4. Verificar conectividad a repositorios Maven
echo -e "\n${PURPLE}4. VERIFICANDO CONECTIVIDAD MAVEN${NC}"
log_info "Probando conectividad a Maven Central..."
if curl -s --connect-timeout 10 https://repo.maven.apache.org/maven2/ > /dev/null; then
    log_success "Conectividad a Maven Central OK"
else
    log_error "No se puede conectar a Maven Central"
    log_info "Verifica tu conexión a internet y configuración de proxy"
fi

# 5. Limpiar caché de Maven
echo -e "\n${PURPLE}5. LIMPIEZA DE CACHÉ MAVEN${NC}"
log_info "Limpiando caché de Maven..."
if [ -d "$HOME/.m2/repository" ]; then
    log_info "Eliminando caché corrupto..."
    rm -rf "$HOME/.m2/repository/com/thoughtworks/xstream" 2>/dev/null
    rm -rf "$HOME/.m2/repository/org/apache/maven/plugins/maven-war-plugin" 2>/dev/null
    log_success "Caché limpiado"
else
    log_info "No se encontró caché de Maven"
fi

# 6. Verificar pom.xml
echo -e "\n${PURPLE}6. VERIFICANDO POM.XML${NC}"
log_info "Verificando configuración del proyecto..."

# Verificar que tenga maven-war-plugin
if grep -q "maven-war-plugin" pom.xml; then
    WAR_PLUGIN_VERSION=$(grep -A 5 "maven-war-plugin" pom.xml | grep "<version>" | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' \t')
    log_success "Plugin maven-war-plugin encontrado: $WAR_PLUGIN_VERSION"
else
    log_error "Plugin maven-war-plugin no encontrado en pom.xml"
    log_info "Agregando plugin maven-war-plugin..."
    
    # Backup del pom.xml
    cp pom.xml pom.xml.backup
    
    # Agregar plugin si no existe
    sed -i '/<\/plugins>/i\            <plugin>\n                <groupId>org.apache.maven.plugins</groupId>\n                <artifactId>maven-war-plugin</artifactId>\n                <version>3.4.0</version>\n                <configuration>\n                    <failOnMissingWebXml>false</failOnMissingWebXml>\n                </configuration>\n            </plugin>' pom.xml
    
    log_success "Plugin maven-war-plugin agregado"
fi

# 7. Verificar dependencias
echo -e "\n${PURPLE}7. VERIFICANDO DEPENDENCIAS${NC}"
log_info "Descargando dependencias..."
if mvn dependency:resolve -q; then
    log_success "Todas las dependencias resueltas"
else
    log_error "Error al resolver dependencias"
    log_info "Ejecutando limpieza profunda..."
    mvn dependency:purge-local-repository -q
fi

# 8. Compilación de prueba
echo -e "\n${PURPLE}8. COMPILACIÓN DE PRUEBA${NC}"
log_info "Intentando compilación de prueba..."
if mvn clean compile -q -Dmaven.compiler.source=17 -Dmaven.compiler.target=17; then
    log_success "Compilación exitosa"
else
    log_error "Error en compilación"
    log_info "Revisa los errores anteriores"
fi

# 9. Generar WAR de prueba
echo -e "\n${PURPLE}9. GENERACIÓN WAR DE PRUEBA${NC}"
log_info "Intentando generar WAR..."
if mvn package -DskipTests -q -Dmaven.compiler.source=17 -Dmaven.compiler.target=17; then
    if [ -f "target/pdf-signer-war-1.0.war" ]; then
        WAR_SIZE=$(du -h target/pdf-signer-war-1.0.war | cut -f1)
        log_success "WAR generado exitosamente: $WAR_SIZE"
    else
        log_error "WAR no encontrado después de la compilación"
    fi
else
    log_error "Error al generar WAR"
fi

# 10. Resumen y recomendaciones
echo -e "\n${PURPLE}10. RESUMEN Y RECOMENDACIONES${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"

if [ -f "target/pdf-signer-war-1.0.war" ]; then
    log_success "✅ DIAGNÓSTICO COMPLETADO - SISTEMA FUNCIONAL"
    echo -e "${GREEN}El proyecto se puede compilar correctamente.${NC}"
    echo -e "${GREEN}Puedes proceder con el despliegue usando:${NC}"
    echo -e "${GREEN}  sudo ./deploy-local.sh${NC}"
else
    log_error "❌ DIAGNÓSTICO COMPLETADO - PROBLEMAS DETECTADOS"
    echo -e "${RED}Se encontraron problemas que impiden la compilación.${NC}"
    echo -e "${YELLOW}Recomendaciones:${NC}"
    echo -e "${YELLOW}1. Verifica que Java 17+ esté instalado y configurado${NC}"
    echo -e "${YELLOW}2. Asegúrate de tener conectividad a internet${NC}"
    echo -e "${YELLOW}3. Ejecuta: mvn clean install -U${NC}"
    echo -e "${YELLOW}4. Si persisten los errores, contacta al equipo de desarrollo${NC}"
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Para más ayuda, ejecuta: ./help.sh${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"