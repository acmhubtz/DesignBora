package com.designbora.call;

import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * Inapitisha OFFER / ANSWER / ICE kati ya wahusika wawili wa simu.
 * Sauti yenyewe haipiti hapa - inaenda moja kwa moja simu kwa simu (au kupitia TURN).
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class CallSignalController {

    private static final Set<String> TYPES = Set.of("OFFER", "ANSWER", "ICE");

    private final CallLogRepository callLogRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @MessageMapping("/call.signal/{callId}")
    public void signal(@DestinationVariable Long callId, Map<String, Object> payload, Principal principal) {
        if (principal == null || payload == null || !TYPES.contains(String.valueOf(payload.get("type")))) {
            return;
        }
        User sender = userRepository.findByPhone(principal.getName()).orElse(null);
        CallLog call = callLogRepository.findById(callId).orElse(null);
        if (sender == null || call == null || !call.isParticipant(sender.getId())) {
            return;
        }
        if (call.getStatus() != CallStatus.ACCEPTED) {
            return;
        }
        Map<String, Object> out = new HashMap<>(payload);
        out.put("senderId", sender.getId());
        out.put("callId", callId);
        messagingTemplate.convertAndSend("/topic/call/" + callId, (Object) out);
    }
}
