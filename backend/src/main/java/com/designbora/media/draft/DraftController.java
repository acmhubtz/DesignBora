package com.designbora.media.draft;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.media.MediaStorageService;
import com.designbora.order.Order;
import com.designbora.order.OrderService;
import com.designbora.order.OrderStatus;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.zip.ZipFile;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class DraftController {

    private static final long MAX_FILE_SIZE = 50L * 1024 * 1024; // 50MB
    private static final int MAX_ARCHIVE_ENTRIES = 200;

    private final DraftRepository draftRepository;
    private final OrderService orderService;
    private final MediaStorageService mediaStorageService;
    private final PreviewService previewService;
    private final UserRepository userRepository;

    @PostMapping(value = "/{orderId}/drafts", consumes = "multipart/form-data")
    public ApiResponse<DraftResponse> uploadDraft(@PathVariable Long orderId,
                                                  @RequestParam("file") MultipartFile file) {

        Order order = orderService.getOrderOrThrow(orderId);
        User user = getCurrentUser();

        if (!isDesignerOf(order, user)) {
            throw ApiException.forbidden("Ni mbunifu wa order hii pekee anayeweza kutuma draft");
        }
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("Faili ni tupu");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw ApiException.badRequest("Faili ni kubwa mno. Kikomo ni 50MB");
        }

        String originalUrl = mediaStorageService.saveDraftFile(file);
        Path originalPath = mediaStorageService.resolve(originalUrl);
        String extension = extensionOf(originalUrl);

        // Preview yenye watermark (picha, PDF, nyaraka, video). null = hakuna preview
        String previewName = previewService.createPreview(originalPath, extension);
        String previewUrl = previewName == null
                ? ""
                : originalUrl.substring(0, originalUrl.lastIndexOf('/') + 1) + previewName;

        List<Draft> existing = draftRepository.findByOrderIdOrderByVersionNoAsc(orderId);
        int nextVersion = existing.size() + 1;

        Draft draft = Draft.builder()
                .order(order)
                .versionNo(nextVersion)
                .watermarkedFileUrl(previewUrl)
                .originalFileUrl(originalUrl)
                .build();

        draft = draftRepository.save(draft);
        orderService.markDraftSubmitted(orderId);

        return ApiResponse.ok("Draft imetumwa (Version " + nextVersion + ")", toResponse(draft));
    }

    @GetMapping("/{orderId}/drafts")
    public ApiResponse<List<DraftResponse>> listDrafts(@PathVariable Long orderId) {
        Order order = orderService.getOrderOrThrow(orderId);
        requireParticipant(order, getCurrentUser());

        List<DraftResponse> drafts = draftRepository.findByOrderIdOrderByVersionNoAsc(orderId)
                .stream()
                .map(this::toResponse)
                .toList();
        return ApiResponse.ok(drafts);
    }

    @GetMapping("/{orderId}/drafts/{draftId}/download")
    public ApiResponse<Map<String, String>> downloadOriginal(@PathVariable Long orderId,
                                                             @PathVariable Long draftId) {
        Order order = orderService.getOrderOrThrow(orderId);
        requireParticipant(order, getCurrentUser());

        if (order.getStatus() != OrderStatus.COMPLETED) {
            throw ApiException.forbidden("Faili la asili linapatikana tu baada ya order kukamilika (COMPLETED)");
        }

        Draft draft = draftRepository.findById(draftId)
                .orElseThrow(() -> ApiException.notFound("Draft haijapatikana"));
        if (!draft.getOrder().getId().equals(orderId)) {
            throw ApiException.notFound("Draft haijapatikana kwenye order hii");
        }

        String finalUrl = mediaStorageService.copyToFinals(draft.getOriginalFileUrl());
        String extension = extensionOf(draft.getOriginalFileUrl());
        String fileName = "DesignBora_Oda" + orderId + "_v" + draft.getVersionNo()
                + (extension.isEmpty() ? "" : "." + extension);

        return ApiResponse.ok("Faili linapatikana", Map.of("url", finalUrl, "fileName", fileName));
    }

    // ---------- Wasaidizi ----------

    private DraftResponse toResponse(Draft draft) {
        String extension = extensionOf(draft.getOriginalFileUrl());
        String previewUrl = draft.getWatermarkedFileUrl() == null ? "" : draft.getWatermarkedFileUrl();
        String previewType = previewTypeOf(previewUrl, extension);
        Path originalPath = mediaStorageService.resolve(draft.getOriginalFileUrl());

        Long size = null;
        try {
            size = Files.size(originalPath);
        } catch (Exception ignored) {
            // Faili halipo kwenye disk - tunarudisha bila ukubwa
        }

        List<DraftResponse.ArchiveEntry> entries = "ARCHIVE".equals(previewType)
                ? zipEntries(originalPath)
                : Collections.emptyList();

        return new DraftResponse(
                draft.getId(),
                draft.getVersionNo(),
                draft.getStatus().name(),
                draft.getSubmittedAt(),
                previewType,
                extension,
                size,
                previewUrl,
                entries
        );
    }

    /** Aina ya preview inatokana na faili la preview lenyewe (docx -> pdf, psd -> png, mov -> mp4) */
    private static String previewTypeOf(String previewUrl, String originalExtension) {
        if (previewUrl.isEmpty()) {
            return "zip".equals(originalExtension) ? "ARCHIVE" : "OTHER";
        }
        return switch (extensionOf(previewUrl)) {
            case "jpg", "jpeg", "png" -> "IMAGE";
            case "pdf" -> "PDF";
            case "mp4" -> "VIDEO";
            default -> "OTHER";
        };
    }

    /** Inasoma orodha ya faili ndani ya zip bila kuzifungua */
    private static List<DraftResponse.ArchiveEntry> zipEntries(Path zipPath) {
        try (ZipFile zip = new ZipFile(zipPath.toFile())) {
            return zip.stream()
                    .filter(entry -> !entry.isDirectory())
                    .limit(MAX_ARCHIVE_ENTRIES)
                    .map(entry -> new DraftResponse.ArchiveEntry(entry.getName(), Math.max(entry.getSize(), 0)))
                    .toList();
        } catch (Exception e) {
            return Collections.emptyList();
        }
    }

    private static String extensionOf(String url) {
        if (url == null) return "";
        int dot = url.lastIndexOf('.');
        int slash = url.lastIndexOf('/');
        return dot > slash ? url.substring(dot + 1).toLowerCase() : "";
    }

    private boolean isDesignerOf(Order order, User user) {
        return order.getDesigner() != null
                && order.getDesigner().getUser() != null
                && order.getDesigner().getUser().getId().equals(user.getId());
    }

    private boolean isCustomerOf(Order order, User user) {
        return order.getCustomer() != null
                && order.getCustomer().getId().equals(user.getId());
    }

    private void requireParticipant(Order order, User user) {
        if (!isDesignerOf(order, user) && !isCustomerOf(order, user)) {
            throw ApiException.forbidden("Huna ruhusa kwa order hii");
        }
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}
