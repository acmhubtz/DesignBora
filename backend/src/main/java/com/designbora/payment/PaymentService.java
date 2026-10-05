package com.designbora.payment;

import com.designbora.common.ApiException;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.order.OrderStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class PaymentService {

    private static final Set<String> METHODS = Set.of("MOBILE", "CARD");
    private static final Set<String> MOBILE_PROVIDERS = Set.of("MPESA", "MIXX", "AIRTEL", "HALOPESA", "TPESA");

    private final PaymentRepository paymentRepository;
    private final OrderService orderService;
    private final PaymentProvider paymentProvider;
    private final com.designbora.notification.NotificationService notificationService;

    @Transactional
    public Payment initiate(Order order, PaymentRequest request) {
        if (order.getStatus() != OrderStatus.PENDING_PAYMENT) {
            throw ApiException.conflict("Oda hii tayari imelipwa au haiko tayari kwa malipo");
        }

        String method = upper(request.method());
        if (!METHODS.contains(method)) {
            throw ApiException.badRequest("Chagua njia ya malipo");
        }

        String provider = null;
        String phone = null;
        if ("MOBILE".equals(method)) {
            provider = upper(request.provider());
            if (!MOBILE_PROVIDERS.contains(provider)) {
                throw ApiException.badRequest("Chagua mtandao wa simu");
            }
            phone = normalizePhone(request.phone());
        }

        Payment payment = paymentRepository.save(Payment.builder()
                .order(order)
                .method(method)
                .provider(provider)
                .phone(phone)
                .amount(order.getGrossAmount())
                .status(Payment.PENDING)
                .build());

        PaymentProvider.InitResult result = paymentProvider.initiate(payment);
        payment.setProviderReference(result.reference());
        payment.setCheckoutUrl(result.checkoutUrl());
        return paymentRepository.save(payment);
    }

    @Transactional
    public Payment refreshStatus(Payment payment) {
        if (!Payment.PENDING.equals(payment.getStatus())) {
            return payment;
        }
        PaymentProvider.StatusResult result = paymentProvider.checkStatus(payment);
        if (Payment.SUCCESS.equals(result.status())) {
            return markSuccess(payment);
        }
        if (Payment.FAILED.equals(result.status())) {
            return markFailed(payment, result.failureReason());
        }
        return payment;
    }

    /** Malipo yamethibitishwa -> oda inakuwa PAID kisha IN_PROGRESS */
    @Transactional
    public Payment markSuccess(Payment payment) {
        if (Payment.SUCCESS.equals(payment.getStatus())) {
            return payment;
        }
        payment.setStatus(Payment.SUCCESS);
        paymentRepository.save(payment);

        Long orderId = payment.getOrder().getId();
        Order order = orderService.getOrderOrThrow(orderId);
        if (order.getStatus() == OrderStatus.PENDING_PAYMENT) {
            orderService.markAsPaid(orderId);
            orderService.startWork(orderId);
            notificationService.toDesigner(order, "ORDER_PAID", "Oda mpya imelipwa! 🎉",
                    "Oda #" + orderId + " ya TSh " + payment.getAmount().toPlainString() + " imelipwa. Anza kazi sasa.");
        }
        return payment;
    }

    @Transactional
    public Payment markFailed(Payment payment, String reason) {
        if (!Payment.PENDING.equals(payment.getStatus())) {
            return payment;
        }
        payment.setStatus(Payment.FAILED);
        payment.setFailureReason(reason == null ? "Malipo hayakufanikiwa" : reason);
        return paymentRepository.save(payment);
    }

    /** Webhook imefika: tunathibitisha hali kwa kuuliza mtoa huduma moja kwa moja */
    @Transactional
    public void handleProviderCallback(String providerReference) {
        paymentRepository.findByProviderReference(providerReference).ifPresent(this::refreshStatus);
    }

    public Payment getOrThrow(Long paymentId) {
        return paymentRepository.findById(paymentId)
                .orElseThrow(() -> ApiException.notFound("Malipo hayajapatikana"));
    }

    /** Inakubali 0712345678, 712345678, 255712345678, +255 712 345 678 -> 255712345678 */
    static String normalizePhone(String raw) {
        String digits = raw == null ? "" : raw.replaceAll("\\D", "");
        if (digits.startsWith("255")) digits = digits.substring(3);
        if (digits.startsWith("0")) digits = digits.substring(1);
        if (digits.length() != 9) {
            throw ApiException.badRequest("Namba ya simu si sahihi");
        }
        return "255" + digits;
    }

    private static String upper(String value) {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
    }
}
