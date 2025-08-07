package com.usiv.controller;

import com.usiv.service.FileManagementService;
import com.usiv.security.JwtTokenProvider;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/download")
@Tag(name = "Public Downloads", description = "API pública para descarga de documentos con token")
public class DownloadController {

    @Autowired
    private FileManagementService fileManagementService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @GetMapping("/{filename}")
    @Operation(
        summary = "Descarga pública de PDF",
        description = "Permite la descarga pública de un PDF usando un token de descarga válido"
    )
    public ResponseEntity<?> downloadFile(
            @PathVariable String filename,
            @Parameter(description = "Token JWT para autorizar la descarga")
            @RequestParam String token) {
        
        try {
            // Validar token de descarga
            if (!jwtTokenProvider.validateToken(token)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                        "error", "Token inválido o expirado",
                        "code", "INVALID_TOKEN",
                        "timestamp", System.currentTimeMillis()
                    ));
            }

            // Verificar que el token es de tipo descarga
            String tokenType = jwtTokenProvider.getTokenTypeFromToken(token);
            if (!"download".equals(tokenType)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                        "error", "Token no autorizado para descarga",
                        "code", "INVALID_TOKEN_TYPE",
                        "timestamp", System.currentTimeMillis()
                    ));
            }

            // Verificar que el filename coincide con el del token
            String tokenFilename = jwtTokenProvider.getFilenameFromToken(token);
            if (!filename.equals(tokenFilename)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                        "error", "Token no válido para este archivo",
                        "code", "FILENAME_MISMATCH",
                        "timestamp", System.currentTimeMillis()
                    ));
            }

            // Obtener el archivo
            byte[] fileData = fileManagementService.getFile(filename);
            if (fileData == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                        "error", "Archivo no encontrado",
                        "code", "FILE_NOT_FOUND",
                        "filename", filename,
                        "timestamp", System.currentTimeMillis()
                    ));
            }

            // Preparar respuesta de descarga
            ByteArrayResource resource = new ByteArrayResource(fileData);
            
            return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_PDF_VALUE)
                .header(HttpHeaders.CONTENT_LENGTH, String.valueOf(fileData.length))
                .header("X-Download-Success", "true")
                .header("X-File-Size", String.valueOf(fileData.length))
                .body(resource);
                
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of(
                    "error", "Error interno del servidor",
                    "code", "INTERNAL_ERROR",
                    "message", e.getMessage(),
                    "timestamp", System.currentTimeMillis()
                ));
        }
    }

    @GetMapping("/info/{filename}")
    @Operation(
        summary = "Información del archivo",
        description = "Obtiene información básica del archivo sin descargarlo"
    )
    public ResponseEntity<Map<String, Object>> getFileInfo(
            @PathVariable String filename,
            @Parameter(description = "Token JWT para autorizar la consulta")
            @RequestParam String token) {
        
        try {
            // Validar token de descarga
            if (!jwtTokenProvider.validateToken(token)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of(
                        "error", "Token inválido o expirado",
                        "code", "INVALID_TOKEN"
                    ));
            }

            // Verificar que el token es de tipo descarga
            String tokenType = jwtTokenProvider.getTokenTypeFromToken(token);
            if (!"download".equals(tokenType)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of(
                        "error", "Token no autorizado",
                        "code", "INVALID_TOKEN_TYPE"
                    ));
            }

            // Verificar que el filename coincide con el del token
            String tokenFilename = jwtTokenProvider.getFilenameFromToken(token);
            if (!filename.equals(tokenFilename)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of(
                        "error", "Token no válido para este archivo",
                        "code", "FILENAME_MISMATCH"
                    ));
            }

            // Verificar si el archivo existe
            boolean exists = fileManagementService.fileExists(filename);
            if (!exists) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of(
                        "error", "Archivo no encontrado",
                        "code", "FILE_NOT_FOUND",
                        "filename", filename
                    ));
            }

            // Obtener información del archivo
            byte[] fileData = fileManagementService.getFile(filename);
            String checksum = fileManagementService.calculateChecksum(fileData);
            
            return ResponseEntity.ok(Map.of(
                "filename", filename,
                "exists", true,
                "size", fileData.length,
                "checksum", checksum,
                "contentType", "application/pdf",
                "downloadable", true
            ));
                
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of(
                    "error", "Error interno del servidor",
                    "code", "INTERNAL_ERROR",
                    "message", e.getMessage()
                ));
        }
    }
}