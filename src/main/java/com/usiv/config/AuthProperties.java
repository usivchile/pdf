package com.usiv.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "api")
public class AuthProperties {
    
    public AuthProperties() {
        // Inicializar con valores por defecto
        this.admin = new Admin();
        this.user = new User();
    }
    
    private Admin admin = new Admin();
    private User user = new User();
    
    public Admin getAdmin() {
        return admin;
    }
    
    public void setAdmin(Admin admin) {
        this.admin = admin;
    }
    
    public User getUser() {
        return user;
    }
    
    public void setUser(User user) {
        this.user = user;
    }
    
    public static class Admin {
        private String username = "admin";
        private String password = "UsivAdmin2025!";
        
        public String getUsername() {
            return username;
        }
        
        public void setUsername(String username) {
            this.username = username;
        }
        
        public String getPassword() {
            return password;
        }
        
        public void setPassword(String password) {
            this.password = password;
        }
    }
    
    public static class User {
        private String username = "user";
        private String password = "user123";
        
        public String getUsername() {
            return username;
        }
        
        public void setUsername(String username) {
            this.username = username;
        }
        
        public String getPassword() {
            return password;
        }
        
        public void setPassword(String password) {
            this.password = password;
        }
    }
}