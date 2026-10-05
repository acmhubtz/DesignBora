package com.designbora.dispute;

import com.designbora.order.Order;
import com.designbora.user.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "disputes")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Dispute {

    public static final String OPEN = "OPEN";
    public static final String RESOLVED = "RESOLVED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @ManyToOne
    @JoinColumn(name = "opened_by", nullable = false)
    private User openedBy;

    @Column(nullable = false, length = 1000)
    private String reason;

    @Column(nullable = false, length = 10)
    private String status;

    /** PAY_DESIGNER | REFUND_CUSTOMER | REVISION */
    @Column(length = 20)
    private String resolution;

    @Column(name = "admin_note", length = 1000)
    private String adminNote;

    @ManyToOne
    @JoinColumn(name = "resolved_by")
    private User resolvedBy;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
