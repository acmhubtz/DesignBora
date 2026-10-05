package com.designbora.notification;

import com.designbora.user.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** "Anwani" ya simu kwa arifa (FCM token) */
@Entity
@Table(name = "device_tokens")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, unique = true, length = 512)
    private String token;

    @Column(length = 20)
    private String platform;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
