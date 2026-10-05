package com.designbora.offering;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

/** Mbunifu anahariri huduma yake (oda za zamani hazibadiliki - bei yake ilihifadhiwa) */
@RestController
@RequestMapping("/api/services")
@RequiredArgsConstructor
public class ServiceEditController {

    private final ServiceOfferingRepository serviceOfferingRepository;
    private final UserRepository userRepository;

    public record UpdateRequest(String title, String description, BigDecimal price, Integer deliveryDays) {
    }

    @PutMapping("/{id}")
    public ApiResponse<ServiceOffering> update(@PathVariable Long id, @RequestBody UpdateRequest request) {
        ServiceOffering service = serviceOfferingRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Huduma haijapatikana"));

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User user = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
        if (service.getDesigner() == null || service.getDesigner().getUser() == null
                || !service.getDesigner().getUser().getId().equals(user.getId())) {
            throw ApiException.forbidden("Unaweza kuhariri huduma zako tu");
        }

        String title = request.title() == null ? "" : request.title().trim();
        if (title.length() < 5 || title.length() > 150) {
            throw ApiException.badRequest("Jina la huduma liwe herufi 5 hadi 150");
        }
        if (request.price() == null || request.price().compareTo(new BigDecimal("1000")) < 0) {
            throw ApiException.badRequest("Bei ya chini ni TSh 1,000");
        }
        if (request.deliveryDays() == null || request.deliveryDays() < 1 || request.deliveryDays() > 90) {
            throw ApiException.badRequest("Muda wa kukamilisha uwe siku 1 hadi 90");
        }

        service.setTitle(title);
        service.setDescription(request.description() == null || request.description().isBlank()
                ? null : request.description().trim());
        service.setPrice(request.price());
        service.setDeliveryDays(request.deliveryDays());
        return ApiResponse.ok("Huduma imesasishwa", serviceOfferingRepository.save(service));
    }
}
