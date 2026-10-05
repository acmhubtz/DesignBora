package com.designbora.notification;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;

    public record DeviceRequest(String token, String platform) {
    }

    /** Simu inajisajili baada ya login (au token ikibadilika) */
    @PostMapping
    public ApiResponse<String> register(@RequestBody DeviceRequest request) {
        String token = request.token() == null ? "" : request.token().trim();
        if (token.length() < 20 || token.length() > 512) {
            throw ApiException.badRequest("Token ya kifaa si sahihi");
        }
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User user = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));

        DeviceToken device = deviceTokenRepository.findByToken(token)
                .orElseGet(() -> DeviceToken.builder().token(token).build());
        device.setUser(user); // simu ikibadilisha mtumiaji, arifa zinamfuata aliyeingia sasa
        device.setPlatform(request.platform() == null ? "android" : request.platform());
        device.setUpdatedAt(LocalDateTime.now());
        deviceTokenRepository.save(device);
        return ApiResponse.ok("Kifaa kimesajiliwa", "OK");
    }

    /** Logout: simu hii isipokee arifa za mtumiaji huyu tena */
    @DeleteMapping
    public ApiResponse<String> unregister(@RequestBody DeviceRequest request) {
        if (request.token() != null && !request.token().isBlank()) {
            deviceTokenRepository.deleteByToken(request.token().trim());
        }
        return ApiResponse.ok("Kifaa kimeondolewa", "OK");
    }
}
