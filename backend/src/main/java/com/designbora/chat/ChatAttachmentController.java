package com.designbora.chat;

import com.designbora.common.ApiException;
import com.designbora.notification.NotificationService;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.order.OrderStatus;
import com.designbora.user.Role;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Faili za chat (mteja NA mbunifu): mifano, maelezo, logo ya zamani...
 * Hazihusiani na drafts - draft inatumwa na mbunifu tu kupitia /drafts.
 */
@RestController
@RequestMapping("/api/orders/{orderId}")
@RequiredArgsConstructor
public class ChatAttachmentController {

    private static final long MAX_BYTES = 25L * 1024 * 1024;

    private final OrderService orderService;
    private final UserRepository userRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final NotificationService notificationService;

    @Value("${app.storage.base-path:./storage}")
    private String basePath;

    @PostMapping(value = "/attachments", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, Object>> upload(@PathVariable Long orderId,
                                                      @RequestParam("file") MultipartFile file,
                                                      @RequestParam(value = "caption", required = false) String caption)
            throws IOException {
        User me = currentUser();
        Order order = orderService.getOrderOrThrow(orderId);
        boolean isCustomer = isCustomer(order, me);
        boolean isDesigner = isDesigner(order, me);
        if (!isCustomer && !isDesigner) {
            throw ApiException.forbidden("Huna ruhusa kwenye oda hii");
        }
        if (order.getStatus() == OrderStatus.PENDING_PAYMENT || order.getStatus() == OrderStatus.CANCELLED) {
            throw ApiException.conflict("Oda hii haipokei mafaili kwa sasa");
        }
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("Chagua faili");
        }
        if (file.getSize() > MAX_BYTES) {
            throw ApiException.badRequest("Faili lisizidi MB 25");
        }

        String name = sanitize(file.getOriginalFilename());
        Path dir = Paths.get(basePath, "attachments", String.valueOf(orderId)).toAbsolutePath().normalize();
        Files.createDirectories(dir);
        Path target = dir.resolve(UUID.randomUUID() + "_" + name);
        file.transferTo(target);

        String text = caption != null && !caption.isBlank() ? caption.trim() : "📎 " + name;
        ChatMessage saved = chatMessageRepository.save(ChatMessage.builder()
                .order(order)
                .sender(me)
                .message(text)
                .attachmentPath(target.toString())
                .attachmentName(name)
                .attachmentSize(file.getSize())
                .attachmentType(file.getContentType())
                .build());

        ChatController.ChatMessageResponse response = toResponse(saved);
        messagingTemplate.convertAndSend("/topic/chat/" + orderId, response);

        String preview = "📎 " + name;
        if (!isCustomer) notificationService.toCustomer(order, "CHAT_MESSAGE", me.getFullName(), preview);
        if (!isDesigner) notificationService.toDesigner(order, "CHAT_MESSAGE", me.getFullName(), preview);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", true);
        body.put("data", response);
        return ResponseEntity.ok(body);
    }

    @GetMapping("/messages/{messageId}/file")
    public ResponseEntity<Resource> download(@PathVariable Long orderId, @PathVariable Long messageId)
            throws IOException {
        User me = currentUser();
        Order order = orderService.getOrderOrThrow(orderId);
        if (!isCustomer(order, me) && !isDesigner(order, me) && me.getRole() != Role.ADMIN) {
            throw ApiException.forbidden("Huna ruhusa kwenye oda hii");
        }
        ChatMessage m = chatMessageRepository.findById(messageId)
                .filter(x -> x.getOrder().getId().equals(orderId) && x.getAttachmentPath() != null)
                .orElseThrow(() -> ApiException.notFound("Faili halijapatikana"));

        Path path = Paths.get(m.getAttachmentPath());
        if (!Files.exists(path)) {
            throw ApiException.notFound("Faili halipatikani tena kwenye server");
        }
        MediaType type;
        try {
            type = m.getAttachmentType() == null ? MediaType.APPLICATION_OCTET_STREAM
                    : MediaType.parseMediaType(m.getAttachmentType());
        } catch (Exception e) {
            type = MediaType.APPLICATION_OCTET_STREAM;
        }
        return ResponseEntity.ok()
                .contentType(type)
                .contentLength(Files.size(path))
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(m.getAttachmentName(), StandardCharsets.UTF_8).build().toString())
                .body(new FileSystemResource(path));
    }

    /** Ujumbe -> jibu la chat (pamoja na faili kama lipo) */
    public static ChatController.ChatMessageResponse toResponse(ChatMessage m) {
        ChatController.ChatMessageResponse r = new ChatController.ChatMessageResponse(
                m.getId(), m.getSender().getId(), m.getSender().getFullName(),
                m.getMessage(), m.getSentAt() == null ? "" : m.getSentAt().toString());
        if (m.getAttachmentName() != null) {
            r.setAttachmentId(m.getId());
            r.setAttachmentName(m.getAttachmentName());
            r.setAttachmentSize(m.getAttachmentSize());
            r.setAttachmentType(m.getAttachmentType());
            r.setAttachmentUrl("/orders/" + m.getOrder().getId() + "/messages/" + m.getId() + "/file");
        }
        return r;
    }

    private static String sanitize(String name) {
        String n = name == null || name.isBlank() ? "faili" : name;
        n = n.replaceAll("[\\\\/:*?\"<>|\\r\\n]", "_").trim();
        return n.length() > 120 ? n.substring(n.length() - 120) : n;
    }

    private static boolean isCustomer(Order o, User u) {
        return o.getCustomer() != null && o.getCustomer().getId().equals(u.getId());
    }

    private static boolean isDesigner(Order o, User u) {
        return o.getDesigner() != null && o.getDesigner().getUser() != null
                && o.getDesigner().getUser().getId().equals(u.getId());
    }

    private User currentUser() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) throw ApiException.forbidden("Ingia kwanza");
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
