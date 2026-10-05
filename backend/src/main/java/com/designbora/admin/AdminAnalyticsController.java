package com.designbora.admin;

import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.designer.VerificationStatus;
import com.designbora.order.Order;
import com.designbora.order.OrderRepository;
import com.designbora.order.OrderStatus;
import com.designbora.payment.Payment;
import com.designbora.payment.PaymentRepository;
import com.designbora.payout.Payout;
import com.designbora.payout.PayoutRepository;
import com.designbora.payout.PayoutStatus;
import com.designbora.user.Role;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/** Takwimu za Admin Panel: pesa, idadi, grafu za kila siku, wabunifu, na ripoti ya CSV */
@RestController
@RequestMapping("/api/admin/analytics")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminAnalyticsController {

    /** Oda zilizolipwa lakini bado hazijakamilika = pesa iko kwenye Escrow */
    private static final Set<OrderStatus> ESCROW = EnumSet.of(
            OrderStatus.PAID, OrderStatus.IN_PROGRESS, OrderStatus.DRAFT_SUBMITTED, OrderStatus.DISPUTED);

    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final PayoutRepository payoutRepository;
    private final UserRepository userRepository;
    private final DesignerProfileRepository designerProfileRepository;
    private final AdminAuditService auditService;

    // ---------- Majibu ----------

    public record MoneySummary(BigDecimal totalCollected, BigDecimal escrowHeld, BigDecimal platformFeesEarned,
                               BigDecimal platformFeesPending, BigDecimal paidToDesigners,
                               BigDecimal payoutsPending, BigDecimal payoutsFailed) {
    }

    public record CountSummary(long customers, long designers, long verifiedDesigners, long pendingVerification,
                               long totalOrders, long activeOrders, long completedOrders, long disputedOrders,
                               long newUsersInRange, long newOrdersInRange) {
    }

    public record DayPoint(String date, BigDecimal revenue, BigDecimal platformFee,
                           long orders, long payments, long newUsers) {
    }

    public record NamedValue(String name, long count, BigDecimal amount) {
    }

    public record TopDesigner(Long designerId, String name, long completedOrders, BigDecimal earnings) {
    }

    public record Overview(int days, MoneySummary money, CountSummary counts, List<DayPoint> daily,
                           List<NamedValue> ordersByStatus, List<NamedValue> paymentsByProvider,
                           List<TopDesigner> topDesigners) {
    }

    public record DesignerActivity(Long designerId, String name, String phone, String verificationStatus,
                                   LocalDateTime registeredAt, long totalOrders, long activeOrders,
                                   long completedOrders, long disputedOrders, BigDecimal grossSales,
                                   BigDecimal earnings, BigDecimal paidOut, BigDecimal pendingPayout,
                                   LocalDateTime lastOrderAt, String payoutMethod) {
    }

    // ---------- Muhtasari na grafu ----------

    @GetMapping("/overview")
    public ApiResponse<Overview> overview(@RequestParam(defaultValue = "30") int days) {
        int range = Math.max(7, Math.min(days, 365));
        LocalDate today = LocalDate.now();
        LocalDate start = today.minusDays(range - 1L);

        List<Order> orders = orderRepository.findAll().stream()
                .filter(o -> o.getStatus() != OrderStatus.PENDING_PAYMENT)
                .toList();
        List<Payment> successPayments = paymentRepository.findAll().stream()
                .filter(p -> Payment.SUCCESS.equals(p.getStatus()))
                .toList();
        List<Payout> payouts = payoutRepository.findAll();
        List<User> users = userRepository.findAll();
        List<DesignerProfile> designers = designerProfileRepository.findAll();

        MoneySummary money = new MoneySummary(
                sum(orders.stream().map(Order::getGrossAmount)),
                sum(orders.stream().filter(o -> ESCROW.contains(o.getStatus())).map(Order::getGrossAmount)),
                sum(orders.stream().filter(o -> o.getStatus() == OrderStatus.COMPLETED).map(Order::getPlatformFee)),
                sum(orders.stream().filter(o -> ESCROW.contains(o.getStatus())).map(Order::getPlatformFee)),
                sum(payouts.stream().filter(p -> p.getStatus() == PayoutStatus.PROCESSED).map(Payout::getAmount)),
                sum(payouts.stream().filter(p -> p.getStatus() == PayoutStatus.PENDING
                        || p.getStatus() == PayoutStatus.PROCESSING).map(Payout::getAmount)),
                sum(payouts.stream().filter(p -> p.getStatus() == PayoutStatus.FAILED).map(Payout::getAmount)));

        CountSummary counts = new CountSummary(
                users.stream().filter(u -> u.getRole() == Role.CUSTOMER).count(),
                designers.size(),
                designers.stream().filter(d -> d.getVerificationStatus() == VerificationStatus.VERIFIED).count(),
                designers.stream().filter(d -> d.getVerificationStatus() == VerificationStatus.PENDING).count(),
                orders.size(),
                orders.stream().filter(o -> ESCROW.contains(o.getStatus()) && o.getStatus() != OrderStatus.DISPUTED).count(),
                orders.stream().filter(o -> o.getStatus() == OrderStatus.COMPLETED).count(),
                orders.stream().filter(o -> o.getStatus() == OrderStatus.DISPUTED).count(),
                users.stream().filter(u -> inRange(u.getCreatedAt(), start, today)).count(),
                orders.stream().filter(o -> inRange(o.getCreatedAt(), start, today)).count());

        // Grafu za kila siku
        Map<LocalDate, BigDecimal[]> money2 = new TreeMap<>();
        Map<LocalDate, long[]> counts2 = new TreeMap<>();
        for (LocalDate d = start; !d.isAfter(today); d = d.plusDays(1)) {
            money2.put(d, new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO});
            counts2.put(d, new long[]{0, 0, 0});
        }
        for (Payment p : successPayments) {
            LocalDate d = dateOf(p.getCreatedAt());
            if (d != null && money2.containsKey(d)) {
                money2.get(d)[0] = money2.get(d)[0].add(nz(p.getAmount()));
                counts2.get(d)[1]++;
            }
        }
        for (Order o : orders) {
            LocalDate created = dateOf(o.getCreatedAt());
            if (created != null && counts2.containsKey(created)) counts2.get(created)[0]++;
            LocalDate completed = dateOf(o.getCompletedAt());
            if (o.getStatus() == OrderStatus.COMPLETED && completed != null && money2.containsKey(completed)) {
                money2.get(completed)[1] = money2.get(completed)[1].add(nz(o.getPlatformFee()));
            }
        }
        for (User u : users) {
            LocalDate d = dateOf(u.getCreatedAt());
            if (d != null && counts2.containsKey(d)) counts2.get(d)[2]++;
        }
        List<DayPoint> daily = money2.keySet().stream()
                .map(d -> new DayPoint(d.toString(), money2.get(d)[0], money2.get(d)[1],
                        counts2.get(d)[0], counts2.get(d)[1], counts2.get(d)[2]))
                .toList();

        List<NamedValue> byStatus = Arrays.stream(OrderStatus.values())
                .filter(s -> s != OrderStatus.PENDING_PAYMENT)
                .map(s -> new NamedValue(s.name(),
                        orders.stream().filter(o -> o.getStatus() == s).count(),
                        sum(orders.stream().filter(o -> o.getStatus() == s).map(Order::getGrossAmount))))
                .filter(v -> v.count() > 0)
                .toList();

        List<NamedValue> byProvider = successPayments.stream()
                .collect(Collectors.groupingBy(
                        p -> p.getProvider() != null ? p.getProvider() : p.getMethod(),
                        TreeMap::new, Collectors.toList()))
                .entrySet().stream()
                .map(e -> new NamedValue(e.getKey(), e.getValue().size(),
                        sum(e.getValue().stream().map(Payment::getAmount))))
                .toList();

        List<TopDesigner> top = orders.stream()
                .filter(o -> o.getStatus() == OrderStatus.COMPLETED && o.getDesigner() != null)
                .collect(Collectors.groupingBy(o -> o.getDesigner().getId()))
                .values().stream()
                .map(list -> new TopDesigner(list.get(0).getDesigner().getId(), designerName(list.get(0).getDesigner()),
                        list.size(), sum(list.stream().map(Order::getNetAmount))))
                .sorted(Comparator.comparing(TopDesigner::earnings).reversed())
                .limit(10)
                .toList();

        return ApiResponse.ok(new Overview(range, money, counts, daily, byStatus, byProvider, top));
    }

    // ---------- Shughuli za kila mbunifu ----------

    @GetMapping("/designers")
    public ApiResponse<List<DesignerActivity>> designers() {
        Map<Long, List<Order>> ordersByDesigner = orderRepository.findAll().stream()
                .filter(o -> o.getStatus() != OrderStatus.PENDING_PAYMENT && o.getDesigner() != null)
                .collect(Collectors.groupingBy(o -> o.getDesigner().getId()));
        Map<Long, List<Payout>> payoutsByDesigner = payoutRepository.findAll().stream()
                .filter(p -> p.getDesigner() != null)
                .collect(Collectors.groupingBy(p -> p.getDesigner().getId()));

        List<DesignerActivity> result = designerProfileRepository.findAll().stream().map(d -> {
            List<Order> os = ordersByDesigner.getOrDefault(d.getId(), List.of());
            List<Payout> ps = payoutsByDesigner.getOrDefault(d.getId(), List.of());
            User u = d.getUser();
            return new DesignerActivity(
                    d.getId(),
                    designerName(d),
                    u == null ? "" : u.getPhone(),
                    d.getVerificationStatus().name(),
                    d.getCreatedAt(),
                    os.size(),
                    os.stream().filter(o -> ESCROW.contains(o.getStatus()) && o.getStatus() != OrderStatus.DISPUTED).count(),
                    os.stream().filter(o -> o.getStatus() == OrderStatus.COMPLETED).count(),
                    os.stream().filter(o -> o.getStatus() == OrderStatus.DISPUTED).count(),
                    sum(os.stream().map(Order::getGrossAmount)),
                    sum(os.stream().filter(o -> o.getStatus() == OrderStatus.COMPLETED).map(Order::getNetAmount)),
                    sum(ps.stream().filter(p -> p.getStatus() == PayoutStatus.PROCESSED).map(Payout::getAmount)),
                    sum(ps.stream().filter(p -> p.getStatus() != PayoutStatus.PROCESSED).map(Payout::getAmount)),
                    os.stream().map(Order::getCreatedAt).filter(Objects::nonNull).max(Comparator.naturalOrder()).orElse(null),
                    d.getPayoutMethod() == null ? (d.getPayoutPhone() == null ? null : "MOBILE") : d.getPayoutMethod());
        }).toList();

        return ApiResponse.ok(result);
    }

    // ---------- Ripoti ya CSV (inafunguka kwenye Excel) ----------

    @GetMapping("/report.csv")
    public ResponseEntity<String> report(@RequestParam(required = false) String from,
                                         @RequestParam(required = false) String to) {
        LocalDate end = to == null || to.isBlank() ? LocalDate.now() : LocalDate.parse(to);
        LocalDate start = from == null || from.isBlank() ? end.minusDays(29) : LocalDate.parse(from);

        Map<Long, Payment> paymentByOrder = paymentRepository.findAll().stream()
                .filter(p -> Payment.SUCCESS.equals(p.getStatus()))
                .collect(Collectors.toMap(p -> p.getOrder().getId(), Function.identity(), (a, b) -> b));
        Map<Long, Payout> payoutByOrder = payoutRepository.findAll().stream()
                .collect(Collectors.toMap(p -> p.getOrder().getId(), Function.identity(), (a, b) -> b));

        StringBuilder csv = new StringBuilder("\uFEFF"); // BOM: Excel inasoma herufi vizuri
        csv.append("Oda,Tarehe,Mteja,Mbunifu,Huduma,Hali,Jumla (TSh),Ada ya Platform (TSh),")
                .append("Mbunifu Anapata (TSh),Njia ya Malipo,Hali ya Payout,Payout Ilikwenda\n");

        List<Order> orders = orderRepository.findAll().stream()
                .filter(o -> o.getStatus() != OrderStatus.PENDING_PAYMENT)
                .filter(o -> inRange(o.getCreatedAt(), start, end))
                .sorted(Comparator.comparing(Order::getId))
                .toList();

        for (Order o : orders) {
            Payment payment = paymentByOrder.get(o.getId());
            Payout payout = payoutByOrder.get(o.getId());
            csv.append(o.getId()).append(',')
                    .append(cell(o.getCreatedAt() == null ? "" : o.getCreatedAt().toLocalDate().toString())).append(',')
                    .append(cell(o.getCustomer() == null ? "" : o.getCustomer().getFullName())).append(',')
                    .append(cell(designerName(o.getDesigner()))).append(',')
                    .append(cell(o.getService() == null ? "" : o.getService().getTitle())).append(',')
                    .append(cell(o.getStatus().name())).append(',')
                    .append(nz(o.getGrossAmount()).toPlainString()).append(',')
                    .append(nz(o.getPlatformFee()).toPlainString()).append(',')
                    .append(nz(o.getNetAmount()).toPlainString()).append(',')
                    .append(cell(payment == null ? "" : (payment.getProvider() != null ? payment.getProvider() : payment.getMethod()))).append(',')
                    .append(cell(payout == null ? "" : payout.getStatus().name())).append(',')
                    .append(cell(payout == null || payout.getDestination() == null ? "" : payout.getDestination()))
                    .append('\n');
        }

        auditService.record("REPORT_DOWNLOADED", null, null, start + " hadi " + end + " (oda " + orders.size() + ")");

        return ResponseEntity.ok()
                .contentType(new MediaType("text", "csv", java.nio.charset.StandardCharsets.UTF_8))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"designbora-ripoti-" + start + "-hadi-" + end + ".csv\"")
                .body(csv.toString());
    }

    // ---------- Wasaidizi ----------

    private static BigDecimal sum(Stream<BigDecimal> values) {
        return values.filter(Objects::nonNull).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static BigDecimal nz(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }

    private static LocalDate dateOf(LocalDateTime time) {
        return time == null ? null : time.toLocalDate();
    }

    private static boolean inRange(LocalDateTime time, LocalDate start, LocalDate end) {
        LocalDate d = dateOf(time);
        return d != null && !d.isBefore(start) && !d.isAfter(end);
    }

    private static String designerName(DesignerProfile d) {
        if (d == null) return "";
        if (d.getCompanyName() != null && !d.getCompanyName().isBlank()) return d.getCompanyName();
        return d.getUser() == null ? "" : d.getUser().getFullName();
    }

    private static String cell(String value) {
        if (value == null) return "";
        String v = value.replace("\"", "\"\"");
        return (v.contains(",") || v.contains("\"") || v.contains("\n")) ? "\"" + v + "\"" : v;
    }
}
