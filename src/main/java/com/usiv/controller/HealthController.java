package com.usiv.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/")
public class HealthController {

    @GetMapping
    public ResponseEntity<Map<String, Object>> root() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "OK");
        response.put("application", "PDF Signer");
        response.put("version", "1.0.0");
        response.put("message", "PDF Signer Application is running");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("timestamp", System.currentTimeMillis());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> response = new HashMap<>();
        response.put("app", "PDF Signer");
        response.put("description", "USIV PDF Signing Service");
        response.put("version", "1.0.0");
        response.put("java.version", System.getProperty("java.version"));
        response.put("spring.profiles.active", System.getProperty("spring.profiles.active", "default"));
        return ResponseEntity.ok(response);
    }
}