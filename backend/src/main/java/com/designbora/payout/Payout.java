package com.designbora.payout;

import com.designbora.designer.DesignerProfile;
import com.designbora.order.Order;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "payouts")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Payout {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "designer_id", nullable = false)
    private DesignerProfile designer;

    @ManyToOne
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    @Column(nullable = false, length = 20)
    private PayoutStatus status = PayoutStatus.PENDING;

    @Column(name = "provider_reference", length = 100)
    private String providerReference;

    @Column(length = 20)
    private String phone;

    /** MOBILE au BANK */
    @Column(length = 10)
    private String channel;

    /** Maelezo ya mahali pesa ilipokwenda, mfano "CRDB Bank • 0150xxxx" */
    @Column(length = 150)
    private String destination;

    @Column(name = "failure_reason", length = 255)
    private String failureReason;

    @Column(name = "processed_at")
    private LocalDateTime processedAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now();
    }
}