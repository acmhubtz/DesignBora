package com.designbora.payment;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Mtoa huduma wa MAJARIBIO tu.
 * - MOBILE: inafanikiwa baada ya sekunde 10; namba inayoishia "0000" inakataliwa.
 * - CARD: ukurasa wa majaribio /api/payments/mock-card/{id} wenye Kubali/Kataa.
 */
@Component
@ConditionalOnProperty(name = "app.clickpesa.enabled", havingValue = "false", matchIfMissing = true)
public class MockPaymentProvider implements PaymentProvider {

    private static final long MOBILE_APPROVAL_SECONDS = 10;

    @Override
    public InitResult initiate(Payment payment) {
        String reference = "MOCK-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        String checkoutUrl = "CARD".equals(payment.getMethod())
                ? "/api/payments/mock-card/" + payment.getId()
                : null;
        return new InitResult(reference, checkoutUrl);
    }

    @Override
    public StatusResult checkStatus(Payment payment) {
        if (!"MOBILE".equals(payment.getMethod())) {
            // Kadi inabadilishwa na ukurasa wa majaribio, si hapa
            return new StatusResult(payment.getStatus(), null);
        }
        if (payment.getPhone() != null && payment.getPhone().endsWith("0000")) {
            return new StatusResult(Payment.FAILED, "Malipo yamekataliwa (namba ya majaribio ya kushindwa)");
        }
        boolean approved = payment.getCreatedAt()
                .plusSeconds(MOBILE_APPROVAL_SECONDS)
                .isBefore(LocalDateTime.now());
        return new StatusResult(approved ? Payment.SUCCESS : Payment.PENDING, null);
    }
}
