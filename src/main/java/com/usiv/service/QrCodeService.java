package com.usiv.service;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

@Service
public class QrCodeService {

    private static final Logger logger = LoggerFactory.getLogger(QrCodeService.class);

    @Value("${qr.size:150}")
    private int qrSize;

    @Value("${qr.margin:1}")
    private int qrMargin;

    @Value("${qr.error-correction:M}")
    private String errorCorrectionLevel;

    public byte[] generateQrCode(String text) throws WriterException, IOException {
        Map<EncodeHintType, Object> hints = new HashMap<>();
        hints.put(EncodeHintType.ERROR_CORRECTION, getErrorCorrectionLevel());
        hints.put(EncodeHintType.MARGIN, qrMargin);
        hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");

        QRCodeWriter qrCodeWriter = new QRCodeWriter();
        BitMatrix bitMatrix = qrCodeWriter.encode(text, BarcodeFormat.QR_CODE, qrSize, qrSize, hints);

        BufferedImage image = new BufferedImage(qrSize, qrSize, BufferedImage.TYPE_INT_RGB);
        image.createGraphics();

        Graphics2D graphics = (Graphics2D) image.getGraphics();
        graphics.setColor(Color.WHITE);
        graphics.fillRect(0, 0, qrSize, qrSize);
        graphics.setColor(Color.BLACK);

        for (int i = 0; i < qrSize; i++) {
            for (int j = 0; j < qrSize; j++) {
                if (bitMatrix.get(i, j)) {
                    graphics.fillRect(i, j, 1, 1);
                }
            }
        }

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(image, "PNG", baos);
        
        logger.debug("QR Code generado para texto: {} (tamaño: {} bytes)", 
                    text.length() > 50 ? text.substring(0, 50) + "..." : text, 
                    baos.size());
        
        return baos.toByteArray();
    }

    public String generateQrCodeBase64(String text) throws WriterException, IOException {
        byte[] qrBytes = generateQrCode(text);
        return Base64.getEncoder().encodeToString(qrBytes);
    }

    public BufferedImage generateQrCodeImage(String text) throws WriterException {
        Map<EncodeHintType, Object> hints = new HashMap<>();
        hints.put(EncodeHintType.ERROR_CORRECTION, getErrorCorrectionLevel());
        hints.put(EncodeHintType.MARGIN, qrMargin);
        hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");

        QRCodeWriter qrCodeWriter = new QRCodeWriter();
        BitMatrix bitMatrix = qrCodeWriter.encode(text, BarcodeFormat.QR_CODE, qrSize, qrSize, hints);

        BufferedImage image = new BufferedImage(qrSize, qrSize, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = (Graphics2D) image.getGraphics();
        graphics.setColor(Color.WHITE);
        graphics.fillRect(0, 0, qrSize, qrSize);
        graphics.setColor(Color.BLACK);

        for (int i = 0; i < qrSize; i++) {
            for (int j = 0; j < qrSize; j++) {
                if (bitMatrix.get(i, j)) {
                    graphics.fillRect(i, j, 1, 1);
                }
            }
        }

        return image;
    }

    private ErrorCorrectionLevel getErrorCorrectionLevel() {
        switch (errorCorrectionLevel.toUpperCase()) {
            case "L": return ErrorCorrectionLevel.L;
            case "M": return ErrorCorrectionLevel.M;
            case "Q": return ErrorCorrectionLevel.Q;
            case "H": return ErrorCorrectionLevel.H;
            default: return ErrorCorrectionLevel.M;
        }
    }

    public String createDownloadQrText(String downloadUrl, String filename, String checksum) {
        return String.format(
            "USIV PDF Document\n" +
            "Archivo: %s\n" +
            "URL: %s\n" +
            "Checksum: %s\n" +
            "Generado: %s",
            filename,
            downloadUrl,
            checksum,
            java.time.LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"))
        );
    }
}