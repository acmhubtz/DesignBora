package com.designbora.payment;

import com.designbora.common.ApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.math.RoundingMode;
import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.clickpesa.enabled", havingValue = "true")
public class ClickPesaPaymentProvider implements PaymentProvider {

    private final ClickPesaClient client;

    @Override
    public InitResult initiate(Payment payment) {
        if (!"MOBILE".equals(payment.getMethod())) {
            throw ApiException.badRequest(
                    "Malipo ya kadi yataongezwa hivi karibuni. Kwa sasa tafadhali lipa kwa simu.");
        }
        String reference = ClickPesaClient.reference("DB", payment.getId());
        Map<?, ?> response = client.post("/payments/initiate-ussd-push-request", Map.of(
                "amount", payment.getAmount().setScale(0, RoundingMode.HALF_UP).toPlainString(),
                "currency", "TZS",
                "orderReference", reference,
                "phoneNumber", payment.getPhone()));
        log.info("ClickPesa USSD push imetumwa: ref={} status={}",
                reference, response == null ? null : response.get("status"));
        return new InitResult(reference, null);
    }

    @Override
    public StatusResult checkStatus(Payment payment) {
        if (payment.getProviderReference() == null) {
            return new StatusResult(Payment.PENDING, null);
        }
        Map<?, ?> item = client.getFirst("/payments/{reference}", payment.getProviderReference());
        if (item == null) {
            return new StatusResult(Payment.PENDING, null);
        }
        return switch (String.valueOf(item.get("status"))) {
            case "SUCCESS", "SETTLED" -> new StatusResult(Payment.SUCCESS, null);
            case "FAILED" -> new StatusResult(Payment.FAILED,
                    item.get("message") == null ? "Malipo hayakufanikiwa" : String.valueOf(item.get("message")));
            default -> new StatusResult(Payment.PENDING, null);
        };
    }
}
