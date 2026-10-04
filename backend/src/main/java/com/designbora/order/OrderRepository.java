package com.designbora.order;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface OrderRepository extends JpaRepository<Order, Long> {
    List<Order> findByCustomerId(Long customerId);
    List<Order> findByDesignerId(Long designerId);
    List<Order> findByStatus(OrderStatus status);
    long countByStatus(OrderStatus status);
}
