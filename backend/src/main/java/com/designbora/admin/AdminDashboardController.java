package com.designbora.admin;

import com.designbora.common.ApiResponse;
import com.designbora.designer.verification.DocumentStatus;
import com.designbora.designer.verification.VerificationDocument;
import com.designbora.designer.verification.VerificationDocumentRepository;
import com.designbora.order.Order;
import com.designbora.order.OrderRepository;
import com.designbora.order.OrderStatus;
import com.designbora.payout.Payout;
import com.designbora.payout.PayoutRepository;
import com.designbora.payout.PayoutStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@RestController
@RequestMapping("/api/admin/dashboard")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminDashboardController {

    private final VerificationDocumentRepository verificationDocumentRepository;
    private final OrderRepository orderRepository;
    private final PayoutRepository payoutRepository;

    @GetMapping("/summary")
    public ApiResponse<DashboardSummaryDto> summary() {
        List<VerificationDocument> pendingDocs = verificationDocumentRepository.findByStatus(DocumentStatus.PENDING);
        List<Order> disputedOrders = orderRepository.findByStatus(OrderStatus.DISPUTED);
        List<Payout> allPayouts = payoutRepository.findAll();

        LocalDate today = LocalDate.now();
        BigDecimal todayPayoutsTotal = allPayouts.stream()
                .filter(p -> p.getCreatedAt() != null && p.getCreatedAt().toLocalDate().isEqual(today))
                .map(Payout::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<ActivityItemDto> activity = new ArrayList<>();

        for (VerificationDocument doc : pendingDocs) {
            activity.add(ActivityItemDto.builder()
                    .actorName(doc.getDesigner().getUser().getFullName())
                    .actorRole(doc.getDesigner().getAccountType().name())
                    .actionType("Uhakiki wa Akaunti")
                    .timestamp(doc.getUploadedAt())
                    .build());
        }

        for (Order order : disputedOrders) {
            activity.add(ActivityItemDto.builder()
                    .actorName(order.getCustomer().getFullName())
                    .actorRole("CUSTOMER")
                    .actionType("Mzozo wa Kazi - Order #" + order.getId())
                    .timestamp(order.getCreatedAt())
                    .build());
        }

        List<Payout> pendingPayouts = payoutRepository.findByStatus(PayoutStatus.PENDING);
        for (Payout payout : pendingPayouts) {
            activity.add(ActivityItemDto.builder()
                    .actorName(payout.getDesigner().getUser().getFullName())
                    .actorRole(payout.getDesigner().getAccountType().name())
                    .actionType("Ombi la Malipo - TSh " + payout.getAmount().toBigInteger())
                    .timestamp(payout.getCreatedAt())
                    .build());
        }

        activity.sort(Comparator.comparing(ActivityItemDto::getTimestamp,
                Comparator.nullsLast(Comparator.reverseOrder())));

        List<ActivityItemDto> recentActivity = activity.size() > 10
                ? activity.subList(0, 10)
                : activity;

        DashboardSummaryDto summary = DashboardSummaryDto.builder()
                .pendingVerifications(pendingDocs.size())
                .disputedOrders(disputedOrders.size())
                .todayPayoutsTotal(todayPayoutsTotal)
                .recentActivity(recentActivity)
                .build();

        return ApiResponse.ok(summary);
    }

    @Data
    @Builder
    @AllArgsConstructor
    public static class DashboardSummaryDto {
        private int pendingVerifications;
        private int disputedOrders;
        private BigDecimal todayPayoutsTotal;
        private List<ActivityItemDto> recentActivity;
    }

    @Data
    @Builder
    @AllArgsConstructor
    public static class ActivityItemDto {
        private String actorName;
        private String actorRole;
        private String actionType;
        private LocalDateTime timestamp;
    }
}
