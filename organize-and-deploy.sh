#!/bin/bash

# Script de Organización y Despliegue - PDF Signer
# Instrucciones completas para VPS CentOS/Rocky Linux

echo "═══════════════════════════════════════════════════════════════════"
echo "           ORGANIZACIÓN Y DESPLIEGUE - PDF SIGNER"
echo "                  VPS CentOS/Rocky Linux"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "SCRIPTS ORGANIZADOS:"
echo
echo "📁 SCRIPTS ESENCIALES (mantener):"
echo "   ✓ clean-tomcat-install.sh     - Instalación completa y limpia"
echo "   ✓ check-deployment.sh         - Verificación del despliegue"
echo "   ✓ manage-tomcat.sh            - Gestión del servicio Tomcat"
echo "   ✓ check-maven.sh              - Verificación de Maven"
echo "   ✓ troubleshoot.sh             - Diagnóstico de problemas"
echo "   ✓ verify-tomcat-service.sh    - Verificación específica del servicio"
echo
echo "📁 SCRIPTS OPCIONALES (útiles):"
echo "   ○ organize-and-deploy.sh       - Este script de instrucciones"
echo
echo "🗑️  SCRIPTS ELIMINADOS (obsoletos):"
echo "   ✗ deploy-complete.sh           - Reemplazado por clean-tomcat-install.sh"
echo "   ✗ deploy-from-git.sh           - Funcionalidad integrada"
echo "   ✗ deploy-local.sh              - No necesario para VPS"
echo "   ✗ install-vps.sh               - Reemplazado por clean-tomcat-install.sh"
echo "   ✗ update-from-git.sh           - Funcionalidad integrada"
echo "   ✗ update-local.sh              - No necesario para VPS"
echo "   ✗ configure-git-repo.sh        - Configuración manual"
echo "   ✗ fix-deployment-error.sh      - Reemplazado por troubleshoot.sh"
echo "   ✗ debug-tomcat-extraction.sh   - Funcionalidad integrada"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    INSTRUCCIONES PARA VPS"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "🔄 PASO 1: ACTUALIZAR REPOSITORIO GIT"
echo "   En tu máquina local (donde tienes el código):"
echo "   git add ."
echo "   git commit -m 'Scripts organizados y optimizados para CentOS'"
echo "   git push origin main"
echo
echo "📥 PASO 2: ACTUALIZAR VPS"
echo "   Conectar a tu VPS y ejecutar:"
echo "   cd /ruta/a/tu/proyecto"
echo "   git pull origin main"
echo
echo "🔧 PASO 3: HACER SCRIPTS EJECUTABLES"
echo "   chmod +x *.sh"
echo
echo "🚀 PASO 4: EJECUTAR INSTALACIÓN PRINCIPAL"
echo "   sudo ./clean-tomcat-install.sh"
echo
echo "✅ PASO 5: VERIFICAR INSTALACIÓN"
echo "   ./verify-tomcat-service.sh"
echo
echo "🔍 PASO 6: VERIFICAR DESPLIEGUE (opcional)"
echo "   ./check-deployment.sh"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    COMANDOS ÚTILES VPS"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "📊 ESTADO DEL SERVICIO:"
echo "   sudo systemctl status tomcat"
echo "   sudo systemctl is-active tomcat"
echo "   sudo systemctl is-enabled tomcat"
echo
echo "🔄 GESTIÓN DEL SERVICIO:"
echo "   sudo systemctl start tomcat      # Iniciar"
echo "   sudo systemctl stop tomcat       # Detener"
echo "   sudo systemctl restart tomcat    # Reiniciar"
echo "   sudo systemctl enable tomcat     # Habilitar inicio automático"
echo
echo "📋 LOGS Y DIAGNÓSTICO:"
echo "   sudo journalctl -u tomcat -f     # Logs en tiempo real"
echo "   sudo journalctl -u tomcat -n 50  # Últimos 50 logs"
echo "   ps aux | grep tomcat             # Procesos de Tomcat"
echo "   ss -tlnp | grep 8080             # Verificar puerto 8080"
echo
echo "🌐 VERIFICAR APLICACIÓN:"
echo "   curl http://localhost:8080/pdf-signer/"
echo "   curl -I http://localhost:8080/pdf-signer/"
echo
echo "🔧 SCRIPTS DE DIAGNÓSTICO:"
echo "   ./troubleshoot.sh                # Diagnóstico completo"
echo "   ./verify-tomcat-service.sh       # Verificación específica del servicio"
echo "   ./manage-tomcat.sh status        # Estado detallado"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                      SOLUCIÓN DE PROBLEMAS"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "❌ SI EL SERVICIO NO SE CREA:"
echo "   1. Verificar que se ejecutó como root: sudo ./clean-tomcat-install.sh"
echo "   2. Verificar logs: sudo journalctl -xe"
echo "   3. Verificar archivo de servicio: ls -la /etc/systemd/system/tomcat.service"
echo "   4. Recargar systemd: sudo systemctl daemon-reload"
echo
echo "❌ SI EL SERVICIO NO INICIA:"
echo "   1. Verificar Java: java -version"
echo "   2. Verificar JAVA_HOME: echo \$JAVA_HOME"
echo "   3. Verificar permisos: ls -la /opt/tomcat/bin/startup.sh"
echo "   4. Verificar usuario tomcat: id tomcat"
echo
echo "❌ SI LA APLICACIÓN NO RESPONDE:"
echo "   1. Verificar puerto: ss -tlnp | grep 8080"
echo "   2. Verificar WAR: ls -la /opt/tomcat/webapps/pdf-signer.war"
echo "   3. Verificar logs de aplicación: tail -f /opt/tomcat/logs/catalina.out"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                        NOTAS IMPORTANTES"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "⚠️  REQUISITOS:"
echo "   - VPS con CentOS 7+, Rocky Linux 8+, o RHEL 8+"
echo "   - Acceso root (sudo)"
echo "   - Conexión a internet"
echo "   - Puerto 8080 disponible"
echo
echo "🔒 SEGURIDAD:"
echo "   - El servicio se ejecuta como usuario 'tomcat' (no root)"
echo "   - Firewall: sudo firewall-cmd --permanent --add-port=8080/tcp"
echo "   - Firewall: sudo firewall-cmd --reload"
echo
echo "📞 SOPORTE:"
echo "   - Si encuentras errores, ejecuta: ./troubleshoot.sh"
echo "   - Envía la salida completa para diagnóstico"
echo "   - Incluye: sistema operativo, versión de Java, logs de error"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                           ¡LISTO!"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "Sigue los pasos en orden y envía los resultados de cada comando."
echo "El script principal (clean-tomcat-install.sh) debería resolver"
echo "todos los problemas de compatibilidad con CentOS/Rocky Linux."
echo
echo "¡Buena suerte! 🚀"
echo