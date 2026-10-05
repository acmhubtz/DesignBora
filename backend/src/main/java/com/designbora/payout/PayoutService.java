package com.designbora.payout;

import com.designbora.designer.DesignerProfile;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.Optional;

/**
 * Foleni ya payouts na refunds. ClickPesa inaruhusu ombi MOJA kila sekunde 60,
 * kwa hiyo tunatuma moja tu kila sekunde 70 (payouts kwanza, kisha refunds).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PayoutService {

    private final PayoutRepository payoutRepository;
    private final RefundRepository refundRepository;
    private final PayoutProvider payoutProvider;
    private final com.designbora.notification.NotificationService notificationService;

    @Scheduled(initialDelay = 30_000, fixedDelay = 70_000)
    public void processQueue() {
        payoutRepository.findByStatus(PayoutStatus.PROCESSING).forEach(this::refresh);
        refundRepository.findByStatus(PayoutStatus.PROCESSING).forEach(this::refreshRefund);

        Optional<Payout> nextPayout = payoutRepository.findByStatus(PayoutStatus.PENDING).stream()
                .filter(p -> destinationOf(p.getDesigner()) != null)
                .min(Comparator.comparing(Payout::getId));
        if (nextPayout.isPresent()) {
            send(nextPayout.get());
            return;
        }

        refundRepository.findByStatus(PayoutStatus.PENDING).stream()
                .filter(r -> r.getPhone() != null && !r.getPhone().isBlank())
                .min(Comparator.comparing(Refund::getId))
                .ifPresent(this::sendRefund);
    }

    /** Mahali pa kupeleka pesa kulingana na chaguo la mbunifu; null kama hajakamilisha taarifa */
    public static PayoutProvider.Destination destinationOf(DesignerProfile d) {
        if (d == null) return null;
        if ("BANK".equals(d.getPayoutMethod())) {
            if (blank(d.getPayoutBankBic()) || blank(d.getPayoutAccountNumber()) || blank(d.getPayoutAccountName())) {
                return null;
            }
            return new PayoutProvider.Destination("BANK", null, d.getPayoutBankBic(), d.getPayoutBankName(),
                    d.getPayoutAccountNumber(), d.getPayoutAccountName());
        }
        if (blank(d.getPayoutPhone())) return null;
        return new PayoutProvider.Destination("MOBILE", d.getPayoutPhone(), null, null, null, null);
    }

    // ---------- Payouts ----------

    private void send(Payout payout) {
        PayoutProvider.Destination destination = destinationOf(payout.getDesigner());
        try {
            String reference = payoutProvider.send(payout, destination);
            payout.setProviderReference(reference);
            payout.setChannel(destination.method());
            payout.setDestination(shorten(destination.label(), 150));
            payout.setPhone(destination.phone());
            payout.setStatus(PayoutStatus.PROCESSING);
            payout.setFailureReason(null);
        } catch (Exception e) {
            payout.setFailureReason(shorten(e.getMessage(), 250));
            log.warn("Payout #{} imeshindwa kutumwa: {}", payout.getId(), e.getMessage());
        }
        payoutRepository.save(payout);
    }

    private void refresh(Payout payout) {
        PayoutProvider.StatusResult result = payoutProvider.checkStatus(payout);
        if ("SUCCESS".equals(result.status())) {
            payout.setStatus(PayoutStatus.PROCESSED);
            payout.setProcessedAt(LocalDateTime.now());
            payout.setFailureReason(null);
            payoutRepository.save(payout);
            log.info("Payout #{} imekamilika", payout.getId());
            notificationService.toDesigner(payout.getOrder(), "PAYOUT_PAID", "Umelipwa! 💰",
                    "TSh " + payout.getAmount().toPlainString() + " za Oda #" + payout.getOrder().getId() + " zimetumwa"
                            + (payout.getDestination() == null ? "." : " kwenda " + payout.getDestination() + "."));
        } else if ("FAILED".equals(result.status())) {
            payout.setStatus(PayoutStatus.FAILED);
            payout.setFailureReason(shorten(result.failureReason(), 250));
            payoutRepository.save(payout);
        }
    }

    // ---------- Refunds ----------

    private void sendRefund(Refund refund) {
        try {
            refund.setProviderReference(payoutProvider.sendRefund(refund));
            refund.setStatus(PayoutStatus.PROCESSING);
            refund.setFailureReason(null);
        } catch (Exception e) {
            refund.setFailureReason(shorten(e.getMessage(), 250));
            log.warn("Refund #{} imeshindwa kutumwa: {}", refund.getId(), e.getMessage());
        }
        refundRepository.save(refund);
    }

    private void refreshRefund(Refund refund) {
        PayoutProvider.StatusResult result = payoutProvider.checkRefund(refund);
        if ("SUCCESS".equals(result.status())) {
            refund.setStatus(PayoutStatus.PROCESSED);
            refund.setProcessedAt(LocalDateTime.now());
            refundRepository.save(refund);
            log.info("Refund #{} imekamilika", refund.getId());
            notificationService.toCustomer(refund.getOrder(), "REFUND_PAID", "Pesa yako imerudishwa",
                    "TSh " + refund.getAmount().toPlainString() + " za Oda #" + refund.getOrder().getId() + " zimerudishwa kwenye namba yako.");
        } else if ("FAILED".equals(result.status())) {
            refund.setStatus(PayoutStatus.FAILED);
            refund.setFailureReason(shorten(result.failureReason(), 250));
            refundRepository.save(refund);
        }
    }

    private static boolean blank(String s) {
        return s == null || s.isBlank();
    }

    private static String shorten(String text, int max) {
        if (text == null) return null;
        return text.length() > max ? text.substring(0, max) : text;
    }
}
