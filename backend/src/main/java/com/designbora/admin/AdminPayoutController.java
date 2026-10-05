package com.designbora.admin;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.payout.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/** Admin: kufuatilia na kurekebisha payouts (kwa wabunifu) na refunds (kwa wateja) */
@RestController
@RequestMapping("/api/admin/payouts")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminPayoutController {

    private final PayoutRepository payoutRepository;
    private final RefundRepository refundRepository;
    private final AdminAuditService auditService;

    public record PayoutRow(Long id, Long orderId, String designerName, String designerPhone, String channel,
                            String destination, boolean ready, BigDecimal amount, String status,
                            String failureReason, LocalDateTime createdAt, LocalDateTime processedAt) {
    }

    public record RefundRow(Long id, Long orderId, String customerName, String phone, BigDecimal amount,
                            String status, String failureReason, LocalDateTime createdAt,
                            LocalDateTime processedAt) {
    }

    public record Summary(Map<String, Long> payoutCounts, Map<String, Long> refundCounts,
                          BigDecimal payoutsWaiting, BigDecimal refundsWaiting) {
    }

    public record ManualRequest(String note) {
    }

    @GetMapping("/summary")
    public ApiResponse<Summary> summary() {
        List<Payout> payouts = payoutRepository.findAll();
        List<Refund> refunds = refundRepository.findAll();
        return ApiResponse.ok(new Summary(
                payouts.stream().collect(Collectors.groupingBy(p -> p.getStatus().name(), TreeMap::new, Collectors.counting())),
                refunds.stream().collect(Collectors.groupingBy(r -> r.getStatus().name(), TreeMap::new, Collectors.counting())),
                payouts.stream().filter(p -> p.getStatus() != PayoutStatus.PROCESSED)
                        .map(Payout::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add),
                refunds.stream().filter(r -> r.getStatus() != PayoutStatus.PROCESSED)
                        .map(Refund::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add)));
    }

    @GetMapping
    public ApiResponse<List<PayoutRow>> payouts(@RequestParam(defaultValue = "ALL") String status) {
        return ApiResponse.ok(payoutRepository.findAll().stream()
                .filter(p -> "ALL".equalsIgnoreCase(status) || p.getStatus().name().equalsIgnoreCase(status))
                .sorted(Comparator.comparing(Payout::getId).reversed())
                .map(this::toRow)
                .toList());
    }

    @GetMapping("/refunds")
    public ApiResponse<List<RefundRow>> refunds(@RequestParam(defaultValue = "ALL") String status) {
        return ApiResponse.ok(refundRepository.findAll().stream()
                .filter(r -> "ALL".equalsIgnoreCase(status) || r.getStatus().name().equalsIgnoreCase(status))
                .sorted(Comparator.comparing(Refund::getId).reversed())
                .map(r -> new RefundRow(r.getId(), r.getOrder().getId(),
                        r.getOrder().getCustomer() == null ? "" : r.getOrder().getCustomer().getFullName(),
                        r.getPhone(), r.getAmount(), r.getStatus().name(), r.getFailureReason(),
                        r.getCreatedAt(), r.getProcessedAt()))
                .toList());
    }

    // ---------- Vitendo: payouts ----------

    @PostMapping("/{id}/retry")
    public ApiResponse<String> retryPayout(@PathVariable Long id) {
        Payout payout = payoutRepository.findById(id).orElseThrow(() -> ApiException.notFound("Payout haijapatikana"));
        if (payout.getStatus() != PayoutStatus.FAILED) {
            throw ApiException.conflict("Payout iliyoshindwa pekee ndiyo inaweza kujaribiwa tena");
        }
        payout.setStatus(PayoutStatus.PENDING);
        payout.setFailureReason(null);
        payoutRepository.save(payout);
        auditService.record("PAYOUT_RETRIED", "PAYOUT", id, "Oda #" + payout.getOrder().getId());
        return ApiResponse.ok("Payout imerudishwa kwenye foleni", "OK");
    }

    @PostMapping("/{id}/mark-paid")
    public ApiResponse<String> markPayoutPaid(@PathVariable Long id, @RequestBody ManualRequest request) {
        Payout payout = payoutRepository.findById(id).orElseThrow(() -> ApiException.notFound("Payout haijapatikana"));
        guardManual(payout.getStatus(), request.note());
        payout.setStatus(PayoutStatus.PROCESSED);
        payout.setProcessedAt(LocalDateTime.now());
        payout.setFailureReason("Imelipwa kwa mkono: " + request.note().trim());
        payoutRepository.save(payout);
        auditService.record("PAYOUT_MARKED_PAID", "PAYOUT", id, request.note().trim());
        return ApiResponse.ok("Payout imewekwa kuwa imelipwa", "OK");
    }

    // ---------- Vitendo: refunds ----------

    @PostMapping("/refunds/{id}/retry")
    public ApiResponse<String> retryRefund(@PathVariable Long id) {
        Refund refund = refundRepository.findById(id).orElseThrow(() -> ApiException.notFound("Refund haijapatikana"));
        if (refund.getStatus() != PayoutStatus.FAILED) {
            throw ApiException.conflict("Refund iliyoshindwa pekee ndiyo inaweza kujaribiwa tena");
        }
        refund.setStatus(PayoutStatus.PENDING);
        refund.setFailureReason(null);
        refundRepository.save(refund);
        auditService.record("REFUND_RETRIED", "REFUND", id, "Oda #" + refund.getOrder().getId());
        return ApiResponse.ok("Refund imerudishwa kwenye foleni", "OK");
    }

    @PostMapping("/refunds/{id}/mark-paid")
    public ApiResponse<String> markRefundPaid(@PathVariable Long id, @RequestBody ManualRequest request) {
        Refund refund = refundRepository.findById(id).orElseThrow(() -> ApiException.notFound("Refund haijapatikana"));
        guardManual(refund.getStatus(), request.note());
        refund.setStatus(PayoutStatus.PROCESSED);
        refund.setProcessedAt(LocalDateTime.now());
        refund.setFailureReason("Imerudishwa kwa mkono: " + request.note().trim());
        refundRepository.save(refund);
        auditService.record("REFUND_MARKED_PAID", "REFUND", id, request.note().trim());
        return ApiResponse.ok("Refund imewekwa kuwa imelipwa", "OK");
    }

    // ---------- Wasaidizi ----------

    /** Kuzuia kulipa mara mbili: PROCESSING bado inaweza kufanikiwa kupitia ClickPesa */
    private static void guardManual(PayoutStatus status, String note) {
        if (status == PayoutStatus.PROCESSED) {
            throw ApiException.conflict("Tayari imelipwa");
        }
        if (status == PayoutStatus.PROCESSING) {
            throw ApiException.conflict("Inatumwa sasa hivi kupitia ClickPesa. Subiri matokeo kabla ya kulipa kwa mkono.");
        }
        if (note == null || note.trim().length() < 3) {
            throw ApiException.badRequest("Andika maelezo, mfano namba ya muamala");
        }
    }

    private PayoutRow toRow(Payout p) {
        DesignerProfile d = p.getDesigner();
        PayoutProvider.Destination current = PayoutService.destinationOf(d);
        String destination = p.getDestination() != null ? p.getDestination()
                : (current != null ? current.label() : null);
        String name = d == null ? "" : (d.getCompanyName() != null && !d.getCompanyName().isBlank()
                ? d.getCompanyName() : (d.getUser() == null ? "" : d.getUser().getFullName()));
        return new PayoutRow(p.getId(), p.getOrder().getId(), name,
                d == null || d.getUser() == null ? "" : d.getUser().getPhone(),
                p.getChannel() != null ? p.getChannel() : (current != null ? current.method() : null),
                destination, current != null, p.getAmount(), p.getStatus().name(), p.getFailureReason(),
                p.getCreatedAt(), p.getProcessedAt());
    }
}
