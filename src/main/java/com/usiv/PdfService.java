
package com.usiv;

import com.itextpdf.io.font.PdfEncodings;
import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.io.image.ImageData;
import com.itextpdf.io.image.ImageDataFactory;
import com.itextpdf.kernel.colors.Color;
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
import org.springframework.stereotype.Service;

import java.io.*;
import java.security.*;
import java.security.cert.Certificate;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.Properties;

@Service
public class PdfService {

    private final Properties props = new Properties();

    public PdfService() throws IOException {
        try (InputStream in = getClass().getClassLoader().getResourceAsStream("signer.properties")) {
            props.load(in);
        }
    }

    public byte[] generateAndSignPdf(Map<String, String> data) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        // Crear PDF
        PdfWriter writer = new PdfWriter(baos);
        PdfDocument pdfDoc = new PdfDocument(writer);
        Document document = new Document(pdfDoc);
        PdfFont fuente = PdfFontFactory.createFont(StandardFonts.HELVETICA);
       


        document.setFont(fuente);
        // Imagen del logo
        ImageData logoData = ImageDataFactory.create(getClass().getClassLoader().getResource("logoUsivComprimido.png"));
        Image logo = new Image(logoData).scaleToFit(75, 75);
        logo.setFixedPosition(500, 770); // Derecha, arriba
        document.add(logo);

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
        String fecha = "Fecha del informe: " + java.time.LocalDate.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
        document.add(new Paragraph(fecha)
            .setFontSize(9)
            .setBold()
            .setTextAlignment(TextAlignment.LEFT).setMultipliedLeading(0.5f));

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

        agregarCampo(document, "Nombre del afiliado:", data.get("nombre"));
        agregarCampo(document, "RUT:", data.get("rut"));
        agregarCampo(document, "Número de licencia médica:", data.get("numeroLicencia"));
        agregarCampo(document, "Fecha de emisión de licencia:", data.get("fechaLicencia"));
        agregarCampo(document, "Sistema de salud:", data.get("sistemaSalud"));

        // Validación
        document.add(new Paragraph("VALIDACIÓN DE UBICACIÓN E IDENTIDAD")
            .setFontSize(14)
            .setBold()
            .setFontColor(azulUsiv));

        agregarCampo(document, "Fecha y hora de validación:", data.get("fechaHoraValidacion"));
        agregarCampo(document, "Medio de validación:", "Aplicación móvil USIV - License");
        agregarCampo(document, "- Latitud GPS:", data.get("latitud"));
        agregarCampo(document, "- Longitud GPS:", data.get("longitud"));
        agregarCampo(document, "- Precisión GPS:", data.get("precision"));
        agregarCampo(document, "- GPS Alterado:", data.get("gpsAlterado"));
        
        agregarCampo(document, "- Dirección aproximada registrada por GPS:", data.getOrDefault("direccionGps", "N/A"));
        agregarCampo(document, "- Domicilio registrado para reposo:", data.getOrDefault("domicilioReposo", "N/A"));
        agregarCampo(document, "- Distancia entre ubicación real y domicilio:", data.getOrDefault("distanciaReposo", "N/A"));
        
        agregarCampo(document, "Resultado de validación geográfica:", "");
       
        
        // Resultado geográfico con color dinámico
        DeviceRgb colorResultado = "COINCIDE CON DOMICILIO DE REPOSO".equalsIgnoreCase(data.get("resultadoGeografico")) ? 
            new DeviceRgb(0, 128, 0) : new DeviceRgb(204, 0, 0);

        document.add(new Paragraph(data.getOrDefault("resultadoGeografico", "N/A"))
            .setFontSize(11).setFontColor(colorResultado).setBold());

        agregarCampo(document, "Resultado de reconocimiento facial:", data.get("resultadoFacial"));
        agregarCampo(document, "Usuario gestor:", data.get("usuarioGestor"));

        document.add(new Paragraph("OBSERVACIONES")
            .setFontSize(13)
            .setBold()
            .setFontColor(azulUsiv));
        document.add(new Paragraph(data.getOrDefault("textoObservacion", ""))
            .setFontSize(11).setTextAlignment(TextAlignment.JUSTIFIED));
        document.add(new Paragraph(data.getOrDefault("textoUsoInforme", ""))
            .setFontSize(11).setTextAlignment(TextAlignment.JUSTIFIED));

        document.close();

        byte[] pdfBytes = baos.toByteArray();

        // Firmar el PDF
        InputStream certStream = getClass().getClassLoader().getResourceAsStream(props.getProperty("signer.p12.path"));
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(certStream, props.getProperty("signer.p12.password").toCharArray());
        String alias = ks.aliases().nextElement();
        PrivateKey pk = (PrivateKey) ks.getKey(alias, props.getProperty("signer.p12.password").toCharArray());
        Certificate[] chain = ks.getCertificateChain(alias);

        Security.addProvider(new BouncyCastleProvider());

        ByteArrayOutputStream signedBaos = new ByteArrayOutputStream();
        PdfReader reader = new PdfReader(new ByteArrayInputStream(pdfBytes));
        PdfSigner signer = new PdfSigner(reader, signedBaos, new StampingProperties());

        PdfSignatureAppearance appearance = signer.getSignatureAppearance()
                .setReason(props.getProperty("signer.reason"))
                .setLocation(props.getProperty("signer.location"))
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
 // 👉 Método auxiliar para agregar campo con estilo
    private void agregarCampo(Document doc, String label, String valor) {
        doc.add(new Paragraph()
            .add(new Text(label).setBold())
            .add(new Text(" " + (valor != null ? valor : "N/A")))
            .setFontSize(11).setMultipliedLeading(0.5f));
    }

}
