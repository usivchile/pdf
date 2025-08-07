#!/bin/bash

# Script de ayuda para PDF Validator API
# Muestra todas las opciones de despliegue disponibles

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
echo "═══════════════════════════════════════════════════════════════════"
echo "                    PDF VALIDATOR API - AYUDA                      "
echo "                     Opciones de Despliegue                       "
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${NC}"

echo -e "${GREEN}🚀 OPCIONES DE DESPLIEGUE DISPONIBLES:${NC}\n"

# Verificar si estamos en un directorio de proyecto
if [ -f "pom.xml" ] && [ -f "deploy-local.sh" ]; then
    echo -e "${BLUE}📍 UBICACIÓN ACTUAL: Directorio del proyecto detectado${NC}"
    echo -e "${GREEN}   Directorio: $(pwd)${NC}\n"
    
    echo -e "${YELLOW}🏠 DESPLIEGUE LOCAL (Recomendado para tu situación):${NC}"
    echo -e "${GREEN}   # Despliegue completo desde este directorio${NC}"
    echo -e "${GREEN}   sudo ./deploy-local.sh${NC}"
    echo -e "${GREEN}   ⏱️  Tiempo: 15-20 minutos${NC}\n"
    
    echo -e "${YELLOW}🔄 ACTUALIZACIÓN LOCAL:${NC}"
    echo -e "${GREEN}   # Actualizar aplicación ya desplegada${NC}"
    echo -e "${GREEN}   git pull  # (opcional, actualizar código)${NC}"
    echo -e "${GREEN}   sudo ./update-local.sh${NC}"
    echo -e "${GREEN}   ⏱️  Tiempo: 3-5 minutos${NC}\n"
else
    echo -e "${BLUE}📍 UBICACIÓN ACTUAL: No es un directorio de proyecto${NC}\n"
fi

echo -e "${YELLOW}🌐 DESPLIEGUE DESDE GIT (Para servidores remotos):${NC}"
echo -e "${GREEN}   # Descargar y ejecutar desde cualquier servidor${NC}"
echo -e "${GREEN}   wget https://raw.githubusercontent.com/tu-usuario/tu-repo/main/deploy-from-git.sh${NC}"
echo -e "${GREEN}   chmod +x deploy-from-git.sh${NC}"
echo -e "${GREEN}   sudo ./deploy-from-git.sh${NC}"
echo -e "${GREEN}   ⏱️  Tiempo: 15-20 minutos${NC}\n"

echo -e "${YELLOW}⚙️  CONFIGURACIÓN INICIAL (Solo una vez):${NC}"
echo -e "${GREEN}   # Configurar URLs de repositorio en scripts${NC}"
echo -e "${GREEN}   ./configure-git-repo.sh${NC}"
echo -e "${GREEN}   git add . && git commit -m \"Configurar Git\" && git push${NC}\n"

echo -e "${YELLOW}📦 DESPLIEGUE MANUAL POR PASOS:${NC}"
echo -e "${GREEN}   # 1. Instalación base${NC}"
echo -e "${GREEN}   sudo ./install-vps.sh${NC}"
echo -e "${GREEN}   # 2. Configurar Nginx${NC}"
echo -e "${GREEN}   sudo ./configure-nginx.sh${NC}"
echo -e "${GREEN}   # 3. Aplicar seguridad${NC}"
echo -e "${GREEN}   sudo ./security-hardening.sh${NC}\n"

echo -e "${BLUE}📋 SCRIPTS DISPONIBLES EN ESTE DIRECTORIO:${NC}"
for script in *.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        case "$script" in
            "deploy-local.sh")
                echo -e "${GREEN}   ✓ $script - Despliegue completo desde directorio local${NC}"
                ;;
            "update-local.sh")
                echo -e "${GREEN}   ✓ $script - Actualización rápida desde directorio local${NC}"
                ;;
            "deploy-from-git.sh")
                echo -e "${GREEN}   ✓ $script - Despliegue completo desde Git${NC}"
                ;;
            "update-from-git.sh")
                echo -e "${GREEN}   ✓ $script - Actualización desde Git${NC}"
                ;;
            "configure-git-repo.sh")
                echo -e "${GREEN}   ✓ $script - Configurador de URLs de Git${NC}"
                ;;
            "install-vps.sh")
                echo -e "${GREEN}   ✓ $script - Instalación base del sistema${NC}"
                ;;
            "configure-nginx.sh")
                echo -e "${GREEN}   ✓ $script - Configuración de Nginx y SSL${NC}"
                ;;
            "security-hardening.sh")
                echo -e "${GREEN}   ✓ $script - Configuraciones de seguridad${NC}"
                ;;
            "deploy-complete.sh")
                echo -e "${GREEN}   ✓ $script - Despliegue con archivos precompilados${NC}"
                ;;
            "help.sh")
                echo -e "${GREEN}   ✓ $script - Esta ayuda${NC}"
                ;;
            *)
                echo -e "${GREEN}   ✓ $script${NC}"
                ;;
        esac
    fi
done

echo -e "\n${BLUE}🔧 COMANDOS ÚTILES POST-DESPLIEGUE:${NC}"
echo -e "${GREEN}   # Ver estado de servicios${NC}"
echo -e "${GREEN}   systemctl status tomcat nginx${NC}"
echo -e "${GREEN}   # Ver logs de aplicación${NC}"
echo -e "${GREEN}   tail -f /opt/tomcat/logs/catalina.out${NC}"
echo -e "${GREEN}   # Ver credenciales${NC}"
echo -e "${GREEN}   cat /opt/pdf-validator-credentials.txt${NC}"
echo -e "${GREEN}   # Reiniciar servicios${NC}"
echo -e "${GREEN}   systemctl restart tomcat${NC}\n"

echo -e "${BLUE}📚 DOCUMENTACIÓN COMPLETA:${NC}"
echo -e "${GREEN}   README.md - Documentación completa${NC}"
echo -e "${GREEN}   DEPLOYMENT-GUIDE.md - Guía rápida de despliegue${NC}"
echo -e "${GREEN}   PROJECT-STRUCTURE.md - Estructura del proyecto${NC}\n"

echo -e "${YELLOW}⚠️  RECOMENDACIÓN PARA TU SITUACIÓN:${NC}"
if [ -f "pom.xml" ] && [ -f "deploy-local.sh" ]; then
    echo -e "${GREEN}   Como ya tienes el proyecto clonado aquí, usa:${NC}"
    echo -e "${GREEN}   sudo ./deploy-local.sh${NC}"
else
    echo -e "${GREEN}   Clona primero el proyecto o usa deploy-from-git.sh${NC}"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Para más ayuda, revisa la documentación o ejecuta cualquier script con -h${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"