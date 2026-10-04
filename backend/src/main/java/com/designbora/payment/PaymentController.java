package com.designbora.payment;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;
    private final OrderService orderService;
    private final UserRepository userRepository;

    @PostMapping("/orders/{orderId}/payments")
    public ApiResponse<PaymentResponse> initiate(@PathVariable Long orderId,
                                                 @RequestBody PaymentRequest request) {
        Order order = orderService.getOrderOrThrow(orderId);
        requireCustomer(order, getCurrentUser());

        Payment payment = paymentService.initiate(order, request);
        String message = "MOBILE".equals(payment.getMethod())
                ? "Ombi la malipo limetumwa kwenye simu yako"
                : "Kamilisha malipo kwenye ukurasa wa kadi";
        return ApiResponse.ok(message, PaymentResponse.from(payment));
    }

    @GetMapping("/payments/{paymentId}")
    public ApiResponse<PaymentResponse> status(@PathVariable Long paymentId) {
        Payment payment = paymentService.getOrThrow(paymentId);
        requireCustomer(payment.getOrder(), getCurrentUser());
        return ApiResponse.ok(PaymentResponse.from(paymentService.refreshStatus(payment)));
    }

    /** Webhook ya ClickPesa (PAYMENT RECEIVED / PAYMENT FAILED) */
    @PostMapping("/payments/webhooks/clickpesa")
    public Map<String, String> clickPesaWebhook(@RequestBody Map<String, Object> payload) {
        if (payload.get("data") instanceof Map<?, ?> data && data.get("orderReference") != null) {
            paymentService.handleProviderCallback(String.valueOf(data.get("orderReference")));
        }
        return Map.of("received", "true");
    }

    // ---------- Ukurasa wa kadi wa MAJARIBIO (ondoa ukitumia mtoa huduma halisi) ----------

    @GetMapping(value = "/payments/mock-card/{paymentId}", produces = MediaType.TEXT_HTML_VALUE)
    public String mockCardPage(@PathVariable Long paymentId) {
        Payment payment = paymentService.getOrThrow(paymentId);
        if (!Payment.PENDING.equals(payment.getStatus())) {
            return resultPage("Malipo haya yameshashughulikiwa", "Rudi kwenye app ya DesignBora.");
        }
        return """
                <!doctype html><html><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Malipo ya Kadi (Majaribio)</title>
                <style>
                  body{font-family:sans-serif;background:#f5f6f7;margin:0;padding:24px;display:flex;justify-content:center}
                  .card{background:#fff;border-radius:18px;padding:24px;max-width:380px;width:100%%;box-shadow:0 4px 20px rgba(0,0,0,.08)}
                  h2{margin:0 0 4px}.muted{color:#6b7280;font-size:14px}.amount{font-size:28px;font-weight:800;margin:16px 0}
                  .badge{display:inline-block;background:#fef3c7;color:#92400e;padding:4px 10px;border-radius:20px;font-size:12px;font-weight:700}
                  button{width:100%%;padding:14px;border:0;border-radius:12px;font-size:16px;font-weight:700;margin-top:10px;cursor:pointer}
                  .ok{background:#059669;color:#fff}.no{background:#fee2e2;color:#b91c1c}
                </style></head><body><div class="card">
                <span class="badge">MAJARIBIO - HAKUNA PESA HALISI</span>
                <h2 style="margin-top:12px">DesignBora</h2>
                <div class="muted">Malipo ya Oda #%d kwa kadi (Visa/Mastercard)</div>
                <div class="amount">TSh %s</div>
                <form method="post" action="/api/payments/mock-card/%d/approve"><button class="ok">Kubali Malipo</button></form>
                <form method="post" action="/api/payments/mock-card/%d/decline"><button class="no">Kataa</button></form>
                </div></body></html>
                """.formatted(
                payment.getOrder().getId(),
                payment.getAmount().toPlainString(),
                payment.getId(),
                payment.getId());
    }

    @PostMapping(value = "/payments/mock-card/{paymentId}/{action}", produces = MediaType.TEXT_HTML_VALUE)
    public String mockCardAction(@PathVariable Long paymentId, @PathVariable String action) {
        Payment payment = paymentService.getOrThrow(paymentId);
        if ("approve".equals(action)) {
            paymentService.markSuccess(payment);
            return resultPage("Malipo yamekubaliwa ✔", "Rudi kwenye app ya DesignBora - oda yako imeanza.");
        }
        paymentService.markFailed(payment, "Kadi imekataliwa (majaribio)");
        return resultPage("Malipo yamekataliwa", "Rudi kwenye app ujaribu tena.");
    }

    private static String resultPage(String title, String message) {
        return """
                <!doctype html><html><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1"></head>
                <body style="font-family:sans-serif;background:#f5f6f7;padding:40px;text-align:center">
                <h2>%s</h2><p style="color:#6b7280">%s</p></body></html>
                """.formatted(title, message);
    }

    // ---------- Wasaidizi ----------

    private void requireCustomer(Order order, User user) {
        if (order.getCustomer() == null || !order.getCustomer().getId().equals(user.getId())) {
            throw ApiException.forbidden("Mteja wa oda hii pekee ndiye anaweza kuilipia");
        }
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
