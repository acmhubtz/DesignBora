package com.designbora.dispute;

import com.designbora.admin.AdminAuditService;
import com.designbora.chat.ChatController;
import com.designbora.chat.ChatMessage;
import com.designbora.chat.ChatMessageRepository;
import com.designbora.common.ApiException;
import com.designbora.order.Order;
import com.designbora.order.OrderRepository;
import com.designbora.order.OrderStatus;
import com.designbora.payment.Payment;
import com.designbora.payment.PaymentRepository;
import com.designbora.payout.Payout;
import com.designbora.payout.PayoutRepository;
import com.designbora.payout.PayoutStatus;
import com.designbora.payout.Refund;
import com.designbora.payout.RefundRepository;
import com.designbora.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class DisputeService {

    private static final Set<OrderStatus> CAN_DISPUTE =
            EnumSet.of(OrderStatus.PAID, OrderStatus.IN_PROGRESS, OrderStatus.DRAFT_SUBMITTED);

    private final DisputeRepository disputeRepository;
    private final OrderRepository orderRepository;
    private final PayoutRepository payoutRepository;
    private final RefundRepository refundRepository;
    private final PaymentRepository paymentRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final AdminAuditService auditService;

    @Transactional
    public Dispute open(Order order, User customer, String rawReason) {
        String reason = rawReason == null ? "" : rawReason.trim();
        if (reason.length() < 10) {
            throw ApiException.badRequest("Eleza tatizo kwa undani zaidi (angalau herufi 10)");
        }
        if (reason.length() > 1000) {
            reason = reason.substring(0, 1000);
        }
        if (!CAN_DISPUTE.contains(order.getStatus())) {
            throw ApiException.conflict("Mgogoro unaweza kufunguliwa tu kwa oda iliyolipwa ambayo bado haijakamilika");
        }

        Dispute dispute = disputeRepository.save(Dispute.builder()
                .order(order)
                .openedBy(customer)
                .reason(reason)
                .status(Dispute.OPEN)
                .build());

        order.setStatus(OrderStatus.DISPUTED);
        orderRepository.save(order);

        postChat(order, customer, "⚠️ Nimefungua mgogoro kuhusu oda hii.\nSababu: " + reason
                + "\n\nDesignBora itakagua mazungumzo na kazi, kisha itatoa uamuzi.");
        return dispute;
    }

    @Transactional
    public Dispute resolve(Dispute dispute, User admin, String resolution, String rawNote) {
        if (!Dispute.OPEN.equals(dispute.getStatus())) {
            throw ApiException.conflict("Mgogoro huu tayari umeshatatuliwa");
        }
        String note = rawNote == null ? "" : rawNote.trim();
        if (note.length() < 5) {
            throw ApiException.badRequest("Andika maelezo ya uamuzi (pande zote mbili zitayaona)");
        }

        Order order = dispute.getOrder();
        String outcome;
        switch (resolution == null ? "" : resolution) {
            case "PAY_DESIGNER" -> {
                order.setStatus(OrderStatus.COMPLETED);
                order.setCompletedAt(LocalDateTime.now());
                payoutRepository.save(Payout.builder()
                        .designer(order.getDesigner())
                        .order(order)
                        .amount(order.getNetAmount())
                        .status(PayoutStatus.PENDING)
                        .build());
                outcome = "Kazi imekubaliwa. Mbunifu atalipwa, na mteja anaweza kupakua faili kamili.";
            }
            case "REFUND_CUSTOMER" -> {
                order.setStatus(OrderStatus.CANCELLED);
                String phone = paymentRepository.findByOrderId(order.getId()).stream()
                        .filter(p -> Payment.SUCCESS.equals(p.getStatus()) && p.getPhone() != null)
                        .map(Payment::getPhone)
                        .reduce((first, last) -> last)
                        .orElse(null);
                refundRepository.save(Refund.builder()
                        .order(order)
                        .phone(phone)
                        .amount(order.getGrossAmount())
                        .failureReason(phone == null ? "Hakuna namba ya malipo ya simu - irudishwe kwa mkono" : null)
                        .build());
                outcome = "Oda imeghairiwa. Mteja atarudishiwa pesa yake yote kwenye namba aliyolipia nayo.";
            }
            case "REVISION" -> {
                order.setStatus(OrderStatus.IN_PROGRESS);
                outcome = "Mbunifu afanye marekebisho na atume draft mpya.";
            }
            default -> throw ApiException.badRequest("Chagua uamuzi: PAY_DESIGNER, REFUND_CUSTOMER au REVISION");
        }
        orderRepository.save(order);

        dispute.setStatus(Dispute.RESOLVED);
        dispute.setResolution(resolution);
        dispute.setAdminNote(note.length() > 1000 ? note.substring(0, 1000) : note);
        dispute.setResolvedBy(admin);
        dispute.setResolvedAt(LocalDateTime.now());
        disputeRepository.save(dispute);

        postChat(order, admin, "🛡️ Uamuzi wa DesignBora kuhusu mgogoro:\n" + outcome + "\n\nMaelezo: " + note);
        auditService.record("DISPUTE_RESOLVED", "ORDER", order.getId(), resolution + ": " + note);
        return dispute;
    }

    /** Ujumbe kwenye chat ya oda (unaonekana papo hapo kwa pande zote) */
    private void postChat(Order order, User sender, String text) {
        ChatMessage saved = chatMessageRepository.save(ChatMessage.builder()
                .order(order)
                .sender(sender)
                .message(text)
                .build());
        messagingTemplate.convertAndSend("/topic/chat/" + order.getId(),
                new ChatController.ChatMessageResponse(saved.getId(), sender.getId(), sender.getFullName(),
                        saved.getMessage(), saved.getSentAt().toString()));
    }
}
