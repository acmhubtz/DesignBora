package com.designbora.designer;

import com.designbora.user.User;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "designer_profiles")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DesignerProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "account_type", nullable = false, length = 20)
    private AccountType accountType;

    @Column(columnDefinition = "TEXT")
    private String bio;

    @Column(name = "experience_years")
    private Integer experienceYears;

    @Column(name = "company_name")
    private String companyName;

    @Column(name = "company_reg_number")
    private String companyRegNumber;

    /** Namba ya kupokea malipo (255XXXXXXXXX) */
    @Column(name = "payout_phone", length = 20)
    private String payoutPhone;

    /** MOBILE (default) au BANK */
    @Column(name = "payout_method", length = 10)
    private String payoutMethod;

    @Column(name = "payout_bank_bic", length = 20)
    private String payoutBankBic;

    @Column(name = "payout_bank_name", length = 100)
    private String payoutBankName;

    @Column(name = "payout_account_number", length = 40)
    private String payoutAccountNumber;

    @Column(name = "payout_account_name", length = 150)
    private String payoutAccountName;

    /** Sababu ya kukataliwa (inaonyeshwa kwa mbunifu) */
    @Column(name = "verification_note", length = 500)
    private String verificationNote;

    @Enumerated(EnumType.STRING)
    @Column(name = "verification_status", nullable = false, length = 20)
    @Builder.Default
    private VerificationStatus verificationStatus = VerificationStatus.PENDING;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now();
    }

    public boolean isVerified() {
        return verificationStatus == VerificationStatus.VERIFIED;
    }
}