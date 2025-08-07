package com.usiv.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

/**
 * Configuración de Swagger/OpenAPI para la documentación de la API
 * Proporciona documentación interactiva y esquemas de autenticación JWT
 */
@Configuration
public class SwaggerConfig {

    @Value("${server.servlet.context-path:/}")
    private String contextPath;

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("USIV PDF Signer API")
                        .description("API para generación, firma digital y gestión de documentos PDF con autenticación JWT")
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("USIV Development Team")
                                .email("dev@usiv.cl")
                                .url("https://usiv.cl"))
                        .license(new License()
                                .name("Proprietary")
                                .url("https://usiv.cl/license")))
                .servers(List.of(
                        new Server().url("http://localhost:8080" + contextPath).description("Servidor de desarrollo"),
                        new Server().url("https://api.usiv.cl" + contextPath).description("Servidor de producción")
                ))
                .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
                .components(new Components()
                        .addSecuritySchemes("bearerAuth",
                                new SecurityScheme()
                                        .type(SecurityScheme.Type.HTTP)
                                        .scheme("bearer")
                                        .bearerFormat("JWT")
                                        .description("Token JWT para autenticación. Formato: Bearer {token}")
                        )
                );
    }
}