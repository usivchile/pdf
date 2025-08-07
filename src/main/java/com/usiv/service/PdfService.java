
package com.usiv.service;

import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.io.image.ImageData;
import com.itextpdf.io.image.ImageDataFactory;
import com.itextpdf.kernel.colors.ColorConstants;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.pdf.*;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.element.Image;
import com.itextpdf.layout.element.Paragraph;
import com.itextpdf.layout.element.Text;
import com.itextpdf.layout.properties.TextAlignment;
import com.itextpdf.signatures.*;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import com.usiv.dto.PdfGenerationRequest;
import com.usiv.dto.PdfGenerationResponse;
import com.usiv.security.JwtTokenProvider;

import java.io.*;
import java.security.*;
import java.security.cert.Certificate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.Map;

@Service
public class PdfService {

    @Autowired
    private QrCodeService qrCodeService;

    @Autowired
    private FileManagementService fileManagementService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Value("${pdf.signature.p12-path}")
    private String keystorePath;

    @Value("${pdf.signature.password}")
    private String keystorePassword;

    @Value("${pdf.signature.reason}")
    private String reason;

    @Value("${pdf.signature.location}")
    private String location;

    @Value("${pdf.signature.contact}")
    private String contact;

    @Value("${pdf.storage.download-url}")
    private String downloadBaseUrl;

    public PdfGenerationResponse generateAndSignPdf(PdfGenerationRequest request) {
        try {
            // Generar nombre de archivo único
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
            String filename = String.format("escritura_%s_%s.pdf", request.getRut(), timestamp);
            
            // Generar URL de descarga y token
            String downloadUrl = downloadBaseUrl + "/download/" + filename;
            String downloadToken = jwtTokenProvider.generateDownloadToken(filename, "admin");
            String downloadUrlWithToken = downloadUrl + "?token=" + downloadToken;
            
            // Generar código QR con la URL de descarga
            String qrText = String.format("Documento: %s\nFecha: %s\nURL: %s", 
                filename, 
                LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")),
                downloadUrlWithToken);
            String qrCodeBase64 = qrCodeService.generateQrCodeAsBase64(qrText);
            
            // Generar PDF en memoria con QR code
            ByteArrayOutputStream pdfOutputStream = new ByteArrayOutputStream();
            generatePdf(request, pdfOutputStream, qrCodeBase64, downloadUrlWithToken);

            // Firmar PDF
            byte[] unsignedPdf = pdfOutputStream.toByteArray();
            byte[] signedPdf = signPdf(unsignedPdf);

            // Guardar archivo firmado
            String savedPath = fileManagementService.saveFile(signedPdf, filename);
            String checksum = fileManagementService.calculateChecksum(signedPdf);
            
            // Crear respuesta
            PdfGenerationResponse response = new PdfGenerationResponse();
            response.setSuccess(true);
            response.setMessage("PDF generado y firmado exitosamente");
            response.setFilename(filename);
            response.setDownloadUrl(downloadUrlWithToken);
            response.setDownloadToken(downloadToken);
            response.setQrCode(qrCodeBase64);
            response.setGeneratedAt(LocalDateTime.now());
            response.setExpiresAt(LocalDateTime.now().plusDays(30)); // Token válido por 30 días
            response.setFileSize(signedPdf.length);
            response.setChecksum(checksum);
            
            return response;
        } catch (Exception e) {
            PdfGenerationResponse errorResponse = new PdfGenerationResponse();
            errorResponse.setSuccess(false);
            errorResponse.setMessage("Error al generar PDF: " + e.getMessage());
            return errorResponse;
        }
    }

