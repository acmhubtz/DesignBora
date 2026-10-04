package com.designbora.media.draft;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DraftRepository extends JpaRepository<Draft, Long> {
    List<Draft> findByOrderIdOrderByVersionNoAsc(Long orderId);
}