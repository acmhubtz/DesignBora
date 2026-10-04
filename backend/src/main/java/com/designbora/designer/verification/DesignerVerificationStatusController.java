package com.designbora.designer.verification;

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

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;

/** Mbunifu anaona hali ya uhakiki wake, sababu ya kukataliwa, na nyaraka zake */
@RestController
@RequestMapping("/api/verification")
@RequiredArgsConstructor
public class DesignerVerificationStatusController {

    private final DesignerProfileRepository designerProfileRepository;
    private final VerificationDocumentRepository documentRepository;
    private final UserRepository userRepository;

    public record DocumentItem(Long id, String documentType, String status, LocalDateTime uploadedAt) {
    }

    public record StatusResponse(String verificationStatus, String verificationNote, List<DocumentItem> documents) {
    }

    @GetMapping("/status")
    public ApiResponse<StatusResponse> status() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        User user = userRepository.findByPhone(auth.getName())
                .orElseThrow(() -> ApiException.notFound("Mtumiaji hajapatikana"));
        DesignerProfile designer = designerProfileRepository.findByUserId(user.getId())
                .orElseThrow(() -> ApiException.badRequest("Wewe si mbunifu aliyesajiliwa"));

        List<DocumentItem> docs = documentRepository.findByDesignerId(designer.getId()).stream()
                .sorted(Comparator.comparing(VerificationDocument::getId).reversed())
                .map(d -> new DocumentItem(d.getId(), d.getDocumentType().name(), d.getStatus().name(), d.getUploadedAt()))
                .toList();

        return ApiResponse.ok(new StatusResponse(
                designer.getVerificationStatus().name(), designer.getVerificationNote(), docs));
    }
}