    private void generatePdf(PdfGenerationRequest request, ByteArrayOutputStream outputStream, 
                           String qrCodeBase64, String downloadUrl) throws Exception {
        
        PdfWriter writer = new PdfWriter(outputStream);
        PdfDocument pdfDoc = new PdfDocument(writer);
        Document document = new Document(pdfDoc);
        PdfFont fuente = PdfFontFactory.createFont(StandardFonts.HELVETICA);
        document.setFont(fuente);
        
        // Imagen del logo
        ImageData logoData = ImageDataFactory.create(getClass().getClassLoader().getResource("logoUsivComprimido.png"));
        Image logo = new Image(logoData).scaleToFit(75, 75);
        logo.setFixedPosition(500, 770);
        document.add(logo);

        // Agregar QR code en la esquina superior izquierda
        if (qrCodeBase64 != null && !qrCodeBase64.isEmpty()) {
            byte[] qrBytes = Base64.getDecoder().decode(qrCodeBase64);
            ImageData qrImageData = ImageDataFactory.create(qrBytes);
            Image qrImage = new Image(qrImageData).scaleToFit(80, 80);
            qrImage.setFixedPosition(50, 750);
            document.add(qrImage);
        }

        // Colores y formato
        DeviceRgb azulUsiv = new DeviceRgb(16, 41, 77);

        // Título
        document.add(new Paragraph("USIV - LICENSE")
            .setFontSize(26)
            .setFontColor(ColorConstants.LIGHT_GRAY)
            .setTextAlignment(TextAlignment.CENTER)
            .setOpacity(0.5f));

        // Subtítulo
        document.add(new Paragraph("INFORME TÉCNICO DE VERIFICACIÓN GEOGRÁFICA")
            .setFontSize(16)
            .setBold()
            .setFontColor(azulUsiv)
            .setTextAlignment(TextAlignment.CENTER));

        // Fecha
        String fecha = "Fecha del informe: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
        document.add(new Paragraph(fecha)
            .setFontSize(9)
            .setBold()
            .setTextAlignment(TextAlignment.LEFT)
            .setMultipliedLeading(0.5f));

        // URL de descarga
        document.add(new Paragraph("URL de descarga: " + downloadUrl)
            .setFontSize(8)
            .setFontColor(ColorConstants.BLUE)
            .setTextAlignment(TextAlignment.LEFT)
            .setMultipliedLeading(0.5f));

        // Texto introductorio
        String texto1 = "El presente informe tiene por objeto presentar los resultados del proceso de validación de ubicación geográfica e identidad realizado mediante la plataforma USIV. Esta validación se efectúa a través de coordenadas geográficas obtenidas desde el dispositivo móvil del usuario, así como mediante tecnologías de reconocimiento facial, con el propósito de verificar la identidad de la persona evaluada.";
        String texto2 = "USIV garantiza que los datos consignados corresponden a la información registrada durante el proceso de validación, y se reserva el derecho de rechazar aquellos casos en que se detecten manipulaciones en la geolocalización, falsificación de identidad o cualquier intento de interferencia con los mecanismos de autenticación provistos por la plataforma.";
        document.add(new Paragraph(texto1).setFontSize(10).setTextAlignment(TextAlignment.JUSTIFIED));
        document.add(new Paragraph(texto2).setFontSize(10).setTextAlignment(TextAlignment.JUSTIFIED));

        // Sección datos del paciente
        document.add(new Paragraph("DATOS DEL PACIENTE")
            .setFontSize(14)
            .setBold()
            .setFontColor(azulUsiv));

        agregarCampo(document, "Nombre del afiliado:", request.getNombre());
        agregarCampo(document, "RUT:", request.getRut());
        agregarCampo(document, "Número de licencia médica:", request.getNumeroLicencia());
        agregarCampo(document, "Fecha de emisión de licencia:", request.getFechaLicencia());
        agregarCampo(document, "Sistema de salud:", request.getSistemaSalud());

        // Validación
        document.add(new Paragraph("VALIDACIÓN DE UBICACIÓN E IDENTIDAD")
            .setFontSize(14)
            .setBold()
            .setFontColor(azulUsiv));

        agregarCampo(document, "Fecha y hora de validación:", request.getFechaHoraValidacion());
        agregarCampo(document, "Medio de validación:", "Aplicación móvil USIV - License");
        agregarCampo(document, "- Latitud GPS:", request.getLatitud());
        agregarCampo(document, "- Longitud GPS:", request.getLongitud());
        agregarCampo(document, "- Precisión GPS:", request.getPrecision());
        agregarCampo(document, "- GPS Alterado:", request.getGpsAlterado());
        
        agregarCampo(document, "- Dirección aproximada registrada por GPS:", request.getDireccionGps());
        agregarCampo(document, "- Domicilio registrado para reposo:", request.getDomicilioReposo());
        agregarCampo(document, "- Distancia entre ubicación real y domicilio:", request.getDistanciaReposo());
        
        agregarCampo(document, "Resultado de validación geográfica:", "");
       
        // Resultado geográfico con color dinámico
        DeviceRgb colorResultado = "COINCIDE CON DOMICILIO DE REPOSO".equalsIgnoreCase(request.getResultadoGeografico()) ? 
            new DeviceRgb(0, 128, 0) : new DeviceRgb(204, 0, 0);

        document.add(new Paragraph(request.getResultadoGeografico() != null ? request.getResultadoGeografico() : "N/A")
            .setFontSize(11).setFontColor(colorResultado).setBold());

        agregarCampo(document, "Resultado de reconocimiento facial:", request.getResultadoFacial());
        agregarCampo(document, "Usuario gestor:", request.getUsuarioGestor());

        // Campos adicionales si existen
        if (request.getCamposAdicionales() != null && !request.getCamposAdicionales().isEmpty()) {
            document.add(new Paragraph("CAMPOS ADICIONALES")
                .setFontSize(13)
                .setBold()
                .setFontColor(azulUsiv));
            
            for (Map.Entry<String, String> entry : request.getCamposAdicionales().entrySet()) {
                agregarCampo(document, entry.getKey() + ":", entry.getValue());
            }
        }

        document.add(new Paragraph("OBSERVACIONES")
            .setFontSize(13)
            .setBold()
            .setFontColor(azulUsiv));
        document.add(new Paragraph(request.getTextoObservacion() != null ? request.getTextoObservacion() : "")
            .setFontSize(11).setTextAlignment(TextAlignment.JUSTIFIED));
        document.add(new Paragraph(request.getTextoUsoInforme() != null ? request.getTextoUsoInforme() : "")
            .setFontSize(11).setTextAlignment(TextAlignment.JUSTIFIED));

        document.close();
    }

