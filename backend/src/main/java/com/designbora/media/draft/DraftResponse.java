package com.designbora.media.draft;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Jibu la draft kwa app. Kwa makusudi HALINA originalFileUrl (Escrow).
 *
 * fileType: IMAGE | PDF | VIDEO | ARCHIVE | OTHER  (aina ya PREVIEW, si ya faili la asili)
 * extension: aina ya faili la asili (docx, psd, mp4...)
 * watermarkedFileUrl: URL ya preview; tupu ("") kama hakuna
 * archiveEntries: orodha ya faili ndani ya zip (ARCHIVE tu)
 */
public record DraftResponse(
        Long id,
        Integer versionNo,
        String status,
        LocalDateTime submittedAt,
        String fileType,
        String extension,
        Long fileSize,
        String watermarkedFileUrl,
        List<ArchiveEntry> archiveEntries
) {
    public record ArchiveEntry(String name, long size) {
    }
}
