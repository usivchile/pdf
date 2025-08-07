package com.usiv.controller;

import com.usiv.security.JwtTokenProvider;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Authentication", description = "API para autenticación y generación de tokens JWT")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Value("${api.admin.username}")
    private String adminUsername;

    @Value("${api.admin.password}")
    private String adminPassword;

    @Value("${api.user.username}")
    private String userUsername;

    @Value("${api.user.password}")
    private String userPassword;

    @PostMapping("/login")
    @Operation(summary = "Autenticar usuario", description = "Autentica un usuario y devuelve un token JWT")
    public ResponseEntity<?> authenticateUser(@RequestBody Map<String, String> credentials) {
        try {
            String username = credentials.get("username");
            String password = credentials.get("password");

            logger.info("Intento de login para usuario: {}", username);

            // Validar credenciales
            boolean isValidUser = false;
            String userRole = "";
            
            if (adminUsername.equals(username) && adminPassword.equals(password)) {
                isValidUser = true;
                userRole = "ADMIN";
            } else if (userUsername.equals(username) && userPassword.equals(password)) {
                isValidUser = true;
                userRole = "USER";
            }

            if (!isValidUser) {
                logger.warn("Credenciales inválidas para usuario: {}", username);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("success", false, "message", "Usuario o contraseña incorrectos"));
            }

            // Generar token JWT
            String jwt = jwtTokenProvider.generateToken(username, Arrays.asList(userRole));
            
            logger.info("Login exitoso para usuario: {} con rol: {}", username, userRole);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("token", jwt);
            response.put("tokenType", "Bearer");
            response.put("username", username);
            response.put("role", userRole);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Error durante la autenticación", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("success", false, "message", "Error interno del servidor"));
        }
    }

    @GetMapping("/validate")
    @Operation(summary = "Validar token", description = "Valida un token JWT y devuelve información del usuario")
    public ResponseEntity<?> validateToken(@RequestHeader("Authorization") String authHeader) {
        try {
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("success", false, "message", "Token no proporcionado o formato incorrecto"));
            }

            String token = authHeader.substring(7);
            
            if (jwtTokenProvider.validateToken(token)) {
                String username = jwtTokenProvider.getUsernameFromToken(token);
                
                Map<String, Object> response = new HashMap<>();
                response.put("success", true);
                response.put("valid", true);
                response.put("username", username);
                
                return ResponseEntity.ok(response);
            } else {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("success", false, "message", "Token inválido o expirado"));
            }
        } catch (Exception e) {
            logger.error("Error durante la validación del token", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("success", false, "message", "Error interno del servidor"));
        }
    }

}