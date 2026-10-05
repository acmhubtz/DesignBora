package com.designbora.review;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

/** App inakagua kama oda tayari ina maoni (ili isimwombe mteja mara mbili) */
@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class ReviewOrderController {

    private final ReviewRepository reviewRepository;
    private final OrderService orderService;
    private final UserRepository userRepository;

    public record ReviewView(Long id, Integer starRating, String comment, boolean deliveredOnTime,
                             LocalDateTime createdAt) {
    }

    @GetMapping("/order/{orderId}")
    public ApiResponse<ReviewView> forOrder(@PathVariable Long orderId) {
        Order order = orderService.getOrderOrThrow(orderId);
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User user = auth == null ? null : userRepository.findByPhone(auth.getName()).orElse(null);
        if (user == null) {
            throw ApiException.forbidden("Ingia kwanza");
        }
        boolean isCustomer = order.getCustomer() != null && order.getCustomer().getId().equals(user.getId());
        boolean isDesigner = order.getDesigner() != null && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(user.getId());
        if (!isCustomer && !isDesigner) {
            throw ApiException.forbidden("Huna ruhusa kwa oda hii");
        }
        return ApiResponse.ok(reviewRepository.findFirstByOrderId(orderId)
                .map(r -> new ReviewView(r.getId(), r.getStarRating(), r.getComment(),
                        r.isDeliveredOnTime(), r.getCreatedAt()))
                .orElse(null));
    }
}
