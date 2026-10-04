package com.designbora.payout;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.List;

/** Majaribio tu: kila payout "inafanikiwa" mara moja, hakuna pesa halisi */
@Slf4j
@Component
@ConditionalOnProperty(name = "app.clickpesa.enabled", havingValue = "false", matchIfMissing = true)
public class MockPayoutProvider implements PayoutProvider {

    @Override
    public String send(Payout payout, Destination destination) {
        log.info("[MOCK] Payout ya TSh {} kwenda {}", payout.getAmount(), destination.label());
        return "MOCKPO" + payout.getId();
    }

    @Override
    public StatusResult checkStatus(Payout payout) {
        return new StatusResult("SUCCESS", null);
    }

    @Override
    public List<Bank> banks() {
        return List.of(
                new Bank("CRDB Bank", "CORUTZTZ"),
                new Bank("NMB Bank", "NMIBTZTZ"),
                new Bank("NBC Bank", "NLCBTZTX"),
                new Bank("Stanbic Bank", "SBICTZTX"),
                new Bank("Equity Bank", "EQBLTZTZ"));
    }
}
