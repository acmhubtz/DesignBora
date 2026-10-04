package com.designbora.order;

import com.designbora.common.ApiException;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.offering.ServiceOffering;
import com.designbora.offering.ServiceOfferingRepository;
import com.designbora.payout.Payout;
import com.designbora.payout.PayoutRepository;
import com.designbora.payout.PayoutStatus;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final UserRepository userRepository;
    private final DesignerProfileRepository designerProfileRepository;
    private final PayoutRepository payoutRepository;
    private final PlatformProperties platformProperties;

    @Transactional
    public Order createOrder(Long serviceId) {
        User customer = getCurrentUser();

        ServiceOffering service = serviceOfferingRepository.findById(serviceId)
                .orElseThrow(() -> ApiException.notFound("Huduma haipo"));

        if (!service.isActive()) {
            throw ApiException.badRequest("Huduma hii haipatikani kwa sasa");
        }

        DesignerProfile designer = service.getDesigner();

        BigDecimal gross = service.getPrice();
        BigDecimal fee = calculatePlatformFee(gross);
        BigDecimal net = gross.subtract(fee);

        Order order = Order.builder()
                .customer(customer)
                .designer(designer)
                .service(service)
                .status(OrderStatus.PENDING_PAYMENT)
                .grossAmount(gross)
                .platformFee(fee)
                .netAmount(net)
                .expectedDeliveryAt(LocalDateTime.now().plusDays(service.getDeliveryDays()))
                .build();

        return orderRepository.save(order);
    }

    private BigDecimal calculatePlatformFee(BigDecimal gross) {
        if ("PERCENTAGE".equals(platformProperties.getFeeType())) {
            return gross.multiply(platformProperties.getFeePercentage())
                    .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        }
        return platformProperties.getFeeFixedAmount();
    }

    @Transactional
    public Order markAsPaid(Long orderId) {
        Order order = getOrderOrThrow(orderId);

        if (order.getStatus() != OrderStatus.PENDING_PAYMENT) {
            throw ApiException.conflict("Order hii tayari imelipwa au haiko tayari kwa malipo");
        }

        order.setStatus(OrderStatus.PAID);
        order.setPaidAt(LocalDateTime.now());
        return orderRepository.save(order);
    }

    @Transactional
    public Order startWork(Long orderId) {
        Order order = getOrderOrThrow(orderId);

        if (order.getStatus() != OrderStatus.PAID) {
            throw ApiException.conflict("Order haiko tayari kuanza kazi");
        }

        order.setStatus(OrderStatus.IN_PROGRESS);
        return orderRepository.save(order);
    }

    @Transactional
    public Order markDraftSubmitted(Long orderId) {
        Order order = getOrderOrThrow(orderId);

        if (order.getStatus() != OrderStatus.IN_PROGRESS && order.getStatus() != OrderStatus.PAID
                && order.getStatus() != OrderStatus.DRAFT_SUBMITTED) {
            throw ApiException.conflict("Order haiko tayari kupokea draft");
        }

        order.setStatus(OrderStatus.DRAFT_SUBMITTED);
        return orderRepository.save(order);
    }

    @Transactional
    public Order confirmCompletion(Long orderId) {
        Order order = getOrderOrThrow(orderId);

        if (order.getStatus() != OrderStatus.DRAFT_SUBMITTED) {
            throw ApiException.conflict("Hakuna draft ya kuthibitisha kwa order hii");
        }

        order.setStatus(OrderStatus.COMPLETED);
        order.setCompletedAt(LocalDateTime.now());
        order = orderRepository.save(order);

        Payout payout = Payout.builder()
                .designer(order.getDesigner())
                .order(order)
                .amount(order.getNetAmount())
                .status(PayoutStatus.PENDING)
                .build();
        payoutRepository.save(payout);

        return order;
    }

    public List<Order> myOrdersAsCustomer() {
        User customer = getCurrentUser();
        return orderRepository.findByCustomerId(customer.getId());
    }

    public List<Order> myOrdersAsDesigner() {
        User user = getCurrentUser();
        DesignerProfile designer = designerProfileRepository.findByUserId(user.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));
        return orderRepository.findByDesignerId(designer.getId());
    }

    public Order getOrderOrThrow(Long orderId) {
        return orderRepository.findById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order haijapatikana"));
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String phone = auth.getName();
        return userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
