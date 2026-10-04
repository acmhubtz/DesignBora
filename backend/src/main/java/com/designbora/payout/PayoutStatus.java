package com.designbora.payout;

public enum PayoutStatus {
    PENDING,     // kwenye foleni (au inasubiri namba ya mbunifu)
    PROCESSING,  // imetumwa kwa ClickPesa, tunasubiri uthibitisho
    PROCESSED,   // mbunifu amepokea pesa
    FAILED
}
