package com.designbora.admin;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.designer.VerificationStatus;
import com.designbora.designer.verification.DocumentStatus;
import com.designbora.designer.verification.VerificationDocument;
import com.designbora.designer.verification.VerificationDocumentRepository;
import com.designbora.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/** Admin: kuhakiki wabunifu (mbunifu mzima pamoja na nyaraka zake) */
@RestController
@RequestMapping("/api/admin/verification")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminVerificationController {

    private final DesignerProfileRepository designerProfileRepository;
    private final VerificationDocumentRepository documentRepository;
    private final AdminAuditService auditService;

    public record DocumentItem(Long id, String documentType, String status,
                               LocalDateTime uploadedAt, String extension) {
    }

    public record DesignerItem(Long designerId, String fullName, String phone, String email, String avatarUrl,
                               String accountType, String companyName, String companyRegNumber,
                               String verificationStatus, String verificationNote, LocalDateTime createdAt,
                               List<DocumentItem> documents) {
    }

    public record Stats(long pending, long verified, long rejected) {
    }

    public record RejectRequest(String reason) {
    }

    @GetMapping("/stats")
    public ApiResponse<Stats> stats() {
        List<DesignerProfile> all = designerProfileRepository.findAll();
        return ApiResponse.ok(new Stats(
                count(all, VerificationStatus.PENDING),
                count(all, VerificationStatus.VERIFIED),
                count(all, VerificationStatus.REJECTED)));
    }

    @GetMapping("/designers")
    public ApiResponse<List<DesignerItem>> designers(@RequestParam(defaultValue = "PENDING") String status) {
        VerificationStatus wanted;
        try {
            wanted = VerificationStatus.valueOf(status.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw ApiException.badRequest("Hali si sahihi: " + status);
        }
        List<DesignerItem> items = designerProfileRepository.findAll().stream()
                .filter(d -> d.getVerificationStatus() == wanted)
                .sorted(Comparator.comparing(DesignerProfile::getCreatedAt,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .map(this::toItem)
                .toList();
        return ApiResponse.ok(items);
    }

    @PostMapping("/designers/{designerId}/approve")
    public ApiResponse<DesignerItem> approve(@PathVariable Long designerId) {
        DesignerProfile designer = findDesigner(designerId);
        designer.setVerificationStatus(VerificationStatus.VERIFIED);
        designer.setVerificationNote(null);
        designerProfileRepository.save(designer);
        updatePendingDocuments(designer, DocumentStatus.APPROVED);
        auditService.record("DESIGNER_APPROVED", "DESIGNER", designer.getId(),
                designer.getUser() == null ? null : designer.getUser().getFullName());
        return ApiResponse.ok("Mbunifu ameidhinishwa", toItem(designer));
    }

    @PostMapping("/designers/{designerId}/reject")
    public ApiResponse<DesignerItem> reject(@PathVariable Long designerId, @RequestBody RejectRequest request) {
        String reason = request.reason() == null ? "" : request.reason().trim();
        if (reason.isEmpty()) {
            throw ApiException.badRequest("Andika sababu ya kukataa ili mbunifu ajue cha kurekebisha");
        }
        DesignerProfile designer = findDesigner(designerId);
        designer.setVerificationStatus(VerificationStatus.REJECTED);
        designer.setVerificationNote(reason.length() > 500 ? reason.substring(0, 500) : reason);
        designerProfileRepository.save(designer);
        updatePendingDocuments(designer, DocumentStatus.REJECTED);
        auditService.record("DESIGNER_REJECTED", "DESIGNER", designer.getId(), reason);
        return ApiResponse.ok("Mbunifu amekataliwa", toItem(designer));
    }

    // ---------- Wasaidizi ----------

    private DesignerProfile findDesigner(Long id) {
        return designerProfileRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Mbunifu hajapatikana"));
    }

    private void updatePendingDocuments(DesignerProfile designer, DocumentStatus newStatus) {
        for (VerificationDocument doc : documentRepository.findByDesignerId(designer.getId())) {
            if (doc.getStatus() == DocumentStatus.PENDING) {
                doc.setStatus(newStatus);
                documentRepository.save(doc);
            }
        }
    }

    private DesignerItem toItem(DesignerProfile d) {
        User u = d.getUser();
        List<DocumentItem> docs = documentRepository.findByDesignerId(d.getId()).stream()
                .sorted(Comparator.comparing(VerificationDocument::getId).reversed())
                .map(doc -> new DocumentItem(doc.getId(), doc.getDocumentType().name(), doc.getStatus().name(),
                        doc.getUploadedAt(), extensionOf(doc.getFileUrl())))
                .toList();
        return new DesignerItem(
                d.getId(),
                u == null ? "" : u.getFullName(),
                u == null ? "" : u.getPhone(),
                u == null ? null : u.getEmail(),
                u == null ? null : u.getAvatarUrl(),
                d.getAccountType() == null ? null : d.getAccountType().name(),
                d.getCompanyName(),
                d.getCompanyRegNumber(),
                d.getVerificationStatus().name(),
                d.getVerificationNote(),
                d.getCreatedAt(),
                docs);
    }

    private static long count(List<DesignerProfile> all, VerificationStatus status) {
        return all.stream().filter(d -> d.getVerificationStatus() == status).count();
    }

    private static String extensionOf(String url) {
        if (url == null) return "";
        int dot = url.lastIndexOf('.');
        return dot >= 0 ? url.substring(dot + 1).toLowerCase(Locale.ROOT) : "";
    }
}
