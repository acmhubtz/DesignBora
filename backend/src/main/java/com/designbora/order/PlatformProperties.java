package com.designbora.order;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
@ConfigurationProperties(prefix = "app.platform")
@Data
public class PlatformProperties {
    private String feeType = "FIXED";
    private BigDecimal feeFixedAmount = new BigDecimal("1000");
    private BigDecimal feePercentage = new BigDecimal("10.0");
}