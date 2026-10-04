package com.designbora.payment;

import java.math.BigDecimal;

public record PaymentResponse(
        Long id,
        Long orderId,
        String method,
        String provider,
        String status,
        BigDecimal amount,
        String checkoutUrl,
        String failureReason
) {
    public static PaymentResponse from(Payment p) {
        return new PaymentResponse(
                p.getId(),
                p.getOrder().getId(),
                p.getMethod(),
                p.getProvider(),
                p.getStatus(),
                p.getAmount(),
                p.getCheckoutUrl(),
                p.getFailureReason()
        );
    }
}
