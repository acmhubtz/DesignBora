package com.designbora.search;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SearchResultDto {
    private Long serviceId;
    private String serviceTitle;
    private BigDecimal price;
    private Integer deliveryDays;

    private Long designerId;
    private String designerName;
    private String designerAvatarUrl;
    private boolean verified;

    private BigDecimal compositeScore;
    private BigDecimal avgStarRating;
}