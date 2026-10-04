package com.designbora.designer;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.metrics.DesignerMetrics;
import com.designbora.designer.metrics.DesignerMetricsRepository;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/designers")
@RequiredArgsConstructor
public class DesignerController {

    private final DesignerProfileRepository designerProfileRepository;
    private final DesignerMetricsRepository designerMetricsRepository;
    private final UserRepository userRepository;

    @GetMapping("/me")
    public ApiResponse<DesignerMeDto> myProfile() {
        User currentUser = getCurrentUser();

        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));

        DesignerMetrics metrics = designerMetricsRepository.findById(designer.getId())
                .orElseGet(() -> DesignerMetrics.builder().designerId(designer.getId()).build());

        String displayName = designer.getAccountType() == AccountType.COMPANY
                ? designer.getCompanyName()
                : currentUser.getFullName();

        DesignerMeDto dto = DesignerMeDto.builder()
                .designerId(designer.getId())
                .displayName(displayName)
                .accountType(designer.getAccountType().name())
                .verificationStatus(designer.getVerificationStatus().name())
                .verified(designer.isVerified())
                .compositeScore(metrics.getCompositeScore())
                .avgStarRating(metrics.getAvgStarRating())
                .completedOrders(metrics.getCompletedOrders())
                .build();

        return ApiResponse.ok(dto);
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String phone = auth.getName();
        return userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }

    @Data
    @Builder
    @AllArgsConstructor
    public static class DesignerMeDto {
        private Long designerId;
        private String displayName;
        private String accountType;
        private String verificationStatus;
        private boolean verified;
        private java.math.BigDecimal compositeScore;
        private java.math.BigDecimal avgStarRating;
        private Integer completedOrders;
    }
}
