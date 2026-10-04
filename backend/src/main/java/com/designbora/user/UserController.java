package com.designbora.user;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.media.MediaStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Locale;
import java.util.Set;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private static final Set<String> AVATAR_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp");
    private static final long MAX_AVATAR_SIZE = 5L * 1024 * 1024; // 5MB

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final MediaStorageService mediaStorageService;

    public record ProfileResponse(Long id, String fullName, String email, String phone,
                                  String role, String avatarUrl) {
        static ProfileResponse from(User u) {
            return new ProfileResponse(u.getId(), u.getFullName(), u.getEmail(), u.getPhone(),
                    u.getRole().name(), u.getAvatarUrl());
        }
    }

    public record UpdateProfileRequest(String fullName, String email) {
    }

    public record ChangePasswordRequest(String currentPassword, String newPassword) {
    }

    @GetMapping("/me")
    public ApiResponse<ProfileResponse> me() {
        return ApiResponse.ok(ProfileResponse.from(getCurrentUser()));
    }

    @PutMapping("/me")
    public ApiResponse<ProfileResponse> updateMe(@RequestBody UpdateProfileRequest request) {
        User user = getCurrentUser();

        String fullName = request.fullName() == null ? "" : request.fullName().trim();
        if (fullName.isEmpty() || fullName.length() > 150) {
            throw ApiException.badRequest("Jina linahitajika (herufi 1 hadi 150)");
        }

        String email = request.email() == null ? "" : request.email().trim().toLowerCase(Locale.ROOT);
        if (!email.isEmpty() && (!email.contains("@") || email.length() > 150)) {
            throw ApiException.badRequest("Barua pepe si sahihi");
        }

        user.setFullName(fullName);
        user.setEmail(email.isEmpty() ? null : email);
        try {
            user = userRepository.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw ApiException.conflict("Barua pepe hii tayari inatumiwa na akaunti nyingine");
        }
        return ApiResponse.ok("Wasifu umesasishwa", ProfileResponse.from(user));
    }

    @PostMapping("/me/password")
    public ApiResponse<String> changePassword(@RequestBody ChangePasswordRequest request) {
        User user = getCurrentUser();

        if (request.currentPassword() == null
                || !passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
            throw ApiException.badRequest("Nenosiri la sasa si sahihi");
        }
        String newPassword = request.newPassword() == null ? "" : request.newPassword();
        if (newPassword.length() < 6) {
            throw ApiException.badRequest("Nenosiri jipya liwe angalau herufi 6");
        }
        if (passwordEncoder.matches(newPassword, user.getPasswordHash())) {
            throw ApiException.badRequest("Nenosiri jipya lisifanane na la zamani");
        }

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        return ApiResponse.ok("Nenosiri limebadilishwa", "OK");
    }

    @PostMapping(value = "/me/avatar", consumes = "multipart/form-data")
    public ApiResponse<ProfileResponse> uploadAvatar(@RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("Chagua picha");
        }
        if (file.getSize() > MAX_AVATAR_SIZE) {
            throw ApiException.badRequest("Picha ni kubwa mno. Kikomo ni 5MB");
        }
        String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase(Locale.ROOT);
        String extension = name.contains(".") ? name.substring(name.lastIndexOf('.') + 1) : "";
        if (!AVATAR_EXTENSIONS.contains(extension)) {
            throw ApiException.badRequest("Tumia picha ya JPG, PNG au WEBP");
        }

        User user = getCurrentUser();
        user.setAvatarUrl(mediaStorageService.saveAvatarFile(file));
        return ApiResponse.ok("Picha ya wasifu imewekwa", ProfileResponse.from(userRepository.save(user)));
    }

    @DeleteMapping("/me/avatar")
    public ApiResponse<ProfileResponse> removeAvatar() {
        User user = getCurrentUser();
        user.setAvatarUrl(null);
        return ApiResponse.ok("Picha ya wasifu imeondolewa", ProfileResponse.from(userRepository.save(user)));
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
