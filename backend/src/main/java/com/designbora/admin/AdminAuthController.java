package com.designbora.admin;

import com.designbora.admin.security.TotpService;
import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.security.JwtUtil;
import com.designbora.user.Role;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.annotation.*;

/**
 * Login ya Admin Panel: nenosiri + 2FA (TOTP).
 * Majibu: status = OK (token imetolewa) | SETUP_REQUIRED (skani QR kwanza) | CODE_REQUIRED (weka namba ya 2FA)
 */
@RestController
@RequestMapping("/api/admin/auth")
@RequiredArgsConstructor
public class AdminAuthController {

    private static final long ADMIN_TOKEN_MS = 8L * 60 * 60 * 1000; // saa 8

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;
    private final TotpService totpService;
    private final AdminAuditService auditService;

    public record LoginRequest(String phone, String password, String code) {
    }

    public record LoginResponse(String status, String token, Long userId, String fullName,
                                String otpauthUrl, String secret) {
    }

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@RequestBody LoginRequest request) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.phone(), request.password()));
        } catch (AuthenticationException e) {
            auditService.record(null, request.phone(), "ADMIN_LOGIN_FAILED", null, null, "Nenosiri si sahihi");
            throw ApiException.badRequest("Namba ya simu au nenosiri si sahihi");
        }

        User user = userRepository.findByPhone(request.phone())
                .orElseThrow(() -> ApiException.badRequest("Namba ya simu au nenosiri si sahihi"));
        if (user.getRole() != Role.ADMIN) {
            throw ApiException.forbidden("Akaunti hii si ya admin");
        }

        // Mara ya kwanza: weka 2FA (skani QR, kisha thibitisha kwa namba)
        if (!Boolean.TRUE.equals(user.getTotpEnabled())) {
            if (user.getTotpSecret() == null) {
                user.setTotpSecret(totpService.generateSecret());
                userRepository.save(user);
            }
            long step = totpService.verify(user.getTotpSecret(), request.code(), null);
            if (step < 0) {
                if (request.code() != null && !request.code().isBlank()) {
                    throw ApiException.badRequest("Namba ya uthibitisho si sahihi. Tumia namba mpya kutoka kwenye app.");
                }
                return ApiResponse.ok("Weka 2FA kwanza", new LoginResponse("SETUP_REQUIRED", null, null,
                        user.getFullName(), totpService.otpauthUrl(user.getTotpSecret(), user.getPhone()),
                        user.getTotpSecret()));
            }
            user.setTotpEnabled(true);
            user.setTotpLastStep(step);
            userRepository.save(user);
            auditService.record(user, user.getPhone(), "ADMIN_2FA_ENABLED", "USER", user.getId(), null);
            return ApiResponse.ok("2FA imewashwa. Karibu!", success(user));
        }

        if (request.code() == null || request.code().isBlank()) {
            return ApiResponse.ok("Weka namba ya 2FA",
                    new LoginResponse("CODE_REQUIRED", null, null, user.getFullName(), null, null));
        }

        long step = totpService.verify(user.getTotpSecret(), request.code(), user.getTotpLastStep());
        if (step < 0) {
            auditService.record(user, user.getPhone(), "ADMIN_LOGIN_FAILED", null, null, "Namba ya 2FA si sahihi");
            throw ApiException.badRequest("Namba ya 2FA si sahihi au imeshatumika");
        }
        user.setTotpLastStep(step);
        userRepository.save(user);
        return ApiResponse.ok("Karibu", success(user));
    }

    private LoginResponse success(User user) {
        auditService.record(user, user.getPhone(), "ADMIN_LOGIN", null, null, null);
        String token = jwtUtil.generateToken(user.getId(), user.getPhone(), user.getRole().name(), ADMIN_TOKEN_MS);
        return new LoginResponse("OK", token, user.getId(), user.getFullName(), null, null);
    }
}
