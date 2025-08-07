package com.usiv.dto;

import java.util.List;

public class LoginResponse {
    
    private String accessToken;
    private String tokenType;
    private List<String> roles;
    private long expiresIn;
    
    public LoginResponse() {}
    
    public LoginResponse(String accessToken, String tokenType, List<String> roles) {
        this.accessToken = accessToken;
        this.tokenType = tokenType;
        this.roles = roles;
        this.expiresIn = 86400; // 24 horas en segundos
    }
    
    public String getAccessToken() {
        return accessToken;
    }
    
    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }
    
    public String getTokenType() {
        return tokenType;
    }
    
    public void setTokenType(String tokenType) {
        this.tokenType = tokenType;
    }
    
    public List<String> getRoles() {
        return roles;
    }
    
    public void setRoles(List<String> roles) {
        this.roles = roles;
    }
    
    public long getExpiresIn() {
        return expiresIn;
    }
    
    public void setExpiresIn(long expiresIn) {
        this.expiresIn = expiresIn;
    }
}