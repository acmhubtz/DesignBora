package com.designbora.call;

import com.designbora.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class CallController {

    private final CallService callService;

    @Value("${app.turn.urls:}")
    private String turnUrls;

    @Value("${app.turn.secret:}")
    private String turnSecret;

    @PostMapping("/orders/{orderId}/calls")
    public ResponseEntity<Map<String, Object>> start(@PathVariable Long orderId) {
        return ok(CallResponse.from(callService.start(orderId)));
    }

    @GetMapping("/calls/incoming")
    public ResponseEntity<Map<String, Object>> incoming() {
        CallLog call = callService.incoming();
        return ok(call == null ? null : CallResponse.from(call));
    }

    @GetMapping("/calls/{id}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable Long id) {
        return ok(CallResponse.from(callService.get(id)));
    }

    @PostMapping("/calls/{id}/accept")
    public ResponseEntity<Map<String, Object>> accept(@PathVariable Long id) {
        return ok(CallResponse.from(callService.accept(id)));
    }

    @PostMapping("/calls/{id}/reject")
    public ResponseEntity<Map<String, Object>> reject(@PathVariable Long id) {
        return ok(CallResponse.from(callService.reject(id)));
    }

    /** Skrini ya simu ya mfumo (app imefungwa kabisa): kataa kwa ufunguo wa simu hiyo */
    @PostMapping("/calls/{id}/decline")
    public ResponseEntity<Map<String, Object>> declineByKey(@PathVariable Long id, @RequestParam String key) {
        callService.declineByKey(id, key);
        return ok(null);
    }

    @PostMapping("/calls/{id}/end")
    public ResponseEntity<Map<String, Object>> end(@PathVariable Long id) {
        return ok(CallResponse.from(callService.end(id)));
    }

    /** STUN za bure + TURN yetu (V4) yenye nenosiri la muda (coturn use-auth-secret) */
    @GetMapping("/calls/ice-servers")
    public ResponseEntity<Map<String, Object>> iceServers() {
        User me = callService.currentUser();
        List<Map<String, Object>> servers = new ArrayList<>();
        servers.add(Map.of("urls", List.of("stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302")));

        List<String> turn = Arrays.stream(turnUrls.split(","))
                .map(String::trim).filter(s -> !s.isEmpty()).toList();
        if (!turn.isEmpty() && !turnSecret.isBlank()) {
            String username = (Instant.now().getEpochSecond() + 6 * 3600) + ":" + me.getId();
            servers.add(Map.of("urls", turn, "username", username, "credential", hmacSha1(username)));
        }
        return ok(Map.of("iceServers", servers, "ringTimeoutSeconds", CallService.RING_TIMEOUT_SECONDS));
    }

    private String hmacSha1(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(turnSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
            return Base64.getEncoder().encodeToString(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("TURN credential haikutengenezwa", e);
        }
    }

    private static ResponseEntity<Map<String, Object>> ok(Object data) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", true);
        body.put("data", data);
        return ResponseEntity.ok(body);
    }
}
