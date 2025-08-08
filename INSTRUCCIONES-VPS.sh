#!/bin/bash

# INSTRUCCIONES SIMPLIFICADAS PARA VPS
# PDF Signer - Instalación de Producción

echo "═══════════════════════════════════════════════════════════════════"
echo "              INSTRUCCIONES PARA TU VPS CENTOS"
echo "                PDF Signer - Producción"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "📁 SCRIPTS DISPONIBLES (solo los necesarios):"
echo "   ✅ simple-production-install.sh  - Instalación completa automatizada"
echo "   ✅ check-deployment.sh           - Verificar despliegue"
echo "   ✅ manage-tomcat.sh              - Gestionar Tomcat"
echo "   ✅ verify-tomcat-service.sh      - Verificar servicios"
echo "   ✅ troubleshoot.sh               - Diagnóstico de problemas"
echo "   ✅ check-maven.sh                - Verificar Maven"
echo "   📋 INSTRUCCIONES-VPS.sh         - Este archivo"
echo
echo "🗑️  SCRIPTS ELIMINADOS (innecesarios):"
echo "   ❌ Todos los scripts de instalación manual"
echo "   ❌ Scripts de configuración individual"
echo "   ❌ Scripts de comparación y testing"
echo "   ❌ Scripts obsoletos y duplicados"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    📋 PASOS EN TU VPS"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "🔄 PASO 1: Actualizar tu repositorio Git (en tu máquina local)"
echo "   git add ."
echo "   git commit -m 'Scripts simplificados para producción'"
echo "   git push origin main"
echo
echo "📥 PASO 2: En tu VPS, actualizar el código"
echo "   cd /ruta/a/tu/proyecto"
echo "   git pull origin main"
echo
echo "🔧 PASO 3: Hacer ejecutable el script principal"
echo "   chmod +x simple-production-install.sh"
echo "   chmod +x *.sh"
echo
echo "🚀 PASO 4: EJECUTAR INSTALACIÓN COMPLETA"
echo "   sudo ./simple-production-install.sh"
echo
echo "   ⚠️  IMPORTANTE: Este script hará:"
echo "   • Eliminar TODAS las instalaciones existentes de Tomcat/Nginx"
echo "   • Instalar desde repositorios oficiales CentOS"
echo "   • Configurar Nginx como proxy reverso"
echo "   • Compilar y desplegar tu aplicación WAR"
echo "   • Configurar firewall y servicios"
echo "   • Verificar funcionamiento completo"
echo
echo "✅ PASO 5: Verificar instalación (opcional)"
echo "   ./check-deployment.sh"
echo "   ./verify-tomcat-service.sh"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    🎯 RESULTADO ESPERADO"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "✅ SERVICIOS FUNCIONANDO:"
echo "   • Java 11 OpenJDK instalado"
echo "   • Tomcat desde repositorios oficiales"
echo "   • Nginx configurado como proxy reverso"
echo "   • PDF Signer desplegado y funcionando"
echo "   • Firewall configurado"
echo "   • Servicios habilitados para inicio automático"
echo
echo "🌐 ACCESO A LA APLICACIÓN:"
echo "   • Principal: http://TU-IP/pdf-signer/"
echo "   • Directo:   http://TU-IP:8080/pdf-signer/"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    🔧 COMANDOS ÚTILES"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "📊 VERIFICAR ESTADO:"
echo "   sudo systemctl status tomcat nginx"
echo "   ss -tlnp | grep -E ':80|:8080'"
echo "   curl http://localhost/pdf-signer/"
echo
echo "🔄 GESTIONAR SERVICIOS:"
echo "   sudo systemctl restart tomcat nginx"
echo "   sudo systemctl stop tomcat nginx"
echo "   sudo systemctl start tomcat nginx"
echo
echo "📋 VER LOGS:"
echo "   sudo journalctl -u tomcat -f"
echo "   sudo journalctl -u nginx -f"
echo "   tail -f /var/log/tomcat/catalina.out"
echo
echo "🔄 ACTUALIZAR SISTEMA:"
echo "   sudo yum update    # o sudo dnf update"
echo
echo "🆘 SI HAY PROBLEMAS:"
echo "   ./troubleshoot.sh"
echo "   # Luego copia y pega la salida para diagnóstico"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    ⚠️  NOTAS IMPORTANTES"
echo "═══════════════════════════════════════════════════════════════════"
echo
echo "🎯 VENTAJAS DE ESTA INSTALACIÓN:"
echo "   • Paquetes oficiales y seguros"
echo "   • Actualizaciones automáticas disponibles"
echo "   • Configuración estándar del sistema"
echo "   • Nginx como proxy reverso (mejor rendimiento)"
echo "   • Integración completa con systemd"
echo "   • Menos mantenimiento requerido"
echo
echo "🔒 SEGURIDAD:"
echo "   • Servicios ejecutándose con usuarios no-root"
echo "   • Firewall configurado automáticamente"
echo "   • Paquetes firmados digitalmente"
echo
echo "📞 SOPORTE:"
echo "   • Si hay errores, ejecuta: ./troubleshoot.sh"
echo "   • Copia la salida completa para diagnóstico"
echo "   • Incluye: logs, estado de servicios, configuración"
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "                    🚀 ¡LISTO PARA PRODUCCIÓN!"
echo "═══════════════════════════════════════════════════════════════════"