    private byte[] signPdf(byte[] pdfBytes) throws Exception {
        InputStream certStream = getClass().getClassLoader().getResourceAsStream(keystorePath);
        if (certStream == null) {
            throw new RuntimeException("No se pudo encontrar el archivo de certificado: " + keystorePath);
        }
        
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(certStream, keystorePassword.toCharArray());
        String alias = ks.aliases().nextElement();
        PrivateKey pk = (PrivateKey) ks.getKey(alias, keystorePassword.toCharArray());
        Certificate[] chain = ks.getCertificateChain(alias);

        Security.addProvider(new BouncyCastleProvider());

        ByteArrayOutputStream signedBaos = new ByteArrayOutputStream();
        PdfReader reader = new PdfReader(new ByteArrayInputStream(pdfBytes));
        PdfSigner signer = new PdfSigner(reader, signedBaos, new StampingProperties());

        PdfSignatureAppearance appearance = signer.getSignatureAppearance()
                .setReason(reason)
                .setLocation(location)
                .setContact(contact)
                .setReuseAppearance(false);
        signer.setFieldName("sig");

        IExternalSignature pks = new PrivateKeySignature(pk, DigestAlgorithms.SHA256, "BC");

        signer.signDetached(
            new BouncyCastleDigest(),
            pks,
            chain,
            null,
            null,
            null,
            0,
            PdfSigner.CryptoStandard.CADES
        );

        return signedBaos.toByteArray();
    }

    private void agregarCampo(Document doc, String label, String valor) {
        doc.add(new Paragraph()
            .add(new Text(label).setBold())
            .add(new Text(" " + (valor != null ? valor : "N/A")))
            .setFontSize(11).setMultipliedLeading(0.5f));
    }

    // Método de compatibilidad para el controlador existente
    public byte[] generateAndSignPdf(Map<String, String> data) throws Exception {
        // Convertir Map a PdfGenerationRequest para compatibilidad
        PdfGenerationRequest request = new PdfGenerationRequest();
        request.setNombre(data.get("nombre"));
        request.setRut(data.get("rut"));
        request.setNumeroLicencia(data.get("numeroLicencia"));
        request.setFechaLicencia(data.get("fechaLicencia"));
        request.setSistemaSalud(data.get("sistemaSalud"));
        request.setFechaHoraValidacion(data.get("fechaHoraValidacion"));
        request.setLatitud(data.get("latitud"));
        request.setLongitud(data.get("longitud"));
        request.setPrecision(data.get("precision"));
        request.setGpsAlterado(data.get("gpsAlterado"));
        request.setDireccionGps(data.get("direccionGps"));
        request.setDomicilioReposo(data.get("domicilioReposo"));
        request.setDistanciaReposo(data.get("distanciaReposo"));
        request.setResultadoGeografico(data.get("resultadoGeografico"));
        request.setResultadoFacial(data.get("resultadoFacial"));
        request.setUsuarioGestor(data.get("usuarioGestor"));
        request.setTextoObservacion(data.get("textoObservacion"));
        request.setTextoUsoInforme(data.get("textoUsoInforme"));
        
        PdfGenerationResponse response = generateAndSignPdf(request);
        if (response.isSuccess()) {
            // Leer el archivo guardado y retornarlo como bytes
            return fileManagementService.getFile(response.getFilename());
        } else {
            throw new RuntimeException(response.getMessage());
        }
    }
}
