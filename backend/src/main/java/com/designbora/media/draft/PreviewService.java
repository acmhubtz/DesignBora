package com.designbora.media.draft;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Comparator;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;

/**
 * Inatengeneza nakala ya "preview" yenye watermark kwa aina nyingi za faili.
 * Faili la asili halibadilishwi. Ikishindwa, inarudisha null (draft inaendelea bila preview).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PreviewService {

    static final Set<String> DIRECT_IMAGES = Set.of("jpg", "jpeg", "png");
    static final Set<String> CONVERT_IMAGES = Set.of("psd", "svg", "tif", "tiff", "gif", "webp", "bmp", "heic");
    static final Set<String> POSTSCRIPT = Set.of("ai", "eps");
    static final Set<String> DOCUMENTS = Set.of("doc", "docx", "odt", "rtf", "txt",
            "xls", "xlsx", "ods", "ppt", "pptx", "odp");
    static final Set<String> VIDEOS = Set.of("mp4", "mov", "avi", "mkv", "webm", "3gp");

    private static final Duration CONVERT_TIMEOUT = Duration.ofMinutes(2);
    private static final Duration VIDEO_TIMEOUT = Duration.ofMinutes(4);

    private final WatermarkService watermarkService;

    /** @return jina la faili la preview (ndani ya folda ile ile), au null kama hakuna preview */
    public String createPreview(Path original, String extension) {
        Path dir = original.getParent();
        String base = stripExtension(original.getFileName().toString());

        try {
            if (DIRECT_IMAGES.contains(extension)) {
                Path target = dir.resolve("wm_" + base + "." + extension);
                watermarkService.watermarkImage(original, target);
                return target.getFileName().toString();
            }

            if ("pdf".equals(extension)) {
                Path target = dir.resolve("wm_" + base + ".pdf");
                watermarkService.watermarkPdf(original, target);
                return target.getFileName().toString();
            }

            if (CONVERT_IMAGES.contains(extension) || POSTSCRIPT.contains(extension)) {
                Path temp = dir.resolve("tmp_" + base + ".png");
                try {
                    if (POSTSCRIPT.contains(extension)) {
                        run(CONVERT_TIMEOUT, "gs", "-dSAFER", "-dBATCH", "-dNOPAUSE", "-sDEVICE=png16m",
                                "-r150", "-dFirstPage=1", "-dLastPage=1",
                                "-sOutputFile=" + temp, original.toString());
                    } else {
                        run(CONVERT_TIMEOUT, "convert", original + "[0]", "-background", "white",
                                "-flatten", "-resize", "2000x2000>", temp.toString());
                    }
                    Path target = dir.resolve("wm_" + base + ".png");
                    watermarkService.watermarkImage(temp, target);
                    return target.getFileName().toString();
                } finally {
                    Files.deleteIfExists(temp);
                }
            }

            if (DOCUMENTS.contains(extension)) {
                Path tempDir = Files.createTempDirectory("designbora-preview");
                try {
                    run(CONVERT_TIMEOUT, "soffice", "--headless",
                            "-env:UserInstallation=file:///tmp/designbora-lo-profile",
                            "--convert-to", "pdf", "--outdir", tempDir.toString(), original.toString());
                    Path pdf = tempDir.resolve(base + ".pdf");
                    Path target = dir.resolve("wm_" + base + ".pdf");
                    watermarkService.watermarkPdf(pdf, target);
                    return target.getFileName().toString();
                } finally {
                    deleteRecursively(tempDir);
                }
            }

            if (VIDEOS.contains(extension)) {
                Path target = dir.resolve("wm_" + base + ".mp4");
                run(VIDEO_TIMEOUT, "ffmpeg", "-y", "-i", original.toString(),
                        "-t", "30",
                        "-vf", "scale=-2:480,drawtext=text='DesignBora - PREVIEW':fontcolor=white@0.55"
                                + ":fontsize=h/12:x=(w-text_w)/2:y=(h-text_h)/2",
                        "-c:v", "libx264", "-preset", "veryfast", "-crf", "30",
                        "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart",
                        target.toString());
                return target.getFileName().toString();
            }
        } catch (Exception e) {
            log.warn("Preview imeshindwa kwa {} ({}): {}", original.getFileName(), extension, e.getMessage());
        }
        return null;
    }

    private static void run(Duration timeout, String... command) throws IOException, InterruptedException {
        Process process = new ProcessBuilder(command)
                .redirectErrorStream(true)
                .redirectOutput(ProcessBuilder.Redirect.DISCARD)
                .start();
        if (!process.waitFor(timeout.toSeconds(), TimeUnit.SECONDS)) {
            process.destroyForcibly();
            throw new IOException(command[0] + ": muda umeisha");
        }
        if (process.exitValue() != 0) {
            throw new IOException(command[0] + " imeshindwa (exit " + process.exitValue() + ")");
        }
    }

    private static String stripExtension(String filename) {
        int dot = filename.lastIndexOf('.');
        return dot > 0 ? filename.substring(0, dot) : filename;
    }

    private static void deleteRecursively(Path dir) {
        try (Stream<Path> paths = Files.walk(dir)) {
            paths.sorted(Comparator.reverseOrder()).forEach(p -> {
                try {
                    Files.deleteIfExists(p);
                } catch (IOException ignored) {
                    // si muhimu
                }
            });
        } catch (IOException ignored) {
            // si muhimu
        }
    }
}
