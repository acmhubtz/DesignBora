package com.designbora.payout;

import com.designbora.payment.ClickPesaClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.clickpesa.enabled", havingValue = "true")
public class ClickPesaPayoutProvider implements PayoutProvider {

    private final ClickPesaClient client;

    private List<Bank> cachedBanks = List.of();
    private Instant banksFetchedAt = Instant.EPOCH;

    @Override
    public String send(Payout payout, Destination destination) {
        String reference = ClickPesaClient.reference("DBPO", payout.getId());
        long amount = whole(payout.getAmount());

        Map<?, ?> response;
        if ("BANK".equals(destination.method())) {
            response = client.post("/payouts/create-bank-payout", Map.of(
                    "amount", amount,
                    "accountNumber", destination.accountNumber(),
                    "accountName", destination.accountName(),
                    "currency", "TZS",
                    "accountCurrency", "TZS",
                    "orderReference", reference,
                    "bic", destination.bic()));
        } else {
            response = mobilePayout(reference, amount, destination.phone());
        }
        log.info("ClickPesa payout ({}) imetumwa: ref={} status={} fee={}", destination.method(), reference,
                response == null ? null : response.get("status"),
                response == null ? null : response.get("fee"));
        return reference;
    }

    @Override
    public StatusResult checkStatus(Payout payout) {
        return query(payout.getProviderReference());
    }

    @Override
    public String sendRefund(Refund refund) {
        String reference = ClickPesaClient.reference("DBRF", refund.getId());
        Map<?, ?> response = mobilePayout(reference, whole(refund.getAmount()), refund.getPhone());
        log.info("ClickPesa refund imetumwa: ref={} status={}", reference,
                response == null ? null : response.get("status"));
        return reference;
    }

    @Override
    public StatusResult checkRefund(Refund refund) {
        return query(refund.getProviderReference());
    }

    /** Orodha ya benki (inahifadhiwa kwa saa 6) */
    @Override
    public synchronized List<Bank> banks() {
        if (!cachedBanks.isEmpty() && banksFetchedAt.isAfter(Instant.now().minusSeconds(6 * 3600))) {
            return cachedBanks;
        }
        List<Bank> banks = client.getList("/list/banks").stream()
                .filter(Map.class::isInstance)
                .map(item -> (Map<?, ?>) item)
                .filter(item -> item.get("name") != null && item.get("bic") != null)
                .map(item -> new Bank(String.valueOf(item.get("name")), String.valueOf(item.get("bic"))))
                .sorted(Comparator.comparing(Bank::name))
                .toList();
        if (!banks.isEmpty()) {
            cachedBanks = banks;
            banksFetchedAt = Instant.now();
        }
        return banks;
    }

    // ---------- Wasaidizi ----------

    private Map<?, ?> mobilePayout(String reference, long amount, String phone) {
        return client.post("/payouts/create-mobile-money-payout", Map.of(
                "amount", amount,
                "phoneNumber", phone,
                "currency", "TZS",
                "orderReference", reference));
    }

    private StatusResult query(String reference) {
        Map<?, ?> item = client.getFirst("/payouts/{reference}", reference);
        if (item == null) {
            return new StatusResult("PROCESSING", null);
        }
        String status = String.valueOf(item.get("status"));
        return switch (status) {
            case "SUCCESS" -> new StatusResult("SUCCESS", null);
            case "FAILED", "REFUNDED", "REVERSED" -> new StatusResult("FAILED",
                    "ClickPesa: " + status + (item.get("notes") == null ? "" : " - " + item.get("notes")));
            default -> new StatusResult("PROCESSING", null);
        };
    }

    private static long whole(BigDecimal amount) {
        return amount.setScale(0, RoundingMode.HALF_UP).longValueExact();
    }
}
