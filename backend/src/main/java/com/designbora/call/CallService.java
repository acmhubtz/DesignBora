package com.designbora.call;

import com.designbora.chat.ChatController;
import com.designbora.chat.ChatMessage;
import com.designbora.chat.ChatMessageRepository;
import com.designbora.common.ApiException;
import com.designbora.notification.NotificationService;
import com.designbora.order.Order;
import com.designbora.order.OrderRepository;
import com.designbora.order.OrderStatus;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class CallService {

    public static final int RING_TIMEOUT_SECONDS = 45;
    private static final int MAX_CALL_HOURS = 3;

    private static final Set<CallStatus> ACTIVE = EnumSet.of(CallStatus.RINGING, CallStatus.ACCEPTED);
    private static final Set<OrderStatus> CALLABLE =
            EnumSet.of(OrderStatus.PAID, OrderStatus.IN_PROGRESS, OrderStatus.DRAFT_SUBMITTED);

    private final CallLogRepository callLogRepository;
    private final OrderRepository orderRepository;
    private final UserRepository userRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final SimpMessagingTemplate messagingTemplate;
    private final NotificationService notificationService;

    // ------------------------------------------------------------------ actions

    @Transactional
    public CallLog start(Long orderId) {
        User me = currentUser();
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> ApiException.notFound("Oda haijapatikana"));

        User designerUser = order.getDesigner() == null ? null : order.getDesigner().getUser();
        User other;
        if (order.getCustomer() != null && order.getCustomer().getId().equals(me.getId())) {
            other = designerUser;
        } else if (designerUser != null && designerUser.getId().equals(me.getId())) {
            other = order.getCustomer();
        } else {
            throw ApiException.forbidden("Huwezi kupiga simu kwenye oda si yako");
        }
        if (other == null) {
            throw ApiException.conflict("Mhusika mwingine wa oda hajapatikana");
        }
        if (!CALLABLE.contains(order.getStatus())) {
            throw ApiException.conflict("Simu zinawezekana kwa oda inayoendelea tu");
        }

        // Simu zangu za zamani zilizokwama (app ilifungwa ghafla) zinafungwa - naanza mpya
        for (CallLog stale : callLogRepository.findActiveForUser(me.getId(), ACTIVE)) {
            finish(stale, stale.getStatus() == CallStatus.ACCEPTED ? CallStatus.ENDED : CallStatus.MISSED, false);
        }
        if (!callLogRepository.findActiveForUser(other.getId(), ACTIVE).isEmpty()) {
            throw ApiException.conflict(other.getFullName() + " yuko kwenye simu nyingine. Jaribu baadaye.");
        }

        CallLog call = callLogRepository.save(CallLog.builder()
                .order(order)
                .caller(me)
                .callee(other)
                .status(CallStatus.RINGING)
                .createdAt(LocalDateTime.now())
                .build());

        notificationService.toUser(other.getId(), "INCOMING_CALL",
                "📞 " + me.getFullName() + " anakupigia",
                "Gusa kupokea simu ya sauti (Oda #" + orderId + ")");
        return call;
    }

    @Transactional
    public CallLog accept(Long callId) {
        User me = currentUser();
        CallLog call = getForParticipant(callId, me);
        if (!call.getCallee().getId().equals(me.getId())) {
            throw ApiException.forbidden("Anayepigiwa tu ndiye anaweza kupokea");
        }
        if (call.getStatus() != CallStatus.RINGING) {
            throw ApiException.conflict("Simu hii imeshaisha");
        }
        call.setStatus(CallStatus.ACCEPTED);
        call.setAnsweredAt(LocalDateTime.now());
        broadcast(call, "ACCEPTED");
        return call;
    }

    @Transactional
    public CallLog reject(Long callId) {
        User me = currentUser();
        CallLog call = getForParticipant(callId, me);
        if (call.getStatus() == CallStatus.RINGING && call.getCallee().getId().equals(me.getId())) {
            finish(call, CallStatus.REJECTED, false);
        }
        return call;
    }

    @Transactional
    public CallLog end(Long callId) {
        User me = currentUser();
        CallLog call = getForParticipant(callId, me);
        if (call.getStatus() == CallStatus.ACCEPTED) {
            finish(call, CallStatus.ENDED, false);
        } else if (call.getStatus() == CallStatus.RINGING) {
            boolean callerCancelled = call.getCaller().getId().equals(me.getId());
            finish(call, callerCancelled ? CallStatus.MISSED : CallStatus.REJECTED, callerCancelled);
        }
        return call; // tayari imeisha: hakuna cha kufanya
    }

    @Transactional(readOnly = true)
    public CallLog incoming() {
        User me = currentUser();
        return callLogRepository.findFirstByCalleeIdAndStatusAndCreatedAtAfterOrderByIdDesc(
                me.getId(), CallStatus.RINGING, LocalDateTime.now().minusSeconds(RING_TIMEOUT_SECONDS))
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public CallLog get(Long callId) {
        return getForParticipant(callId, currentUser());
    }

    // ------------------------------------------------------------------ scheduler

    /** Kila sekunde 15: simu zisizopokelewa ndani ya sekunde 45 -> MISSED; zilizokwama -> ENDED */
    @Scheduled(fixedDelay = 15_000, initialDelay = 20_000)
    @Transactional
    public void expireCalls() {
        LocalDateTime now = LocalDateTime.now();
        for (CallLog c : callLogRepository.findByStatusAndCreatedAtBefore(
                CallStatus.RINGING, now.minusSeconds(RING_TIMEOUT_SECONDS))) {
            finish(c, CallStatus.MISSED, true);
        }
        for (CallLog c : callLogRepository.findByStatusAndAnsweredAtBefore(
                CallStatus.ACCEPTED, now.minusHours(MAX_CALL_HOURS))) {
            finish(c, CallStatus.ENDED, false);
        }
    }

    // ------------------------------------------------------------------ helpers

    private void finish(CallLog call, CallStatus status, boolean notifyMissed) {
        call.setStatus(status);
        call.setEndedAt(LocalDateTime.now());
        callLogRepository.save(call);
        broadcast(call, status.name());

        switch (status) {
            case ENDED -> {
                long secs = call.getAnsweredAt() == null ? 0
                        : Duration.between(call.getAnsweredAt(), call.getEndedAt()).getSeconds();
                postToChat(call, String.format("📞 Simu ya sauti • %d:%02d", secs / 60, secs % 60));
            }
            case REJECTED -> postToChat(call, "📞 Simu ilikataliwa");
            case MISSED -> {
                postToChat(call, "📞 Simu haikupokelewa");
                if (notifyMissed) {
                    notificationService.toUser(call.getCallee().getId(), "MISSED_CALL",
                            "📞 Simu uliyokosa",
                            call.getCaller().getFullName() + " alikupigia (Oda #" + call.getOrder().getId() + ")");
                }
            }
            default -> { }
        }
    }

    private void broadcast(CallLog call, String type) {
        messagingTemplate.convertAndSend("/topic/call/" + call.getId(),
                (Object) Map.of("type", type, "callId", call.getId()));
    }

    private void postToChat(CallLog call, String text) {
        try {
            ChatMessage saved = chatMessageRepository.save(ChatMessage.builder()
                    .order(call.getOrder())
                    .sender(call.getCaller())
                    .message(text)
                    .build());
            messagingTemplate.convertAndSend("/topic/chat/" + call.getOrder().getId(),
                    new ChatController.ChatMessageResponse(
                            saved.getId(), call.getCaller().getId(), call.getCaller().getFullName(),
                            saved.getMessage(), saved.getSentAt().toString()));
        } catch (Exception e) {
            log.warn("Kumbukumbu ya simu {} haikuwekwa kwenye chat: {}", call.getId(), e.getMessage());
        }
    }

    private CallLog getForParticipant(Long callId, User me) {
        CallLog call = callLogRepository.findById(callId)
                .orElseThrow(() -> ApiException.notFound("Simu haijapatikana"));
        if (!call.isParticipant(me.getId())) {
            throw ApiException.forbidden("Huna ruhusa kwenye simu hii");
        }
        return call;
    }

    public User currentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) {
            throw ApiException.forbidden("Ingia kwanza");
        }
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
