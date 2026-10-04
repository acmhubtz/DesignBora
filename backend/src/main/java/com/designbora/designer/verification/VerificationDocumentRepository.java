package com.designbora.designer.verification;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VerificationDocumentRepository extends JpaRepository<VerificationDocument, Long> {
    List<VerificationDocument> findByDesignerId(Long designerId);
    List<VerificationDocument> findByStatus(DocumentStatus status);
}