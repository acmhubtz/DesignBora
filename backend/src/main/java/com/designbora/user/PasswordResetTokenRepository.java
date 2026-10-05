package com.designbora.user;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {
    java.util.Optional<PasswordResetToken> findTopByUserIdAndUsedFalseOrderByIdDesc(Long userId);

    long countByUserIdAndExpiresAtAfter(Long userId, java.time.LocalDateTime time);

    Optional<PasswordResetToken> findTopByUserIdAndCodeAndUsedFalseOrderByIdDesc(Long userId, String code);
}
