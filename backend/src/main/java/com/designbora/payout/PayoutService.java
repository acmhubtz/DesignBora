package com.designbora.payout;

import com.designbora.designer.DesignerProfile;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Comparator;

/**
 * Foleni ya payouts. ClickPesa inaruhusu payout MOJA kila sekunde 60,
 * kwa hiyo tunatuma moja kila sekunde 70 na kufuatilia zilizotumwa.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PayoutService {

    private final PayoutRepository payoutRepository;
    private final PayoutProvider payoutProvider;

    @Scheduled(initialDelay = 30_000, fixedDelay = 70_000)
    public void processQueue() {
        for (Payout payout : payoutRepository.findByStatus(PayoutStatus.PROCESSING)) {
            refresh(payout);
        }
        payoutRepository.findByStatus(PayoutStatus.PENDING).stream()
                .filter(p -> destinationOf(p.getDesigner()) != null)
                .min(Comparator.comparing(Payout::getId))
                .ifPresent(this::send);
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
            // Inabaki PENDING - itajaribiwa tena mzunguko ujao
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
        } else if ("FAILED".equals(result.status())) {
            payout.setStatus(PayoutStatus.FAILED);
            payout.setFailureReason(shorten(result.failureReason(), 250));
            payoutRepository.save(payout);
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
