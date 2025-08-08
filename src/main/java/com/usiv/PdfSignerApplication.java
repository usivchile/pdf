
package com.usiv;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.context.annotation.PropertySource;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import com.usiv.config.AuthProperties;

@SpringBootApplication
@EnableScheduling
@PropertySource("classpath:application.properties")
@EnableConfigurationProperties(AuthProperties.class)
public class PdfSignerApplication extends SpringBootServletInitializer {
    
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(PdfSignerApplication.class);
    }
    
    public static void main(String[] args) {
        SpringApplication.run(PdfSignerApplication.class, args);
    }
}
