package com.designbora.payment;

/** method: MOBILE | CARD. provider na phone zinahitajika kwa MOBILE tu. */
public record PaymentRequest(String method, String provider, String phone) {
}
