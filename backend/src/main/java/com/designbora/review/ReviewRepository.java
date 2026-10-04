package com.designbora.review;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

public interface ReviewRepository extends JpaRepository<Review, Long> {

    List<Review> findByDesignerIdOrderByCreatedAtDesc(Long designerId);

    Optional<Review> findByOrderId(Long orderId);

    @Query("SELECT AVG(r.starRating) FROM Review r WHERE r.designer.id = :designerId")
    BigDecimal averageStarRating(@Param("designerId") Long designerId);

    long countByDesignerId(Long designerId);
}