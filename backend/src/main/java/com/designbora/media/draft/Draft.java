package com.designbora.media.draft;

import com.designbora.order.Order;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "drafts")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Draft {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "version_no", nullable = false)
    private Integer versionNo;

    @Column(name = "watermarked_file_url", nullable = false)
    private String watermarkedFileUrl;

    @Column(name = "original_file_url", nullable = false)
    private String originalFileUrl;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    @Column(nullable = false, length = 20)
    private DraftStatus status = DraftStatus.PENDING_REVIEW;

    @Column(name = "submitted_at")
    private LocalDateTime submittedAt;

    @PrePersist
    void onCreate() {
        submittedAt = LocalDateTime.now();
    }
}