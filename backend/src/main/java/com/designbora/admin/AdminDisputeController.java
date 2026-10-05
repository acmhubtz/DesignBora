package com.designbora.admin;

import com.designbora.chat.ChatMessageRepository;
import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.dispute.Dispute;
import com.designbora.dispute.DisputeRepository;
import com.designbora.dispute.DisputeService;
import com.designbora.media.MediaStorageService;
import com.designbora.media.draft.Draft;
import com.designbora.media.draft.DraftRepository;
import com.designbora.order.Order;
import com.designbora.payout.Refund;
import com.designbora.payout.RefundRepository;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

@RestController
@RequestMapping("/api/admin/disputes")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminDisputeController {

    private final DisputeRepository disputeRepository;
    private final DisputeService disputeService;
    private final ChatMessageRepository chatMessageRepository;
    private final DraftRepository draftRepository;
    private final RefundRepository refundRepository;
    private final MediaStorageService mediaStorageService;
    private final UserRepository userRepository;
    private final AdminAuditService auditService;

    public record Party(String name, String phone) {
    }

    public record DisputeSummary(Long id, Long orderId, String serviceTitle, Party customer, Party designer,
                                 BigDecimal grossAmount, BigDecimal netAmount, BigDecimal platformFee,
                                 String orderStatus, String reason, String status, String resolution,
                                 String adminNote, LocalDateTime createdAt, LocalDateTime resolvedAt,
                                 long draftCount, long messageCount) {
    }

    public record MessageView(Long id, String senderName, String senderRole, String message, LocalDateTime sentAt) {
    }

    public record DraftView(Long id, Integer versionNo, String extension, String previewUrl, LocalDateTime submittedAt) {
    }

    public record RefundView(String status, String phone, BigDecimal amount, String failureReason) {
    }

    public record DisputeDetail(DisputeSummary summary, List<MessageView> messages, List<DraftView> drafts,
                                RefundView refund) {
    }

    public record ResolveRequest(String resolution, String note) {
    }

    @GetMapping
    public ApiResponse<List<DisputeSummary>> list(@RequestParam(defaultValue = "OPEN") String status) {
        return ApiResponse.ok(disputeRepository.findByStatusOrderByIdDesc(status.toUpperCase(Locale.ROOT))
                .stream().map(this::summary).toList());
    }

    @GetMapping("/{id}")
    public ApiResponse<DisputeDetail> detail(@PathVariable Long id) {
        Dispute dispute = find(id);
        Long orderId = dispute.getOrder().getId();

        List<MessageView> messages = chatMessageRepository.findByOrderIdOrderBySentAtAsc(orderId).stream()
                .map(m -> new MessageView(m.getId(),
                        m.getSender() == null ? "" : m.getSender().getFullName(),
                        m.getSender() == null ? "" : m.getSender().getRole().name(),
                        m.getMessage(), m.getSentAt()))
                .toList();

        List<DraftView> drafts = draftRepository.findByOrderIdOrderByVersionNoAsc(orderId).stream()
                .map(d -> new DraftView(d.getId(), d.getVersionNo(), extensionOf(d.getOriginalFileUrl()),
                        d.getWatermarkedFileUrl(), d.getSubmittedAt()))
                .toList();

        RefundView refund = refundRepository.findTopByOrderIdOrderByIdDesc(orderId)
                .map(r -> new RefundView(r.getStatus().name(), r.getPhone(), r.getAmount(), r.getFailureReason()))
                .orElse(null);

        return ApiResponse.ok(new DisputeDetail(summary(dispute), messages, drafts, refund));
    }

    /** Faili la ASILI (bila watermark) - kwa admin kuhukumu ubora wa kazi */
    @GetMapping("/{id}/drafts/{draftId}/original")
    public ResponseEntity<Resource> original(@PathVariable Long id, @PathVariable Long draftId) {
        Dispute dispute = find(id);
        Draft draft = draftRepository.findById(draftId)
                .orElseThrow(() -> ApiException.notFound("Draft haijapatikana"));
        if (!draft.getOrder().getId().equals(dispute.getOrder().getId())) {
            throw ApiException.notFound("Draft si ya oda hii");
        }
        Path path = mediaStorageService.resolve(draft.getOriginalFileUrl());
        if (!Files.exists(path)) {
            throw ApiException.notFound("Faili halipo");
        }
        auditService.record("DISPUTE_FILE_VIEWED", "ORDER", dispute.getOrder().getId(), "Draft v" + draft.getVersionNo());

        String type;
        try {
            type = Files.probeContentType(path);
        } catch (Exception e) {
            type = null;
        }
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(type == null ? "application/octet-stream" : type))
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + path.getFileName() + "\"")
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(new FileSystemResource(path));
    }

    @PostMapping("/{id}/resolve")
    public ApiResponse<DisputeSummary> resolve(@PathVariable Long id, @RequestBody ResolveRequest request) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User admin = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Admin hajapatikana"));
        Dispute dispute = disputeService.resolve(find(id), admin, request.resolution(), request.note());
        return ApiResponse.ok("Uamuzi umehifadhiwa", summary(dispute));
    }

    // ---------- Wasaidizi ----------

    private Dispute find(Long id) {
        return disputeRepository.findById(id).orElseThrow(() -> ApiException.notFound("Mgogoro haujapatikana"));
    }

    private DisputeSummary summary(Dispute d) {
        Order o = d.getOrder();
        DesignerProfile designer = o.getDesigner();
        User designerUser = designer == null ? null : designer.getUser();
        return new DisputeSummary(
                d.getId(),
                o.getId(),
                o.getService() == null ? "" : o.getService().getTitle(),
                new Party(o.getCustomer() == null ? "" : o.getCustomer().getFullName(),
                        o.getCustomer() == null ? "" : o.getCustomer().getPhone()),
                new Party(designerUser == null ? "" : designerUser.getFullName(),
                        designerUser == null ? "" : designerUser.getPhone()),
                o.getGrossAmount(), o.getNetAmount(), o.getPlatformFee(),
                o.getStatus().name(),
                d.getReason(), d.getStatus(), d.getResolution(), d.getAdminNote(),
                d.getCreatedAt(), d.getResolvedAt(),
                draftRepository.findByOrderIdOrderByVersionNoAsc(o.getId()).size(),
                chatMessageRepository.findByOrderIdOrderBySentAtAsc(o.getId()).size());
    }

    private static String extensionOf(String url) {
        if (url == null) return "";
        int dot = url.lastIndexOf('.');
        return dot >= 0 ? url.substring(dot + 1).toLowerCase(Locale.ROOT) : "";
    }
}
