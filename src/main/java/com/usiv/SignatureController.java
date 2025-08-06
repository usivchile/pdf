
package com.usiv;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.Map;
import java.util.Base64;

@RestController
public class SignatureController {

    @Autowired
    private PdfService pdfService;

    @PostMapping("/firmar")
    public Map<String, String> firmar(@RequestBody Map<String, String> body) throws Exception {
        byte[] signedPdf = pdfService.generateAndSignPdf(body);
        String base64 = Base64.getEncoder().encodeToString(signedPdf);
        return Map.of("status", "ok", "pdfBase64", base64);
    }
}
