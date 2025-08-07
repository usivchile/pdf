package com.usiv.service;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

@Service
public class FileManagementService {

    private static final Logger logger = LoggerFactory.getLogger(FileManagementService.class);

    @Value("${pdf.storage.base-path}")
    private String basePath;

    @Value("${pdf.storage.download-base-url}")
    private String downloadBaseUrl;

    @Value("${pdf.cleanup.retention-months:6}")
    private int retentionMonths;

    @Value("${pdf.cleanup.trash-retention-days:30}")
    private int trashRetentionDays;

    @Value("${pdf.cleanup.trash-folder-name:_trash}")
    private String trashFolderName;

    @Value("${pdf.cleanup.enabled:true}")
    private boolean cleanupEnabled;

    public String saveFile(byte[] fileContent, String filename) throws IOException {
        // Crear estructura de directorios basada en fecha actual
        LocalDate now = LocalDate.now();
        String yearMonth = now.format(DateTimeFormatter.ofPattern("yyyy/MM"));
        String day = now.format(DateTimeFormatter.ofPattern("dd"));
        
        Path directoryPath = Paths.get(basePath, yearMonth, day);
        Files.createDirectories(directoryPath);
        
        // Generar nombre único si ya existe
        String uniqueFilename = generateUniqueFilename(directoryPath, filename);
        Path filePath = directoryPath.resolve(uniqueFilename);
        
        // Guardar archivo
        Files.write(filePath, fileContent);
        
        logger.info("Archivo guardado: {} (tamaño: {} bytes)", filePath, fileContent.length);
        
        return filePath.toString();
    }

    public String generateDownloadUrl(String filePath, String downloadToken) {
        // Convertir ruta absoluta a ruta relativa desde base path
        String relativePath = Paths.get(basePath).relativize(Paths.get(filePath)).toString();
        relativePath = relativePath.replace("\\", "/"); // Normalizar separadores para URL
        
        return String.format("%s/%s?token=%s", downloadBaseUrl, relativePath, downloadToken);
    }

    public byte[] getFile(String relativePath) throws IOException {
        Path filePath = Paths.get(basePath, relativePath);
        
        if (!Files.exists(filePath)) {
            throw new IOException("Archivo no encontrado: " + relativePath);
        }
        
        if (!filePath.normalize().startsWith(Paths.get(basePath).normalize())) {
            throw new SecurityException("Acceso denegado: ruta fuera del directorio permitido");
        }
        
        return Files.readAllBytes(filePath);
    }

