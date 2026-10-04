package com.designbora.user;

import com.designbora.common.ApiResponse;
import com.designbora.user.dto.AuthDtos.AuthResponse;
import com.designbora.user.dto.AuthDtos.ForgotPasswordRequest;
import com.designbora.user.dto.AuthDtos.ForgotPasswordResponse;
import com.designbora.user.dto.AuthDtos.LoginRequest;
import com.designbora.user.dto.AuthDtos.RegisterRequest;
import com.designbora.user.dto.AuthDtos.ResetPasswordRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ApiResponse<AuthResponse> register(@Valid @RequestBody RegisterRequest req) {
        return ApiResponse.ok("Usajili umefanikiwa", authService.register(req));
    }

    @PostMapping("/login")
    public ApiResponse<AuthResponse> login(@Valid @RequestBody LoginRequest req) {
        return ApiResponse.ok("Umeingia", authService.login(req));
    }

    @PostMapping("/forgot-password")
    public ApiResponse<ForgotPasswordResponse> forgotPassword(@Valid @RequestBody ForgotPasswordRequest req) {
        ForgotPasswordResponse response = authService.forgotPassword(req);
        return ApiResponse.ok(response.getMessage(), response);
    }

    @PostMapping("/reset-password")
    public ApiResponse<Void> resetPassword(@Valid @RequestBody ResetPasswordRequest req) {
        authService.resetPassword(req);
        return ApiResponse.ok("Nenosiri limebadilishwa. Sasa unaweza kuingia.", null);
    }

    @GetMapping("/me")
    public String whoAmI(java.security.Principal principal) {
        return "Umeingia kama: " + principal.getName();
    }
}
