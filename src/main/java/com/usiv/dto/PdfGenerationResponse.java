package com.usiv.dto;

import java.time.LocalDateTime;

public class PdfGenerationResponse {
    
    private boolean success;
    private String message;
    private String filename;
    private String downloadUrl;
    private String downloadToken;
    private String qrCode; // Base64 del QR
    private LocalDateTime generatedAt;
    private LocalDateTime expiresAt;
    private long fileSizeBytes;
    private String checksum; // MD5 o SHA256 del archivo
    
    public PdfGenerationResponse() {
        this.generatedAt = LocalDateTime.now();
    }
    
    public PdfGenerationResponse(boolean success, String message) {
        this();
        this.success = success;
        this.message = message;
    }
    
    public static PdfGenerationResponse success(String filename, String downloadUrl, String downloadToken) {
        PdfGenerationResponse response = new PdfGenerationResponse(true, "PDF generado y firmado exitosamente");
        response.setFilename(filename);
        response.setDownloadUrl(downloadUrl);
        response.setDownloadToken(downloadToken);
        return response;
    }
    
    public static PdfGenerationResponse error(String message) {
        return new PdfGenerationResponse(false, message);
    }
    
    // Getters y Setters
    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }
    
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
    
    public String getFilename() { return filename; }
    public void setFilename(String filename) { this.filename = filename; }
    
    public String getDownloadUrl() { return downloadUrl; }
    public void setDownloadUrl(String downloadUrl) { this.downloadUrl = downloadUrl; }
    
    public String getDownloadToken() { return downloadToken; }
    public void setDownloadToken(String downloadToken) { this.downloadToken = downloadToken; }
    
    public String getQrCode() { return qrCode; }
    public void setQrCode(String qrCode) { this.qrCode = qrCode; }
    
    public LocalDateTime getGeneratedAt() { return generatedAt; }
    public void setGeneratedAt(LocalDateTime generatedAt) { this.generatedAt = generatedAt; }
    
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }
    
    public long getFileSizeBytes() { return fileSizeBytes; }
    public void setFileSizeBytes(long fileSizeBytes) { this.fileSizeBytes = fileSizeBytes; }
    
    public String getChecksum() { return checksum; }
    public void setChecksum(String checksum) { this.checksum = checksum; }
}