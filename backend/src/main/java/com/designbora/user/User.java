package com.designbora.user;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

@Entity
@Table(name = "users")
@JsonIgnoreProperties(value = {"passwordHash", "password", "authorities", "username",
        "accountNonExpired", "accountNonLocked", "credentialsNonExpired", "enabled",
        "hibernateLazyInitializer", "handler", "totpSecret", "totpLastStep"}, allowSetters = true)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User implements UserDetails {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "full_name", nullable = false, length = 150)
    private String fullName;

    @Column(unique = true, length = 150)
    private String email;

    @Column(nullable = false, unique = true, length = 20)
    private String phone;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    @Column(name = "avatar_url", length = 255)
    private String avatarUrl;

    /** 2FA (admin): siri ya TOTP, kama imewashwa, na hatua ya mwisho iliyotumika */
    @Column(name = "totp_secret", length = 64)
    private String totpSecret;

    @Column(name = "totp_enabled")
    private Boolean totpEnabled;

    @Column(name = "totp_last_step")
    private Long totpLastStep;

    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // ---- Utekelezaji wa UserDetails (unaohitajika na Spring Security) ----

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return phone; // tunatumia namba ya simu kama "username"
    }

    @Override
    public boolean isAccountNonExpired() { return true; }

    @Override
    public boolean isAccountNonLocked() { return active; }

    @Override
    public boolean isCredentialsNonExpired() { return true; }

    @Override
    public boolean isEnabled() { return active; }
}