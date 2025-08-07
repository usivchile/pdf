package com.usiv.controller;

import com.usiv.dto.LoginRequest;
import com.usiv.dto.LoginResponse;
import com.usiv.security.JwtTokenProvider;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    @Autowired
    private JwtTokenProvider tokenProvider;

    @Autowired
    private PasswordEncoder passwordEncoder;

    // Usuarios hardcodeados para demo - En producción usar base de datos
    private final Map<String, UserInfo> users = new HashMap<String, UserInfo>() {{
        put("admin", new UserInfo("admin", passwordEncoder.encode("admin123"), Arrays.asList("ADMIN", "USER")));
        put("user", new UserInfo("user", passwordEncoder.encode("user123"), Arrays.asList("USER")));
        put("api_client", new UserInfo("api_client", passwordEncoder.encode("api123"), Arrays.asList("API_CLIENT")));
    }};

    @PostMapping("/login")
    public ResponseEntity<?> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) {
        try {
            String username = loginRequest.getUsername();
            String password = loginRequest.getPassword();

            logger.info("Intento de login para usuario: {}", username);

            UserInfo userInfo = users.get(username);
            if (userInfo == null) {
                logger.warn("Usuario no encontrado: {}", username);
                return ResponseEntity.badRequest()
                    .body(new ApiResponse(false, "Usuario o contraseña incorrectos"));
            }

            if (!passwordEncoder.matches(password, userInfo.getPassword())) {
                logger.warn("Contraseña incorrecta para usuario: {}", username);
                return ResponseEntity.badRequest()
                    .body(new ApiResponse(false, "Usuario o contraseña incorrectos"));
            }

            String jwt = tokenProvider.generateToken(username, userInfo.getRoles());
            
            logger.info("Login exitoso para usuario: {} con roles: {}", username, userInfo.getRoles());
            
            return ResponseEntity.ok(new LoginResponse(jwt, "Bearer", userInfo.getRoles()));
            
        } catch (Exception e) {
            logger.error("Error durante la autenticación", e);
            return ResponseEntity.internalServerError()
                .body(new ApiResponse(false, "Error interno del servidor"));
        }
    }

    @GetMapping("/validate")
    public ResponseEntity<?> validateToken(@RequestHeader("Authorization") String authHeader) {
        try {
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String token = authHeader.substring(7);
                
                if (tokenProvider.validateToken(token)) {
                    String username = tokenProvider.getUsernameFromToken(token);
                    List<String> roles = tokenProvider.getRolesFromToken(token);
                    
                    Map<String, Object> response = new HashMap<>();
                    response.put("valid", true);
                    response.put("username", username);
                    response.put("roles", roles);
                    response.put("expiration", tokenProvider.getExpirationDateFromToken(token));
                    
                    return ResponseEntity.ok(response);
                } else {
                    return ResponseEntity.badRequest()
                        .body(new ApiResponse(false, "Token inválido o expirado"));
                }
            } else {
                return ResponseEntity.badRequest()
                    .body(new ApiResponse(false, "Header de autorización requerido"));
            }
        } catch (Exception e) {
            logger.error("Error validando token", e);
            return ResponseEntity.internalServerError()
                .body(new ApiResponse(false, "Error validando token"));
        }
    }

    // Clases internas para DTOs
    public static class UserInfo {
        private String username;
        private String password;
        private List<String> roles;

        public UserInfo(String username, String password, List<String> roles) {
            this.username = username;
            this.password = password;
            this.roles = roles;
        }

        public String getUsername() { return username; }
        public String getPassword() { return password; }
        public List<String> getRoles() { return roles; }
    }

    public static class ApiResponse {
        private Boolean success;
        private String message;

        public ApiResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        public Boolean getSuccess() { return success; }
        public String getMessage() { return message; }
    }
}