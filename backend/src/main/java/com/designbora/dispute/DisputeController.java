package com.designbora.dispute;

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

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class DisputeController {

    private final DisputeService disputeService;
    private final DisputeRepository disputeRepository;
    private final OrderService orderService;
    private final UserRepository userRepository;

    public record OpenRequest(String reason) {
    }

    public record DisputeView(Long id, Long orderId, String status, String reason, String resolution,
                              String adminNote, LocalDateTime createdAt, LocalDateTime resolvedAt) {
        static DisputeView from(Dispute d) {
            return new DisputeView(d.getId(), d.getOrder().getId(), d.getStatus(), d.getReason(),
                    d.getResolution(), d.getAdminNote(), d.getCreatedAt(), d.getResolvedAt());
        }
    }

    @PostMapping("/{orderId}/dispute")
    public ApiResponse<DisputeView> open(@PathVariable Long orderId, @RequestBody OpenRequest request) {
        Order order = orderService.getOrderOrThrow(orderId);
        User user = currentUser();
        if (order.getCustomer() == null || !order.getCustomer().getId().equals(user.getId())) {
            throw ApiException.forbidden("Mteja wa oda hii pekee ndiye anaweza kufungua mgogoro");
        }
        return ApiResponse.ok("Mgogoro umefunguliwa", DisputeView.from(disputeService.open(order, user, request.reason())));
    }

    @GetMapping("/{orderId}/dispute")
    public ApiResponse<DisputeView> latest(@PathVariable Long orderId) {
        Order order = orderService.getOrderOrThrow(orderId);
        User user = currentUser();
        boolean isCustomer = order.getCustomer() != null && order.getCustomer().getId().equals(user.getId());
        boolean isDesigner = order.getDesigner() != null && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(user.getId());
        if (!isCustomer && !isDesigner) {
            throw ApiException.forbidden("Huna ruhusa kwa oda hii");
        }
        return ApiResponse.ok(disputeRepository.findTopByOrderIdOrderByIdDesc(orderId).map(DisputeView::from).orElse(null));
    }

    private User currentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
