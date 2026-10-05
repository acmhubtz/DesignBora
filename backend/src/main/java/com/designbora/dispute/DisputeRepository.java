package com.designbora.dispute;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DisputeRepository extends JpaRepository<Dispute, Long> {
    List<Dispute> findByStatusOrderByIdDesc(String status);
    Optional<Dispute> findTopByOrderIdOrderByIdDesc(Long orderId);
}
