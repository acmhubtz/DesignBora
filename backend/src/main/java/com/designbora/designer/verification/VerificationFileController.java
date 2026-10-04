package com.designbora.designer.verification;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.media.MediaStorageService;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;

/**
 * Nyaraka za KYC: hazipo wazi kwenye /uploads.
 * - /file : inahitaji login (mwenye nyaraka au ADMIN)
 * - /link : inatoa kiungo cha muda (dakika 5) kilichosainiwa, ili kufungua kwenye kivinjari
 * - /view : inakubali kiungo hicho tu
 */
@RestController
@RequestMapping("/api/verification-documents")
@RequiredArgsConstructor
public class VerificationFileController {

    private static final long LINK_VALID_SECONDS = 300;

    private final VerificationDocumentRepository documentRepository;
    private final MediaStorageService mediaStorageService;
    private final UserRepository userRepository;

    /** Siri ya kusaini viungo; inabadilika server ikiwashwa upya (viungo vya zamani vinakufa) */
    private final byte[] linkSecret = newSecret();

    @GetMapping("/{id}/file")
    public ResponseEntity<Resource> file(@PathVariable Long id) {
        VerificationDocument document = findAndAuthorize(id);
        return serve(document);
    }

    @PostMapping("/{id}/link")
    public ApiResponse<Map<String, String>> link(@PathVariable Long id) {
        findAndAuthorize(id);
        long expires = Instant.now().getEpochSecond() + LINK_VALID_SECONDS;
        String url = "/api/verification-documents/" + id + "/view?exp=" + expires + "&sig=" + sign(id, expires);
        return ApiResponse.ok(Map.of("url", url));
    }

    @GetMapping("/{id}/view")
    public ResponseEntity<Resource> view(@PathVariable Long id, @RequestParam long exp, @RequestParam String sig) {
        if (Instant.now().getEpochSecond() > exp) {
            throw ApiException.forbidden("Kiungo kimeisha muda. Rudi kwenye app ufungue tena.");
        }
        byte[] expected = sign(id, exp).getBytes(StandardCharsets.UTF_8);
        if (!MessageDigest.isEqual(expected, sig.getBytes(StandardCharsets.UTF_8))) {
            throw ApiException.forbidden("Kiungo si sahihi");
        }
        VerificationDocument document = documentRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Nyaraka haijapatikana"));
        return serve(document);
    }

    // ---------- Wasaidizi ----------

    private VerificationDocument findAndAuthorize(Long id) {
        VerificationDocument document = documentRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Nyaraka haijapatikana"));

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean isAdmin = auth.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        User user = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
        boolean isOwner = document.getDesigner() != null
                && document.getDesigner().getUser() != null
                && document.getDesigner().getUser().getId().equals(user.getId());

        if (!isAdmin && !isOwner) {
            throw ApiException.forbidden("Huna ruhusa ya kuona nyaraka hii");
        }
        return document;
    }

    private ResponseEntity<Resource> serve(VerificationDocument document) {
        Path path = mediaStorageService.resolve(document.getFileUrl());
        if (!Files.exists(path)) {
            throw ApiException.notFound("Faili la nyaraka halipo");
        }
        String contentType;
        try {
            contentType = Files.probeContentType(path);
        } catch (Exception e) {
            contentType = null;
        }
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType == null ? "application/octet-stream" : contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + path.getFileName() + "\"")
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(new FileSystemResource(path));
    }

    private String sign(Long id, long expires) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(linkSecret, "HmacSHA256"));
            byte[] hash = mac.doFinal((id + ":" + expires).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new IllegalStateException("Imeshindwa kusaini kiungo", e);
        }
    }

    private static byte[] newSecret() {
        byte[] secret = new byte[32];
        new SecureRandom().nextBytes(secret);
        return secret;
    }
}
