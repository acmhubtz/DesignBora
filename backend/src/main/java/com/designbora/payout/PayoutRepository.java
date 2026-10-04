package com.designbora.payout;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PayoutRepository extends JpaRepository<Payout, Long> {
    List<Payout> findByDesignerId(Long designerId);
    List<Payout> findByStatus(PayoutStatus status);
}