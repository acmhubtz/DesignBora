package com.designbora.review;

import com.designbora.common.ApiResponse;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;
    private final ReviewRepository reviewRepository;

    @PostMapping
    public ApiResponse<Review> submit(@RequestBody SubmitReviewRequest req) {
        Review review = reviewService.submitReview(
                req.getOrderId(), req.getStarRating(), req.getComment(), req.isDeliveredOnTime());
        return ApiResponse.ok("Asante kwa maoni yako!", review);
    }

    @GetMapping("/designer/{designerId}")
    public ApiResponse<List<Review>> byDesigner(@PathVariable Long designerId) {
        return ApiResponse.ok(reviewRepository.findByDesignerIdOrderByCreatedAtDesc(designerId));
    }

    @Data
    public static class SubmitReviewRequest {
        private Long orderId;
        private int starRating;
        private String comment;
        private boolean deliveredOnTime;
    }
}