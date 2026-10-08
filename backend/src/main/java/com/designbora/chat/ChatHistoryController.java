package com.designbora.chat;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.user.Role;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class ChatHistoryController {

    private final ChatMessageRepository chatMessageRepository;
    private final OrderService orderService;
    private final UserRepository userRepository;

    @GetMapping("/api/orders/{orderId}/messages")
    public ApiResponse<List<ChatController.ChatMessageResponse>> history(@PathVariable Long orderId) {
        Order order = orderService.getOrderOrThrow(orderId);

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User user = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));

        boolean isAdmin = user.getRole() == Role.ADMIN;
        boolean isCustomer = order.getCustomer() != null && order.getCustomer().getId().equals(user.getId());
        boolean isDesigner = order.getDesigner() != null && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(user.getId());
        if (!isAdmin && !isCustomer && !isDesigner) {
            throw ApiException.forbidden("Huna ruhusa ya kuona chat ya oda hii");
        }

        List<ChatController.ChatMessageResponse> messages = chatMessageRepository
                .findByOrderIdOrderBySentAtAsc(orderId).stream()
                .map(ChatAttachmentController::toResponse)
                .toList();
        return ApiResponse.ok(messages);
    }
}
