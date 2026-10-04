package com.designbora.offering;

import com.designbora.category.Category;
import com.designbora.category.CategoryRepository;
import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/services")
@RequiredArgsConstructor
public class ServiceOfferingController {

    private final ServiceOfferingRepository serviceOfferingRepository;
    private final DesignerProfileRepository designerProfileRepository;
    private final CategoryRepository categoryRepository;
    private final UserRepository userRepository;

    @GetMapping("/designer/{designerId}")
    public ApiResponse<List<ServiceOffering>> byDesigner(@PathVariable Long designerId) {
        return ApiResponse.ok(serviceOfferingRepository.findByDesignerIdAndActiveTrue(designerId));
    }

    @PostMapping
    public ApiResponse<ServiceOffering> create(@RequestBody CreateServiceRequest req) {
        User currentUser = getCurrentUser();

        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));

        if (!designer.isVerified()) {
            throw ApiException.forbidden("Akaunti yako lazima ithibitishwe (verified) kabla ya kuongeza huduma");
        }

        Category category = categoryRepository.findById(req.getCategoryId())
                .orElseThrow(() -> ApiException.notFound("Category haipo"));

        ServiceOffering service = ServiceOffering.builder()
                .designer(designer)
                .category(category)
                .title(req.getTitle())
                .description(req.getDescription())
                .price(req.getPrice())
                .deliveryDays(req.getDeliveryDays())
                .active(true)
                .build();

        return ApiResponse.ok("Huduma imeongezwa", serviceOfferingRepository.save(service));
    }

    @PatchMapping("/{id}/toggle")
    public ApiResponse<ServiceOffering> toggleActive(@PathVariable Long id) {
        User currentUser = getCurrentUser();

        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));

        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Huduma haipo"));

        if (!service.getDesigner().getId().equals(designer.getId())) {
            throw ApiException.forbidden("Huduma hii si yako");
        }

        service.setActive(!service.isActive());
        return ApiResponse.ok(serviceOfferingRepository.save(service));
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String phone = auth.getName();
        return userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }

    @Data
    public static class CreateServiceRequest {
        private Long categoryId;
        private String title;
        private String description;
        private BigDecimal price;
        private Integer deliveryDays;
    }
}