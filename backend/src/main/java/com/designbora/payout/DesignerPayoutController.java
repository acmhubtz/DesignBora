package com.designbora.payout;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

@RestController
@RequestMapping("/api/payouts")
@RequiredArgsConstructor
public class DesignerPayoutController {

    private final PayoutRepository payoutRepository;
    private final PayoutProvider payoutProvider;
    private final DesignerProfileRepository designerProfileRepository;
    private final UserRepository userRepository;

    public record PayoutResponse(Long id, Long orderId, BigDecimal amount, String status, String channel,
                                 String destination, String failureReason,
                                 LocalDateTime createdAt, LocalDateTime processedAt) {
        static PayoutResponse from(Payout p) {
            String destination = p.getDestination() != null ? p.getDestination()
                    : (p.getPhone() != null ? "+" + p.getPhone() : null);
            return new PayoutResponse(p.getId(), p.getOrder().getId(), p.getAmount(), p.getStatus().name(),
                    p.getChannel(), destination, p.getFailureReason(), p.getCreatedAt(), p.getProcessedAt());
        }
    }

    public record MyPayoutsResponse(String payoutMethod, String payoutPhone, String bankName, String bankBic,
                                    String accountNumber, String accountName, boolean ready,
                                    BigDecimal totalPaid, BigDecimal pendingAmount, List<PayoutResponse> payouts) {
    }

    public record PhoneRequest(String phone) {
    }

    public record MethodRequest(String method, String phone, String bic, String bankName,
                                String accountNumber, String accountName) {
    }

    @GetMapping("/me")
    public ApiResponse<MyPayoutsResponse> myPayouts() {
        DesignerProfile designer = currentDesigner();
        List<Payout> payouts = payoutRepository.findByDesignerId(designer.getId());

        BigDecimal totalPaid = sum(payouts, PayoutStatus.PROCESSED);
        BigDecimal pending = sum(payouts, PayoutStatus.PENDING).add(sum(payouts, PayoutStatus.PROCESSING));
        List<PayoutResponse> items = payouts.stream()
                .sorted(Comparator.comparing(Payout::getId).reversed())
                .map(PayoutResponse::from)
                .toList();

        return ApiResponse.ok(new MyPayoutsResponse(
                designer.getPayoutMethod() == null ? "MOBILE" : designer.getPayoutMethod(),
                designer.getPayoutPhone(), designer.getPayoutBankName(), designer.getPayoutBankBic(),
                designer.getPayoutAccountNumber(), designer.getPayoutAccountName(),
                PayoutService.destinationOf(designer) != null,
                totalPaid, pending, items));
    }

    @GetMapping("/banks")
    public ApiResponse<List<PayoutProvider.Bank>> banks() {
        return ApiResponse.ok(payoutProvider.banks());
    }

    /** Njia ya zamani (simu tu) - bado inafanya kazi */
    @PutMapping("/me/phone")
    public ApiResponse<MyPayoutsResponse> setPayoutPhone(@RequestBody PhoneRequest request) {
        return setMethod(new MethodRequest("MOBILE", request.phone(), null, null, null, null));
    }

    @PutMapping("/me/method")
    public ApiResponse<MyPayoutsResponse> setMethod(@RequestBody MethodRequest request) {
        DesignerProfile designer = currentDesigner();
        String method = request.method() == null ? "" : request.method().trim().toUpperCase(Locale.ROOT);

        if ("BANK".equals(method)) {
            String bic = request.bic() == null ? "" : request.bic().trim();
            String accountNumber = request.accountNumber() == null ? "" : request.accountNumber().replaceAll("\\s", "");
            String accountName = request.accountName() == null ? "" : request.accountName().trim();
            if (bic.isEmpty()) {
                throw ApiException.badRequest("Chagua benki");
            }
            if (!accountNumber.matches("[A-Za-z0-9]{5,30}")) {
                throw ApiException.badRequest("Namba ya akaunti si sahihi");
            }
            if (accountName.length() < 3 || accountName.length() > 150) {
                throw ApiException.badRequest("Andika jina la akaunti kama lilivyo benki");
            }
            designer.setPayoutMethod("BANK");
            designer.setPayoutBankBic(bic);
            designer.setPayoutBankName(request.bankName() == null ? bic : request.bankName().trim());
            designer.setPayoutAccountNumber(accountNumber);
            designer.setPayoutAccountName(accountName);
        } else if ("MOBILE".equals(method)) {
            designer.setPayoutMethod("MOBILE");
            designer.setPayoutPhone(normalizePhone(request.phone()));
        } else {
            throw ApiException.badRequest("Chagua njia ya kupokea malipo: simu au benki");
        }
        designerProfileRepository.save(designer);

        // Payouts zilizoshindwa zinarudishwa kwenye foleni kwa taarifa mpya
        for (Payout payout : payoutRepository.findByDesignerId(designer.getId())) {
            if (payout.getStatus() == PayoutStatus.FAILED) {
                payout.setStatus(PayoutStatus.PENDING);
                payout.setFailureReason(null);
                payoutRepository.save(payout);
            }
        }
        return myPayouts();
    }

    private static BigDecimal sum(List<Payout> payouts, PayoutStatus status) {
        return payouts.stream()
                .filter(p -> p.getStatus() == status)
                .map(Payout::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static String normalizePhone(String raw) {
        String digits = raw == null ? "" : raw.replaceAll("\\D", "");
        if (digits.startsWith("255")) digits = digits.substring(3);
        if (digits.startsWith("0")) digits = digits.substring(1);
        if (digits.length() != 9) {
            throw ApiException.badRequest("Namba ya simu si sahihi");
        }
        return "255" + digits;
    }

    private DesignerProfile currentDesigner() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User user = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
        return designerProfileRepository.findByUserId(user.getId())
                .orElseThrow(() -> ApiException.forbidden("Wewe si mbunifu aliyesajiliwa"));
    }
}
