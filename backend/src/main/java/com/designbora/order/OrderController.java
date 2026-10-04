package com.designbora.order;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;
    private final UserRepository userRepository;

    @PostMapping
    public ApiResponse<Order> create(@RequestBody CreateOrderRequest req) {
        return ApiResponse.ok("Order imeundwa - endelea na malipo", orderService.createOrder(req.getServiceId()));
    }

    @GetMapping("/mine/customer")
    public ApiResponse<List<Order>> myOrdersAsCustomer() {
        return ApiResponse.ok(orderService.myOrdersAsCustomer());
    }

    @GetMapping("/mine/designer")
    public ApiResponse<List<Order>> myOrdersAsDesigner() {
        return ApiResponse.ok(orderService.myOrdersAsDesigner());
    }

    @GetMapping("/{id}")
    public ApiResponse<Order> get(@PathVariable Long id) {
        Order order = orderService.getOrderOrThrow(id);
        User user = getCurrentUser();
        if (!isCustomerOf(order, user) && !isDesignerOf(order, user)) {
            throw ApiException.forbidden("Huna ruhusa kwa order hii");
        }
        return ApiResponse.ok(order);
    }

    // mark-paid na start ZIMEONDOLEWA: sasa zinafanywa na PaymentService tu baada ya malipo kuthibitishwa.
    // submit-draft IMEONDOLEWA: inafanywa na DraftController faili linapopakiwa.

    @PostMapping("/{id}/confirm-completion")
    public ApiResponse<Order> confirmCompletion(@PathVariable Long id) {
        Order order = orderService.getOrderOrThrow(id);
        if (!isCustomerOf(order, getCurrentUser())) {
            throw ApiException.forbidden("Mteja wa order hii pekee ndiye anaweza kuthibitisha");
        }
        return ApiResponse.ok("Umethibitisha! Malipo yatatolewa kwa designer", orderService.confirmCompletion(id));
    }

    // ---------- Wasaidizi ----------

    private boolean isCustomerOf(Order order, User user) {
        return order.getCustomer() != null && order.getCustomer().getId().equals(user.getId());
    }

    private boolean isDesignerOf(Order order, User user) {
        return order.getDesigner() != null
                && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(user.getId());
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }

    @Data
    public static class CreateOrderRequest {
        private Long serviceId;
    }
}
