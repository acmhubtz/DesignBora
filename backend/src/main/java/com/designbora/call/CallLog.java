package com.designbora.call;

import com.designbora.order.Order;
import com.designbora.user.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "call_logs", indexes = {
        @Index(name = "idx_call_status", columnList = "status"),
        @Index(name = "idx_call_callee", columnList = "callee_id")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CallLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "order_id")
    private Order order;

    @ManyToOne(optional = false)
    @JoinColumn(name = "caller_id")
    private User caller;

    @ManyToOne(optional = false)
    @JoinColumn(name = "callee_id")
    private User callee;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CallStatus status;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    private LocalDateTime answeredAt;

    private LocalDateTime endedAt;

    public boolean isParticipant(Long userId) {
        return caller.getId().equals(userId) || callee.getId().equals(userId);
    }
}
