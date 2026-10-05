package com.designbora.chat;

import com.designbora.order.Order;
import com.designbora.order.OrderRepository;
import com.designbora.user.Role;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

import java.security.Principal;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Inaruhusu kujiunga (SUBSCRIBE) na /topic/chat/{orderId} kwa wahusika wa oda tu:
 * mteja, mbunifu, au admin. Topic nyingine zote chini ya /topic zinakataliwa.
 */
@Component
@RequiredArgsConstructor
public class ChatSubscriptionGuard implements ChannelInterceptor {

    private static final Pattern CHAT_TOPIC = Pattern.compile("^/topic/chat/(\\d+)$");

    private final UserRepository userRepository;
    private final OrderRepository orderRepository;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null || accessor.getCommand() != StompCommand.SUBSCRIBE) {
            return message;
        }

        String destination = accessor.getDestination();
        Matcher matcher = destination == null ? null : CHAT_TOPIC.matcher(destination);
        if (matcher == null || !matcher.matches()) {
            throw new MessagingException("Destination hairuhusiwi: " + destination);
        }

        Principal principal = accessor.getUser();
        if (principal == null) {
            throw new MessagingException("Ingia kwanza");
        }
        User user = userRepository.findByPhone(principal.getName())
                .orElseThrow(() -> new MessagingException("Mtumiaji hajapatikana"));
        Order order = orderRepository.findById(Long.valueOf(matcher.group(1)))
                .orElseThrow(() -> new MessagingException("Oda haijapatikana"));

        boolean isAdmin = user.getRole() == Role.ADMIN;
        boolean isCustomer = order.getCustomer() != null && order.getCustomer().getId().equals(user.getId());
        boolean isDesigner = order.getDesigner() != null && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(user.getId());

        if (!isAdmin && !isCustomer && !isDesigner) {
            throw new MessagingException("Huna ruhusa ya kusikiliza chat ya oda hii");
        }
        return message;
    }
}
