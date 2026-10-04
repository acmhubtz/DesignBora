package com.designbora.user.dto;

import com.designbora.user.Role;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

public class AuthDtos {

    @Data
    public static class RegisterRequest {
        @NotBlank(message = "Jina kamili linahitajika")
        private String fullName;

        private String email; // hiari

        @NotBlank(message = "Namba ya simu inahitajika")
        private String phone;

        @NotBlank
        @Size(min = 6, message = "Nenosiri liwe angalau herufi 6")
        private String password;

        @NotNull(message = "Chagua aina ya akaunti: CUSTOMER au DESIGNER")
        private Role role;

        // Fields hizi zinahitajika TU kama role == DESIGNER
        private com.designbora.designer.AccountType accountType;
        private String companyName;
        private String companyRegNumber;
    }

    @Data
    public static class LoginRequest {
        @NotBlank
        private String phone;
        @NotBlank
        private String password;
    }

    @Data
    public static class AuthResponse {
        private String token;
        private Long userId;
        private String fullName;
        private Role role;

        public AuthResponse(String token, Long userId, String fullName, Role role) {
            this.token = token;
            this.userId = userId;
            this.fullName = fullName;
            this.role = role;
        }
    }

    @Data
    public static class ForgotPasswordRequest {
        @NotBlank(message = "Namba ya simu inahitajika")
        private String phone;
    }

    @Data
    public static class ForgotPasswordResponse {
        private final String message;
        // Kwa DEVELOPMENT TU - code inaonekana moja kwa moja hapa.
        // Kwenye PRODUCTION, ondoa field hii kabisa - code itatumwa kwa SMS pekee.
        private final String devCode;
    }

    @Data
    public static class ResetPasswordRequest {
        @NotBlank(message = "Namba ya simu inahitajika")
        private String phone;

        @NotBlank(message = "Code inahitajika")
        private String code;

        @NotBlank
        @Size(min = 6, message = "Nenosiri jipya liwe angalau herufi 6")
        private String newPassword;
    }
}
