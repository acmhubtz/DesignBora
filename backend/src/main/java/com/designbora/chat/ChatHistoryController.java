package com.designbora.chat;

import com.designbora.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class ChatHistoryController {

    private final ChatMessageRepository chatMessageRepository;

    @GetMapping("/api/orders/{orderId}/messages")
    public ApiResponse<List<ChatMessage>> history(@PathVariable Long orderId) {
        return ApiResponse.ok(chatMessageRepository.findByOrderIdOrderBySentAtAsc(orderId));
    }
}