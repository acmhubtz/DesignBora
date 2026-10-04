package com.designbora.category;

import com.designbora.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
@RequiredArgsConstructor
public class CategoryController {

    private final CategoryRepository categoryRepository;

    @GetMapping
    public ApiResponse<List<Category>> topLevel() {
        return ApiResponse.ok(categoryRepository.findByParentIsNull());
    }

    @GetMapping("/{id}/children")
    public ApiResponse<List<Category>> children(@PathVariable Long id) {
        return ApiResponse.ok(categoryRepository.findByParentId(id));
    }
}