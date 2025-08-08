package com.usiv.controller;

import com.usiv.dto.PdfGenerationRequest;
import com.usiv.dto.PdfGenerationResponse;
import com.usiv.service.FileManagementService;
import com.usiv.service.PdfService;
import com.usiv.security.JwtTokenProvider;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/pdf")
@Tag(name = "PDF Management", description = "API para generación, firma y gestión de documentos PDF")
public class PdfController {

    @Autowired
    private PdfService pdfService;

    @Autowired
    private FileManagementService fileManagementService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @PostMapping("/generate")
    @Operation(
        summary = "Generar y firmar PDF",
        description = "Genera un PDF con los datos proporcionados, lo firma digitalmente y lo almacena",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<PdfGenerationResponse> generatePdf(
            @Valid @RequestBody PdfGenerationRequest request) {
        
        try {
            PdfGenerationResponse response = pdfService.generateAndSignPdf(request);
            
            if (response.isSuccess()) {
                return ResponseEntity.ok(response);
            } else {
                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
            }
        } catch (Exception e) {
            PdfGenerationResponse errorResponse = new PdfGenerationResponse();
            errorResponse.setSuccess(false);
            errorResponse.setMessage("Error interno del servidor: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    @GetMapping("/download/{filename}")
    @Operation(
        summary = "Descargar PDF",
        description = "Descarga un PDF usando un token de descarga válido"
    )
    public ResponseEntity<?> downloadPdf(
            @PathVariable String filename,
            @Parameter(description = "Token JWT para autorizar la descarga")
            @RequestParam String token) {
        
        try {
            // Validar token de descarga
            if (!jwtTokenProvider.validateToken(token)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "Token inválido o expirado"));
            }

            // Verificar que el token es de tipo descarga
            String tokenType = jwtTokenProvider.getTokenType(token);
            if (!"download".equals(tokenType)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Token no autorizado para descarga"));
            }

            // Verificar que el filename coincide con el del token
            String tokenFilename = jwtTokenProvider.getFilenameFromToken(token);
            if (!filename.equals(tokenFilename)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Token no válido para este archivo"));
            }

            // Obtener el archivo
            byte[] fileData = fileManagementService.getFile(filename);
            if (fileData == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "Archivo no encontrado"));
            }

            // Preparar respuesta de descarga
            ByteArrayResource resource = new ByteArrayResource(fileData);
            
            return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_PDF_VALUE)
                .header(HttpHeaders.CONTENT_LENGTH, String.valueOf(fileData.length))
                .body(resource);
                
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Error al descargar archivo: " + e.getMessage()));
        }
    }

    @GetMapping("/status/{filename}")
    @Operation(
        summary = "Verificar estado del archivo",
        description = "Verifica si un archivo existe y obtiene información básica",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> getFileStatus(@PathVariable String filename) {
        try {
            boolean exists = fileManagementService.fileExists(filename);
            Map<String, Object> response = new HashMap<>();
            response.put("filename", filename);
            response.put("exists", exists);
            
            if (exists) {
                byte[] fileData = fileManagementService.getFile(filename);
                response.put("size", fileData.length);
                response.put("checksum", fileManagementService.calculateChecksum(fileData));
            }
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Error al verificar archivo: " + e.getMessage()));
        }
    }

    @DeleteMapping("/delete/{filename}")
    @Operation(
        summary = "Eliminar archivo",
        description = "Elimina un archivo del sistema (solo administradores)",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> deleteFile(@PathVariable String filename) {
        try {
            boolean deleted = fileManagementService.deleteFile(filename);
            
            if (deleted) {
                return ResponseEntity.ok(Map.of(
                    "message", "Archivo eliminado exitosamente",
                    "filename", filename
                ));
            } else {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", "Archivo no encontrado"));
            }
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Error al eliminar archivo: " + e.getMessage()));
        }
    }

    @PostMapping("/cleanup")
    @Operation(
        summary = "Ejecutar limpieza manual",
        description = "Ejecuta manualmente el proceso de limpieza de archivos antiguos (solo administradores)",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> manualCleanup() {
        try {
            fileManagementService.manualCleanup();
            FileManagementService.CleanupStats stats = fileManagementService.getCleanupStats();
            
            Map<String, Object> result = new HashMap<>();
            result.put("status", "success");
            result.put("message", "Limpieza ejecutada correctamente");
            result.put("totalFiles", stats.getTotalFiles());
            result.put("totalSizeBytes", stats.getTotalSizeBytes());
            result.put("trashFiles", stats.getTrashFiles());
            result.put("trashSizeBytes", stats.getTrashSizeBytes());
            
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Error durante la limpieza: " + e.getMessage()));
        }
    }
}