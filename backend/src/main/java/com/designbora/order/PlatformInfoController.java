package com.designbora.order;

import com.designbora.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;

/** App inasoma ada ya platform kutoka hapa (badala ya kuiandika ndani ya app) */
@RestController
@RequiredArgsConstructor
public class PlatformInfoController {

    private final PlatformProperties platformProperties;

    public record FeeInfo(String feeType, BigDecimal percentage, BigDecimal fixedAmount) {
    }

    @GetMapping("/api/platform/fee")
    public ApiResponse<FeeInfo> fee() {
        return ApiResponse.ok(new FeeInfo(
                platformProperties.getFeeType(),
                platformProperties.getFeePercentage(),
                platformProperties.getFeeFixedAmount()));
    }
}
