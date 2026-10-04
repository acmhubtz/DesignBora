package com.designbora.media;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.storage")
@Data
public class StorageProperties {
    private String basePath;
    private String documentsPath;
    private String portfolioPath;
    private String draftsPath;
    private String finalsPath;
}