    public String calculateChecksum(byte[] content) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(content);
            StringBuilder hexString = new StringBuilder();
            
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            logger.error("Error calculando checksum", e);
            return "unknown";
        }
    }

    private String generateUniqueFilename(Path directory, String originalFilename) {
        String name = originalFilename;
        String extension = "";
        
        int lastDot = originalFilename.lastIndexOf('.');
        if (lastDot > 0) {
            name = originalFilename.substring(0, lastDot);
            extension = originalFilename.substring(lastDot);
        }
        
        String filename = originalFilename;
        int counter = 1;
        
        while (Files.exists(directory.resolve(filename))) {
            filename = String.format("%s_%d%s", name, counter, extension);
            counter++;
        }
        
        return filename;
    }

    @Scheduled(cron = "${pdf.cleanup.schedule-cron:0 0 2 * * ?}")
    public void performCleanup() {
        if (!cleanupEnabled) {
            logger.debug("Limpieza automática deshabilitada");
            return;
        }
        
        logger.info("Iniciando limpieza automática de archivos");
        
        try {
            // Paso 1: Mover archivos antiguos a papelera
            moveOldFilesToTrash();
            
            // Paso 2: Eliminar archivos de papelera antiguos
            deleteOldTrashFiles();
            
            logger.info("Limpieza automática completada");
        } catch (Exception e) {
            logger.error("Error durante la limpieza automática", e);
        }
    }

    private void moveOldFilesToTrash() throws IOException {
        LocalDate cutoffDate = LocalDate.now().minusMonths(retentionMonths);
        Path baseDir = Paths.get(basePath);
        Path trashDir = baseDir.resolve(trashFolderName);
        
        Files.createDirectories(trashDir);
        
        List<Path> filesToMove = new ArrayList<>();
        
        // Buscar archivos antiguos
        try (Stream<Path> paths = Files.walk(baseDir)) {
            paths.filter(Files::isRegularFile)
                 .filter(path -> !path.startsWith(trashDir))
                 .filter(path -> isFileOlderThan(path, cutoffDate))
                 .forEach(filesToMove::add);
        }
        
        // Mover archivos a papelera
        for (Path file : filesToMove) {
            try {
                String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
                String trashFilename = timestamp + "_" + file.getFileName().toString();
                Path trashFile = trashDir.resolve(trashFilename);
                
                Files.move(file, trashFile, StandardCopyOption.REPLACE_EXISTING);
                logger.info("Archivo movido a papelera: {} -> {}", file, trashFile);
            } catch (IOException e) {
                logger.error("Error moviendo archivo a papelera: {}", file, e);
            }
        }
        
        logger.info("Archivos movidos a papelera: {}", filesToMove.size());
    }

    private void deleteOldTrashFiles() throws IOException {
        LocalDate cutoffDate = LocalDate.now().minusDays(trashRetentionDays);
        Path trashDir = Paths.get(basePath, trashFolderName);
        
        if (!Files.exists(trashDir)) {
            return;
        }
        
        List<Path> filesToDelete = new ArrayList<>();
        
        try (Stream<Path> paths = Files.walk(trashDir)) {
            paths.filter(Files::isRegularFile)
                 .filter(path -> isFileOlderThan(path, cutoffDate))
                 .forEach(filesToDelete::add);
        }
        
        // Eliminar archivos
        for (Path file : filesToDelete) {
            try {
                Files.delete(file);
                logger.info("Archivo eliminado de papelera: {}", file);
            } catch (IOException e) {
                logger.error("Error eliminando archivo de papelera: {}", file, e);
            }
        }
        
        logger.info("Archivos eliminados de papelera: {}", filesToDelete.size());
    }

    private boolean isFileOlderThan(Path file, LocalDate cutoffDate) {
        try {
            LocalDate fileDate = LocalDate.ofEpochDay(
                Files.getLastModifiedTime(file).toInstant().getEpochSecond() / 86400
            );
            return fileDate.isBefore(cutoffDate);
        } catch (IOException e) {
            logger.error("Error obteniendo fecha de archivo: {}", file, e);
            return false;
        }
    }

    public void manualCleanup() {
        logger.info("Iniciando limpieza manual");
        performCleanup();
    }

    public boolean fileExists(String relativePath) {
        try {
            Path fullPath = Paths.get(basePath, relativePath);
            return Files.exists(fullPath) && Files.isRegularFile(fullPath);
        } catch (Exception e) {
            logger.error("Error checking file existence: {}", relativePath, e);
            return false;
        }
    }

    public boolean deleteFile(String relativePath) {
        try {
            Path fullPath = Paths.get(basePath, relativePath);
            if (Files.exists(fullPath)) {
                Files.delete(fullPath);
                logger.info("File deleted: {}", relativePath);
                return true;
            } else {
                logger.warn("File not found for deletion: {}", relativePath);
                return false;
            }
        } catch (IOException e) {
            logger.error("Error deleting file: {}", relativePath, e);
            return false;
        }
    }

    public CleanupStats getCleanupStats() {
        try {
            Path baseDir = Paths.get(basePath);
            Path trashDir = baseDir.resolve(trashFolderName);
            
            long totalFiles = 0;
            long totalSize = 0;
            long trashFiles = 0;
            long trashSize = 0;
            
            if (Files.exists(baseDir)) {
                try (Stream<Path> paths = Files.walk(baseDir)) {
                    for (Path path : paths.filter(Files::isRegularFile).toList()) {
                        long size = Files.size(path);
                        if (path.startsWith(trashDir)) {
                            trashFiles++;
                            trashSize += size;
                        } else {
                            totalFiles++;
                            totalSize += size;
                        }
                    }
                }
            }
            
            return new CleanupStats(totalFiles, totalSize, trashFiles, trashSize);
        } catch (IOException e) {
            logger.error("Error obteniendo estadísticas de limpieza", e);
            return new CleanupStats(0, 0, 0, 0);
        }
    }

    public static class CleanupStats {
        private final long totalFiles;
        private final long totalSizeBytes;
        private final long trashFiles;
        private final long trashSizeBytes;
        
        public CleanupStats(long totalFiles, long totalSizeBytes, long trashFiles, long trashSizeBytes) {
            this.totalFiles = totalFiles;
            this.totalSizeBytes = totalSizeBytes;
            this.trashFiles = trashFiles;
            this.trashSizeBytes = trashSizeBytes;
        }
        
        public long getTotalFiles() { return totalFiles; }
        public long getTotalSizeBytes() { return totalSizeBytes; }
        public long getTrashFiles() { return trashFiles; }
        public long getTrashSizeBytes() { return trashSizeBytes; }
    }
}