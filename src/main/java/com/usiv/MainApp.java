package com.usiv;

import com.usiv.service.PdfService;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Map;

public class MainApp {

    public static void main(String[] args) {
        // Medir tiempo de inicio
        long startTime = System.nanoTime();

        // Medir memoria antes
        long beforeUsedMem = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();

        try {
            PdfService pdfService = new PdfService();

            Map<String, String> data = new HashMap<>();
            data.put("nombre", "Juan Pérez");
            data.put("rut", "12.345.678-9");
            data.put("numeroLicencia", "LM123456");
            data.put("fechaLicencia", "05/08/2025");
            data.put("sistemaSalud", "Fonasa");
            data.put("fechaHoraValidacion", "2025-08-05 10:30:00");
            data.put("latitud", "-33.4489");
            data.put("longitud", "-70.6693");
            data.put("precision", "10 metros");
            data.put("gpsAlterado", "No");
            data.put("direccionGps", "Av. Libertador Bernardo O'Higgins 1234, Santiago, Chile");
            data.put("domicilioReposo", "Calle Falsa 123, Las Condes, Santiago");
            data.put("distanciaReposo", "2.5 km");
            data.put("resultadoGeografico", "COINCIDE CON DOMICILIO DE REPOSO");
            data.put("resultadoFacial", "VALIDADO");
            data.put("usuarioGestor", "validador@usiv.cl");
            data.put("textoObservacion", "La validación se realizó sin inconvenientes. El paciente se encontraba en el domicilio registrado.");
            data.put("textoUsoInforme", "Este informe técnico podrá ser utilizado para fines de fiscalización médica, licencias laborales u otros trámites que requieran verificación de identidad y ubicación.");

            byte[] signedPdf = pdfService.generateAndSignPdf(data);

            try (FileOutputStream fos = new FileOutputStream("pdf-firmado.pdf")) {
                fos.write(signedPdf);
            }

            System.out.println("✅ PDF firmado generado con éxito: pdf-firmado.pdf");

        } catch (Exception e) {
            System.err.println("❌ Error al generar y firmar PDF:");
            e.printStackTrace();
        }

        // Medir memoria después
        long afterUsedMem = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        long actualMemUsed = afterUsedMem - beforeUsedMem;

        // Medir tiempo final
        long endTime = System.nanoTime();
        long durationInMs = (endTime - startTime) / 1_000_000;

        System.out.println("📊 Tiempo de ejecución: " + durationInMs + " ms");
        System.out.println("📈 Memoria utilizada: " + (actualMemUsed / 1024) + " KB");
    }
}
