package com.designbora.payment;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.clickpesa")
@Data
public class ClickPesaProperties {
    private boolean enabled;
    private String baseUrl = "https://api.clickpesa.com/third-parties";
    private String clientId;
    private String apiKey;
    /** Hiari: weka tu kama umewasha checksum kwenye dashboard ya ClickPesa */
    private String checksumKey;
}
