package com.designbora.offering;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ServiceOfferingRepository extends JpaRepository<ServiceOffering, Long> {
    List<ServiceOffering> findByDesignerIdAndActiveTrue(Long designerId);
    List<ServiceOffering> findByCategoryIdAndActiveTrue(Long categoryId);
}