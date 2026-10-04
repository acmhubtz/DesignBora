package com.designbora.portfolio;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PortfolioItemRepository extends JpaRepository<PortfolioItem, Long> {
    List<PortfolioItem> findByDesignerId(Long designerId);
    List<PortfolioItem> findByCategoryId(Long categoryId);
    List<PortfolioItem> findByDesignerIdAndCategoryId(Long designerId, Long categoryId);
}