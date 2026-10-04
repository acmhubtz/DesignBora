package com.designbora.portfolio;

import com.designbora.category.Category;
import com.designbora.category.CategoryRepository;
import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.media.MediaStorageService;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/portfolio")
@RequiredArgsConstructor
public class PortfolioController {

    private final PortfolioItemRepository portfolioItemRepository;
    private final DesignerProfileRepository designerProfileRepository;
    private final CategoryRepository categoryRepository;
    private final UserRepository userRepository;
    private final MediaStorageService mediaStorageService;

    @GetMapping("/designer/{designerId}")
    public ApiResponse<List<PortfolioItem>> byDesigner(@PathVariable Long designerId) {
        return ApiResponse.ok(portfolioItemRepository.findByDesignerId(designerId));
    }

    @GetMapping("/category/{categoryId}")
    public ApiResponse<List<PortfolioItem>> byCategory(@PathVariable Long categoryId) {
        return ApiResponse.ok(portfolioItemRepository.findByCategoryId(categoryId));
    }

    @PostMapping(consumes = "multipart/form-data")
    public ApiResponse<PortfolioItem> create(
            @RequestParam("categoryId") Long categoryId,
            @RequestParam("title") String title,
            @RequestParam(value = "description", required = false) String description,
            @RequestParam("file") MultipartFile file) {

        User currentUser = getCurrentUser();

        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));

        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> ApiException.notFound("Category haipo"));

        String thumbnailUrl = mediaStorageService.savePortfolioFile(file);

        PortfolioItem item = PortfolioItem.builder()
                .designer(designer)
                .category(category)
                .title(title)
                .description(description)
                .thumbnailUrl(thumbnailUrl)
                .build();

        return ApiResponse.ok("Kazi imeongezwa kwenye portfolio", portfolioItemRepository.save(item));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        User currentUser = getCurrentUser();

        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));

        PortfolioItem item = portfolioItemRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Kazi haipo"));

        if (!item.getDesigner().getId().equals(designer.getId())) {
            throw ApiException.forbidden("Huwezi kufuta kazi ya designer mwingine");
        }

        portfolioItemRepository.delete(item);
        return ApiResponse.ok("Imefutwa", null);
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String phone = auth.getName();
        return userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}