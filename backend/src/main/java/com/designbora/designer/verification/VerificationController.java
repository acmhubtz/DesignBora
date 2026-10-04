package com.designbora.designer.verification;

import com.designbora.common.ApiException;
import com.designbora.common.ApiResponse;
import com.designbora.designer.DesignerProfile;
import com.designbora.designer.DesignerProfileRepository;
import com.designbora.designer.VerificationStatus;
import com.designbora.media.MediaStorageService;
import com.designbora.user.User;
import com.designbora.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/verification")
@RequiredArgsConstructor
public class VerificationController {

    private final VerificationDocumentRepository documentRepository;
    private final DesignerProfileRepository designerProfileRepository;
    private final UserRepository userRepository;
    private final MediaStorageService mediaStorageService;

    @PostMapping(value = "/documents", consumes = "multipart/form-data")
    public ApiResponse<VerificationDocument> upload(
            @RequestParam("documentType") DocumentType documentType,
            @RequestParam("file") MultipartFile file) {

        User currentUser = getCurrentUser();

        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));

        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("Chagua faili la nyaraka");
        }
        if (file.getSize() > 10L * 1024 * 1024) {
            throw ApiException.badRequest("Faili ni kubwa mno. Kikomo ni 10MB");
        }
        String originalName = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase();
        if (!(originalName.endsWith(".jpg") || originalName.endsWith(".jpeg")
                || originalName.endsWith(".png") || originalName.endsWith(".pdf"))) {
            throw ApiException.badRequest("Tumia picha (JPG/PNG) au PDF");
        }

        String fileUrl = mediaStorageService.saveDocumentFile(file);

        VerificationDocument document = VerificationDocument.builder()
                .designer(designer)
                .documentType(documentType)
                .fileUrl(fileUrl)
                .build();

        if (designer.getVerificationStatus() == VerificationStatus.REJECTED) {
            designer.setVerificationStatus(VerificationStatus.PENDING);
            designerProfileRepository.save(designer);
        }

        return ApiResponse.ok("Hati imepakiwa, inasubiri uhakiki", documentRepository.save(document));
    }

    @GetMapping("/documents/mine")
    public ApiResponse<List<VerificationDocument>> myDocuments() {
        User currentUser = getCurrentUser();
        DesignerProfile designer = designerProfileRepository.findByUserId(currentUser.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si designer aliyesajiliwa"));
        return ApiResponse.ok(documentRepository.findByDesignerId(designer.getId()));
    }

    @GetMapping("/admin/pending")
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<List<VerificationDocument>> pendingDocuments() {
        return ApiResponse.ok(documentRepository.findByStatus(DocumentStatus.PENDING));
    }

    @PostMapping("/admin/documents/{id}/approve")
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<VerificationDocument> approve(@PathVariable Long id) {
        VerificationDocument document = documentRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Hati haijapatikana"));

        document.setStatus(DocumentStatus.APPROVED);
        documentRepository.save(document);

        DesignerProfile designer = document.getDesigner();
        designer.setVerificationStatus(VerificationStatus.VERIFIED);
        designerProfileRepository.save(designer);

        return ApiResponse.ok("Designer ameidhinishwa (VERIFIED)", document);
    }

    @PostMapping("/admin/documents/{id}/reject")
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<VerificationDocument> reject(@PathVariable Long id) {
        VerificationDocument document = documentRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Hati haijapatikana"));

        document.setStatus(DocumentStatus.REJECTED);
        documentRepository.save(document);

        DesignerProfile designer = document.getDesigner();
        designer.setVerificationStatus(VerificationStatus.REJECTED);
        designerProfileRepository.save(designer);

        return ApiResponse.ok("Hati imekataliwa", document);
    }

    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String phone = auth.getName();
        return userRepository.findByPhone(phone)
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
    }
}