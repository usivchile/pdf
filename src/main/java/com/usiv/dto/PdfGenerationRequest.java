package com.usiv.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.Map;

public class PdfGenerationRequest {
    
    @NotBlank(message = "El nombre del afiliado es requerido")
    @Size(max = 100, message = "El nombre no puede exceder 100 caracteres")
    private String nombre;
    
    @NotBlank(message = "El RUT es requerido")
    @Pattern(regexp = "^[0-9]{1,2}\\.[0-9]{3}\\.[0-9]{3}-[0-9Kk]$", 
             message = "El RUT debe tener el formato XX.XXX.XXX-X")
    private String rut;
    
    @NotBlank(message = "El número de licencia es requerido")
    @Size(max = 50, message = "El número de licencia no puede exceder 50 caracteres")
    private String numeroLicencia;
    
    @NotBlank(message = "La fecha de licencia es requerida")
    @Pattern(regexp = "^[0-9]{2}/[0-9]{2}/[0-9]{4}$", 
             message = "La fecha debe tener el formato DD/MM/YYYY")
    private String fechaLicencia;
    
    @NotBlank(message = "El sistema de salud es requerido")
    private String sistemaSalud;
    
    @NotBlank(message = "La fecha y hora de validación es requerida")
    private String fechaHoraValidacion;
    
    @NotBlank(message = "La latitud es requerida")
    private String latitud;
    
    @NotBlank(message = "La longitud es requerida")
    private String longitud;
    
    @NotBlank(message = "La precisión GPS es requerida")
    private String precision;
    
    @NotBlank(message = "El estado de GPS alterado es requerido")
    private String gpsAlterado;
    
    private String direccionGps;
    private String domicilioReposo;
    private String distanciaReposo;
    
    @NotBlank(message = "El resultado geográfico es requerido")
    private String resultadoGeografico;
    
    @NotBlank(message = "El resultado facial es requerido")
    private String resultadoFacial;
    
    @NotBlank(message = "El usuario gestor es requerido")
    private String usuarioGestor;
    
    private String textoObservacion;
    private String textoUsoInforme;
    
    // Campos adicionales opcionales
    private Map<String, String> camposAdicionales;
    
    public PdfGenerationRequest() {}
    
    // Getters y Setters
    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }
    
    public String getRut() { return rut; }
    public void setRut(String rut) { this.rut = rut; }
    
    public String getNumeroLicencia() { return numeroLicencia; }
    public void setNumeroLicencia(String numeroLicencia) { this.numeroLicencia = numeroLicencia; }
    
    public String getFechaLicencia() { return fechaLicencia; }
    public void setFechaLicencia(String fechaLicencia) { this.fechaLicencia = fechaLicencia; }
    
    public String getSistemaSalud() { return sistemaSalud; }
    public void setSistemaSalud(String sistemaSalud) { this.sistemaSalud = sistemaSalud; }
    
    public String getFechaHoraValidacion() { return fechaHoraValidacion; }
    public void setFechaHoraValidacion(String fechaHoraValidacion) { this.fechaHoraValidacion = fechaHoraValidacion; }
    
    public String getLatitud() { return latitud; }
    public void setLatitud(String latitud) { this.latitud = latitud; }
    
    public String getLongitud() { return longitud; }
    public void setLongitud(String longitud) { this.longitud = longitud; }
    
    public String getPrecision() { return precision; }
    public void setPrecision(String precision) { this.precision = precision; }
    
    public String getGpsAlterado() { return gpsAlterado; }
    public void setGpsAlterado(String gpsAlterado) { this.gpsAlterado = gpsAlterado; }
    
    public String getDireccionGps() { return direccionGps; }
    public void setDireccionGps(String direccionGps) { this.direccionGps = direccionGps; }
    
    public String getDomicilioReposo() { return domicilioReposo; }
    public void setDomicilioReposo(String domicilioReposo) { this.domicilioReposo = domicilioReposo; }
    
    public String getDistanciaReposo() { return distanciaReposo; }
    public void setDistanciaReposo(String distanciaReposo) { this.distanciaReposo = distanciaReposo; }
    
    public String getResultadoGeografico() { return resultadoGeografico; }
    public void setResultadoGeografico(String resultadoGeografico) { this.resultadoGeografico = resultadoGeografico; }
    
    public String getResultadoFacial() { return resultadoFacial; }
    public void setResultadoFacial(String resultadoFacial) { this.resultadoFacial = resultadoFacial; }
    
    public String getUsuarioGestor() { return usuarioGestor; }
    public void setUsuarioGestor(String usuarioGestor) { this.usuarioGestor = usuarioGestor; }
    
    public String getTextoObservacion() { return textoObservacion; }
    public void setTextoObservacion(String textoObservacion) { this.textoObservacion = textoObservacion; }
    
    public String getTextoUsoInforme() { return textoUsoInforme; }
    public void setTextoUsoInforme(String textoUsoInforme) { this.textoUsoInforme = textoUsoInforme; }
    
    public Map<String, String> getCamposAdicionales() { return camposAdicionales; }
    public void setCamposAdicionales(Map<String, String> camposAdicionales) { this.camposAdicionales = camposAdicionales; }
}