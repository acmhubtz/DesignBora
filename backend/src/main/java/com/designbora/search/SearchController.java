package com.designbora.search;

import com.designbora.category.Category;
import com.designbora.category.CategoryRepository;
import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.metrics.DesignerMetrics;
import com.designbora.designer.metrics.DesignerMetricsRepository;
import com.designbora.offering.ServiceOffering;
import com.designbora.offering.ServiceOfferingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class SearchController {

    private final CategoryRepository categoryRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final DesignerMetricsRepository designerMetricsRepository;

    @GetMapping("/api/search")
    public ApiResponse<List<SearchResultDto>> search(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String q) {

        if ((category == null || category.isBlank()) && (q == null || q.isBlank())) {
            throw ApiException.badRequest("Weka 'category' au 'q' kwenye search");
        }

        List<Category> matchedCategories = new ArrayList<>();

        if (category != null && !category.isBlank()) {
            categoryRepository.findBySlug(category).ifPresent(matchedCategories::add);
        }

        if (q != null && !q.isBlank()) {
            String needle = q.toLowerCase().trim();
            categoryRepository.findAll().forEach(c -> {
                if (c.getName().toLowerCase().contains(needle) && !matchedCategories.contains(c)) {
                    matchedCategories.add(c);
                }
            });
        }

        List<ServiceOffering> offerings = new ArrayList<>();
        for (Category cat : matchedCategories) {
            offerings.addAll(serviceOfferingRepository.findByCategoryIdAndActiveTrue(cat.getId()));
        }

        List<SearchResultDto> results = offerings.stream().map(offering -> {
            DesignerMetrics metrics = designerMetricsRepository.findById(offering.getDesigner().getId())
                    .orElseGet(() -> DesignerMetrics.builder()
                            .designerId(offering.getDesigner().getId())
                            .build());

            return SearchResultDto.builder()
                    .serviceId(offering.getId())
                    .serviceTitle(offering.getTitle())
                    .price(offering.getPrice())
                    .deliveryDays(offering.getDeliveryDays())
                    .designerId(offering.getDesigner().getId())
                    .designerName(offering.getDesigner().getAccountType().name().equals("COMPANY")
                            ? offering.getDesigner().getCompanyName()
                            : offering.getDesigner().getUser().getFullName())
                    .verified(offering.getDesigner().isVerified())
                    .designerAvatarUrl(offering.getDesigner().getUser() == null ? null
                            : offering.getDesigner().getUser().getAvatarUrl())
                    .compositeScore(metrics.getCompositeScore())
                    .avgStarRating(metrics.getAvgStarRating())
                    .build();
        })
        .sorted(Comparator.comparing(SearchResultDto::getCompositeScore).reversed())
        .toList();

        return ApiResponse.ok(results);
    }
}
