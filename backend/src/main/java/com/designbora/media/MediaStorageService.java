package com.designbora.media;

import com.designbora.common.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class MediaStorageService {

    private final StorageProperties props;

    public String saveDocumentFile(MultipartFile file) {
        return save(file, props.getDocumentsPath());
    }

    public String savePortfolioFile(MultipartFile file) {
        return save(file, props.getPortfolioPath());
    }

    public String saveDraftFile(MultipartFile file) {
        return save(file, props.getDraftsPath());
    }

    public String saveFinalFile(MultipartFile file) {
        return save(file, props.getFinalsPath());
    }

    public String saveAvatarFile(MultipartFile file) {
        return save(file, "avatars");
    }

    /** Nakala ya faili la asili kwenda folda ya mwisho (inayoruhusiwa kupakuliwa). */
    public String copyToFinals(String relativeUrl) {
        try {
            Path source = resolve(relativeUrl);
            Path dir = Paths.get(props.getBasePath(), props.getFinalsPath());
            Files.createDirectories(dir);
            Path target = dir.resolve(source.getFileName());
            if (!Files.exists(target)) {
                Files.copy(source, target);
            }
            return "/uploads/" + props.getFinalsPath() + "/" + target.getFileName();
        } catch (IOException e) {
            throw ApiException.badRequest("Imeshindwa kuandaa faili la kupakua: " + e.getMessage());
        }
    }

    public Path resolve(String relativeUrl) {
        String cleaned = relativeUrl.replaceFirst("^/uploads/", "");
        return Paths.get(props.getBasePath(), cleaned);
    }

    private String save(MultipartFile file, String subfolder) {
        try {
            String extension = "";
            String original = file.getOriginalFilename();
            if (original != null && original.contains(".")) {
                extension = original.substring(original.lastIndexOf('.'));
            }
            String filename = UUID.randomUUID() + extension;

            Path dir = Paths.get(props.getBasePath(), subfolder);
            Files.createDirectories(dir);

            Path target = dir.resolve(filename);
            file.transferTo(target);

            return "/uploads/" + subfolder + "/" + filename;
        } catch (IOException e) {
            throw ApiException.badRequest("Imeshindwa kuhifadhi faili: " + e.getMessage());
        }
    }
}