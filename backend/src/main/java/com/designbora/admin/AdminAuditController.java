package com.designbora.admin;

import com.designbora.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/audit-logs")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminAuditController {

    private final AdminAuditLogRepository auditLogRepository;

    @GetMapping
    public ApiResponse<List<AdminAuditLog>> latest() {
        return ApiResponse.ok(auditLogRepository.findTop200ByOrderByIdDesc());
    }
}
