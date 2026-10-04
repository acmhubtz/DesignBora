package com.designbora.review;

import com.designbora.common.ApiException;
import com.designbora.designer.metrics.DesignerMetrics;
import com.designbora.designer.metrics.DesignerMetricsRepository;
import com.designbora.order.Order;
import com.designbora.order.OrderRepository;
import com.designbora.order.OrderStatus;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@RequiredArgsConstructor
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final OrderRepository orderRepository;
    private final DesignerMetricsRepository designerMetricsRepository;
    private final UserRepository userRepository;

    @Transactional
    public Review submitReview(Long orderId, int starRating, String comment, boolean deliveredOnTime) {
        User reviewer = getCurrentUser();

        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> ApiException.notFound("Order haijapatikana"));

        if (!order.getCustomer().getId().equals(reviewer.getId())) {
            throw ApiException.forbidden("Huwezi kutoa maoni kwa order si yako");
        }
        if (order.getStatus() != OrderStatus.COMPLETED) {
            throw ApiException.conflict("Unaweza kutoa maoni tu baada ya order kukamilika");
        }
        if (reviewRepository.findByOrderId(orderId).isPresent()) {
            throw ApiException.conflict("Tayari umetoa maoni kwa order hii");
        }
        if (starRating < 1 || starRating > 5) {
            throw ApiException.badRequest("Rating iwe kati ya nyota 1 na 5");
        }

        Review review = Review.builder()
                .order(order)
                .reviewer(reviewer)
                .designer(order.getDesigner())
                .starRating(starRating)
                .comment(comment)
                .deliveredOnTime(deliveredOnTime)
                .build();

        review = reviewRepository.save(review);

        recalculateCompositeScore(order.getDesigner().getId());

        return review;
    }

    private void recalculateCompositeScore(Long designerId) {
        DesignerMetrics metrics = designerMetricsRepository.findById(designerId)
                .orElseGet(() -> DesignerMetrics.builder().designerId(designerId).build());

        long totalOrders = orderRepository.findByDesignerId(designerId).size();
        long completedOrders = orderRepository.findByDesignerId(designerId).stream()
                .filter(o -> o.getStatus() == OrderStatus.COMPLETED)
                .count();

        BigDecimal avgStars = reviewRepository.averageStarRating(designerId);
        if (avgStars == null) avgStars = BigDecimal.ZERO;

        BigDecimal completionRate = totalOrders == 0 ? BigDecimal.ZERO :
                BigDecimal.valueOf(completedOrders)
                        .divide(BigDecimal.valueOf(totalOrders), 4, RoundingMode.HALF_UP);

        // Formula rahisi (mwanzo): 70% star rating (kwa kiwango cha 0-1) + 30% completion rate
        BigDecimal starComponent = avgStars.divide(new BigDecimal("5.0"), 4, RoundingMode.HALF_UP)
                .multiply(new BigDecimal("0.7"));
        BigDecimal completionComponent = completionRate.multiply(new BigDecimal("0.3"));

        BigDecimal composite = starComponent.add(completionComponent).setScale(3, RoundingMode.HALF_UP);

        metrics.setTotalOrders((int) totalOrders);
        metrics.setCompletedOrders((int) completedOrders);
        metrics.setAvgStarRating(avgStars.setScale(2, RoundingMode.HALF_UP));
        metrics.setCompletionRate(completionRate.multiply(new BigDecimal("100")).setScale(2, RoundingMode.HALF_UP));
        metrics.setCompositeScore(composite);

        designerMetricsRepository.save(metrics);
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String phone = auth.getName();
        return userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}