package com.designbora.payout;

import java.util.List;

public interface PayoutProvider {

    /** Mahali pesa inapokwenda: MOBILE (namba ya simu) au BANK (akaunti) */
    record Destination(String method, String phone, String bic, String bankName,
                       String accountNumber, String accountName) {
        public String label() {
            return "BANK".equals(method)
                    ? bankName + " • " + accountNumber
                    : "+" + phone;
        }
    }

    record Bank(String name, String bic) {
    }

    /** status: PROCESSING | SUCCESS | FAILED */
    record StatusResult(String status, String failureReason) {
    }

    String send(Payout payout, Destination destination);

    StatusResult checkStatus(Payout payout);

    /** Kurudisha pesa kwa mteja kwenye namba aliyolipia nayo */
    String sendRefund(Refund refund);

    StatusResult checkRefund(Refund refund);

    List<Bank> banks();
}
