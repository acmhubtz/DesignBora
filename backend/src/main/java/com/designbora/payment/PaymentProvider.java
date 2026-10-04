package com.designbora.payment;

/**
 * Mtoa huduma wa malipo. Kwa sasa: MockPaymentProvider.
 * Baadaye: AzamPayProvider / ClickPesaProvider - app haibadiliki.
 */
public interface PaymentProvider {

    record InitResult(String reference, String checkoutUrl) {
    }

    record StatusResult(String status, String failureReason) {
    }

    /** Anzisha malipo: kwa MOBILE inatuma USSD push; kwa CARD inarudisha checkoutUrl. */
    InitResult initiate(Payment payment);

    /** Uliza hali ya malipo (kwa watoa huduma wasio na webhook, au kama ziada yake). */
    StatusResult checkStatus(Payment payment);
}
