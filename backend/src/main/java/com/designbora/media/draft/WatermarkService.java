package com.designbora.media.draft;

import com.designbora.common.ApiException;
import net.coobird.thumbnailator.Thumbnails;
import net.coobird.thumbnailator.geometry.Positions;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.pdfbox.pdmodel.graphics.state.PDExtendedGraphicsState;
import org.apache.pdfbox.util.Matrix;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

@Service
public class WatermarkService {

    private static final String WATERMARK_TEXT = "DesignBora - PREVIEW";

    public void watermarkImage(Path sourceImage, Path targetImage) {
        try {
            BufferedImage original = ImageIO.read(sourceImage.toFile());
            if (original == null) {
                throw ApiException.badRequest("Faili si picha sahihi (jpg/png)");
            }

            BufferedImage watermarkOverlay = buildWatermarkOverlay(original.getWidth(), original.getHeight());

            Files.createDirectories(targetImage.getParent());

            Thumbnails.of(original)
                    .size(original.getWidth(), original.getHeight())
                    .watermark(Positions.CENTER, watermarkOverlay, 0.4f)
                    .outputQuality(0.9)
                    .toFile(targetImage.toFile());

        } catch (IOException e) {
            throw ApiException.badRequest("Imeshindwa kuweka watermark: " + e.getMessage());
        }
    }

    public void watermarkPdf(Path sourcePdf, Path targetPdf) {
        try (PDDocument doc = Loader.loadPDF(sourcePdf.toFile())) {
            PDType1Font font = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);
            PDExtendedGraphicsState transparency = new PDExtendedGraphicsState();
            transparency.setNonStrokingAlphaConstant(0.25f);

            for (PDPage page : doc.getPages()) {
                PDRectangle box = page.getMediaBox();
                float width = box.getWidth();
                float height = box.getHeight();
                float fontSize = Math.max(18f, width / 18f);
                float textWidth = font.getStringWidth(WATERMARK_TEXT) / 1000f * fontSize;

                try (PDPageContentStream cs = new PDPageContentStream(
                        doc, page, PDPageContentStream.AppendMode.APPEND, true, true)) {
                    cs.setGraphicsStateParameters(transparency);
                    cs.setNonStrokingColor(0.5f, 0.5f, 0.5f);
                    cs.beginText();
                    cs.setFont(font, fontSize);
                    for (float y = -height; y < height * 2; y += fontSize * 4) {
                        for (float x = -width; x < width * 2; x += textWidth + 60) {
                            cs.setTextMatrix(Matrix.getRotateInstance(Math.toRadians(30), x, y));
                            cs.showText(WATERMARK_TEXT);
                        }
                    }
                    cs.endText();
                }
            }

            Files.createDirectories(targetPdf.getParent());
            doc.save(targetPdf.toFile());
        } catch (IOException e) {
            throw ApiException.badRequest("Imeshindwa kuweka watermark kwenye PDF: " + e.getMessage());
        }
    }

    private BufferedImage buildWatermarkOverlay(int width, int height) {
        BufferedImage overlay = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = overlay.createGraphics();

        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setColor(new Color(255, 255, 255, 180));

        int fontSize = Math.max(16, width / 20);
        g.setFont(new Font("SansSerif", Font.BOLD, fontSize));
        g.rotate(-Math.PI / 6, width / 2.0, height / 2.0);

        FontMetrics fm = g.getFontMetrics();
        int textWidth = fm.stringWidth(WATERMARK_TEXT);
        int stepX = textWidth + 50;
        int stepY = fontSize * 3;

        for (int y = -height; y < height * 2; y += stepY) {
            for (int x = -width; x < width * 2; x += stepX) {
                g.drawString(WATERMARK_TEXT, x, y);
            }
        }

        g.dispose();
        return overlay;
    }
}