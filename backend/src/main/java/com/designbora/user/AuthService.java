package com.designbora.user;

import com.designbora.common.ApiException;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.designer.metrics.DesignerMetrics;
import com.designbora.designer.metrics.DesignerMetricsRepository;
import com.designbora.security.JwtUtil;
import com.designbora.user.dto.AuthDtos.AuthResponse;
import com.designbora.user.dto.AuthDtos.ForgotPasswordRequest;
import com.designbora.user.dto.AuthDtos.ForgotPasswordResponse;
import com.designbora.user.dto.AuthDtos.LoginRequest;
import com.designbora.user.dto.AuthDtos.RegisterRequest;
import com.designbora.user.dto.AuthDtos.ResetPasswordRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final DesignerProfileRepository designerProfileRepository;
    private final DesignerMetricsRepository designerMetricsRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int CODE_VALID_MINUTES = 15;

    /** DEV ONLY: kurudisha code ya reset kwenye jibu. LAZIMA iwe false kwenye production (tumia SMS). */
    @Value("${app.dev.expose-reset-code:true}")
    private boolean exposeResetCode;

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        if (userRepository.existsByPhone(req.getPhone())) {
            throw ApiException.conflict("Namba ya simu tayari imesajiliwa");
        }

        if (req.getEmail() != null && !req.getEmail().isBlank()
                && userRepository.existsByEmail(req.getEmail())) {
            throw ApiException.conflict("Barua pepe tayari imesajiliwa");
        }

        if (req.getRole() == null || req.getRole() == Role.ADMIN) {
            throw ApiException.forbidden("Aina hii ya akaunti hairuhusiwi kusajiliwa");
        }

        if (req.getRole() == Role.DESIGNER && req.getAccountType() == null) {
            throw ApiException.badRequest("Chagua aina ya designer: Individual au Company");
        }

        User user = User.builder()
                .fullName(req.getFullName())
                .email((req.getEmail() == null || req.getEmail().isBlank()) ? null : req.getEmail())
                .phone(req.getPhone())
                .passwordHash(passwordEncoder.encode(req.getPassword()))
                .role(req.getRole())
                .active(true)
                .build();

        user = userRepository.save(user);

        if (req.getRole() == Role.DESIGNER) {
            DesignerProfile profile = DesignerProfile.builder()
                    .user(user)
                    .accountType(req.getAccountType())
                    .companyName(req.getCompanyName())
                    .companyRegNumber(req.getCompanyRegNumber())
                    .experienceYears(0)
                    .build();
            profile = designerProfileRepository.save(profile);

            DesignerMetrics metrics = DesignerMetrics.builder()
                    .designerId(profile.getId())
                    .build();
            designerMetricsRepository.save(metrics);
        }

        String token = jwtUtil.generateToken(user.getId(), user.getPhone(), user.getRole().name());
        return new AuthResponse(token, user.getId(), user.getFullName(), user.getRole());
    }

    public AuthResponse login(LoginRequest req) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.getPhone(), req.getPassword())
        );

        User user = userRepository.findByPhone(req.getPhone())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));

        if (user.getRole() == Role.ADMIN) {
            throw ApiException.forbidden("Akaunti za admin zinaingia kupitia Admin Panel ya web");
        }

        String token = jwtUtil.generateToken(user.getId(), user.getPhone(), user.getRole().name());
        return new AuthResponse(token, user.getId(), user.getFullName(), user.getRole());
    }

    /**
     * Hatua ya 1 ya Forgot Password: mtumiaji anatuma namba ya simu, tunazalisha
     * code ya nasibu ya tarakimu 6 na kuihifadhi (ikiwa na muda wa kuisha).
     * Kwa PRODUCTION: code hii itumwe kwa SMS pekee, si kurudishwa kwenye response.
     */
    @Transactional
    public ForgotPasswordResponse forgotPassword(ForgotPasswordRequest req) {
        User user = userRepository.findByPhone(req.getPhone())
                .orElseThrow(() -> ApiException.notFound("Hakuna akaunti yenye namba hii ya simu"));

        if (user.getRole() == Role.ADMIN) {
            throw ApiException.forbidden("Nenosiri la admin haliwezi kubadilishwa kwa njia hii");
        }

        String code = generateSixDigitCode();

        PasswordResetToken resetToken = PasswordResetToken.builder()
                .user(user)
                .code(code)
                .expiresAt(LocalDateTime.now().plusMinutes(CODE_VALID_MINUTES))
                .used(false)
                .build();
        passwordResetTokenRepository.save(resetToken);

        // TODO (production): tuma 'code' kwa SMS hapa (Selcom/AzamPay SMS gateway, n.k.)
        // badala ya kuirudisha kwenye response.

        return new ForgotPasswordResponse(
                "Code ya kubadilisha nenosiri imetumwa (itaisha muda baada ya dakika " + CODE_VALID_MINUTES + ")",
                exposeResetCode ? code : null // DEV ONLY: weka app.dev.expose-reset-code=false kwenye production
        );
    }

    /**
     * Hatua ya 2: mtumiaji anathibitisha code aliyopokea na kuweka password mpya.
     */
    @Transactional
    public void resetPassword(ResetPasswordRequest req) {
        User user = userRepository.findByPhone(req.getPhone())
                .orElseThrow(() -> ApiException.notFound("Hakuna akaunti yenye namba hii ya simu"));

        if (user.getRole() == Role.ADMIN) {
            throw ApiException.forbidden("Nenosiri la admin haliwezi kubadilishwa kwa njia hii");
        }

        PasswordResetToken resetToken = passwordResetTokenRepository
                .findTopByUserIdAndCodeAndUsedFalseOrderByIdDesc(user.getId(), req.getCode())
                .orElseThrow(() -> ApiException.badRequest("Code si sahihi au tayari imetumika"));

        if (resetToken.isExpired()) {
            throw ApiException.badRequest("Code imeisha muda. Omba code mpya.");
        }

        user.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        userRepository.save(user);

        resetToken.setUsed(true);
        passwordResetTokenRepository.save(resetToken);
    }

    private String generateSixDigitCode() {
        int number = 100000 + RANDOM.nextInt(900000);
        return String.valueOf(number);
    }
}
