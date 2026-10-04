package com.designbora.designer.metrics;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "designer_metrics")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DesignerMetrics {

    @Id
    @Column(name = "designer_id")
    private Long designerId;

    @Builder.Default
    @Column(name = "total_orders")
    private Integer totalOrders = 0;

    @Builder.Default
    @Column(name = "completed_orders")
    private Integer completedOrders = 0;

    @Builder.Default
    @Column(name = "avg_star_rating")
    private BigDecimal avgStarRating = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "completion_rate")
    private BigDecimal completionRate = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "composite_score")
    private BigDecimal compositeScore = new BigDecimal("0.5");
}