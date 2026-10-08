package com.designbora.chat;

import com.designbora.common.ApiException;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;

import java.security.Principal;

@Controller
@RequiredArgsConstructor
public class ChatController {

    private final ChatMessageRepository chatMessageRepository;
    private final UserRepository userRepository;
    private final OrderService orderService;
    private final SimpMessagingTemplate messagingTemplate;
    private final com.designbora.notification.NotificationService notificationService;

    @MessageMapping("/chat.send/{orderId}")
    public void sendMessage(@DestinationVariable Long orderId,
                             ChatMessageRequest request,
                             Principal principal) {

        String phone = principal.getName();
        User sender = userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));

        Order order = orderService.getOrderOrThrow(orderId);

        boolean isCustomer = order.getCustomer() != null && order.getCustomer().getId().equals(sender.getId());
        boolean isDesigner = order.getDesigner() != null && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(sender.getId());
        boolean isAdmin = sender.getRole() == com.designbora.user.Role.ADMIN;
        if (!isCustomer && !isDesigner && !isAdmin) {
            throw ApiException.forbidden("Huna ruhusa ya kutuma ujumbe kwenye oda hii");
        }
        if (request.getMessage() == null || request.getMessage().isBlank()) {
            return;
        }

        ChatMessage message = ChatMessage.builder()
                .order(order)
                .sender(sender)
                .message(request.getMessage())
                .build();

        ChatMessage saved = chatMessageRepository.save(message);

        ChatMessageResponse response = new ChatMessageResponse(
                saved.getId(), sender.getId(), sender.getFullName(),
                saved.getMessage(), saved.getSentAt().toString());

        messagingTemplate.convertAndSend("/topic/chat/" + orderId, response);

        String preview = saved.getMessage().length() > 120 ? saved.getMessage().substring(0, 120) + "…" : saved.getMessage();
        if (!isCustomer) notificationService.toCustomer(order, "CHAT_MESSAGE", sender.getFullName(), preview);
        if (!isDesigner) notificationService.toDesigner(order, "CHAT_MESSAGE", sender.getFullName(), preview);
    }

    @Data
    public static class ChatMessageRequest {
        private String message;
    }

    @Data
    public static class ChatMessageResponse {
        private final Long id;
        private final Long senderId;
        private final String senderName;
        private final String message;
        private final String sentAt;
        // Faili (kama lipo): GET /api/orders/{orderId}/messages/{attachmentId}/file
        private Long attachmentId;
        private String attachmentName;
        private Long attachmentSize;
        private String attachmentType;
        private String attachmentUrl;
    }
}