package com.designbora.admin;

import com.designbora.user.User;
import com.designbora.user.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

@Service
@RequiredArgsConstructor
public class AdminAuditService {

    private final AdminAuditLogRepository auditLogRepository;
    private final UserRepository userRepository;

    /** Kitendo cha admin aliyeingia sasa */
    public void record(String action, String targetType, Long targetId, String details) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User admin = auth == null ? null : userRepository.findByPhone(auth.getName()).orElse(null);
        record(admin, auth == null ? null : auth.getName(), action, targetType, targetId, details);
    }

    public void record(User admin, String phone, String action, String targetType, Long targetId, String details) {
        auditLogRepository.save(AdminAuditLog.builder()
                .adminUserId(admin == null ? null : admin.getId())
                .adminPhone(admin != null ? admin.getPhone() : shorten(phone, 20))
                .action(action)
                .targetType(targetType)
                .targetId(targetId)
                .details(shorten(details, 500))
                .ipAddress(currentIp())
                .build());
    }

    private static String currentIp() {
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attrs) {
            HttpServletRequest request = attrs.getRequest();
            return shorten(request.getRemoteAddr(), 64);
        }
        return null;
    }

    private static String shorten(String text, int max) {
        if (text == null) return null;
        return text.length() > max ? text.substring(0, max) : text;
    }
}
