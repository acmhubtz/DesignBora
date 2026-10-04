package com.designbora.admin.security;

import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.ByteArrayOutputStream;
import java.net.URLEncoder;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Instant;

/** TOTP (RFC 6238): namba ya tarakimu 6 inayobadilika kila sekunde 30 (Google Authenticator n.k.) */
@Service
public class TotpService {

    private static final String BASE32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    private static final SecureRandom RANDOM = new SecureRandom();

    public String generateSecret() {
        byte[] bytes = new byte[20];
        RANDOM.nextBytes(bytes);
        return base32Encode(bytes);
    }

    public String otpauthUrl(String secret, String account) {
        String label = URLEncoder.encode("DesignBora Admin:" + account, StandardCharsets.UTF_8).replace("+", "%20");
        return "otpauth://totp/" + label + "?secret=" + secret
                + "&issuer=DesignBora&algorithm=SHA1&digits=6&period=30";
    }

    /**
     * @param lastUsedStep hatua ya mwisho iliyotumika (kuzuia namba moja kutumika mara mbili)
     * @return hatua (time-step) iliyolingana, au -1 kama namba si sahihi
     */
    public long verify(String secret, String code, Long lastUsedStep) {
        if (secret == null || code == null || !code.trim().matches("\\d{6}")) {
            return -1;
        }
        byte[] key = base32Decode(secret);
        long current = Instant.now().getEpochSecond() / 30;
        for (long step = current - 1; step <= current + 1; step++) {
            if (lastUsedStep != null && step <= lastUsedStep) continue;
            if (generate(key, step).equals(code.trim())) return step;
        }
        return -1;
    }

    private static String generate(byte[] key, long step) {
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(key, "HmacSHA1"));
            byte[] hash = mac.doFinal(ByteBuffer.allocate(8).putLong(step).array());
            int offset = hash[hash.length - 1] & 0xF;
            int binary = ((hash[offset] & 0x7f) << 24)
                    | ((hash[offset + 1] & 0xff) << 16)
                    | ((hash[offset + 2] & 0xff) << 8)
                    | (hash[offset + 3] & 0xff);
            return String.format("%06d", binary % 1_000_000);
        } catch (Exception e) {
            throw new IllegalStateException("Imeshindwa kutengeneza TOTP", e);
        }
    }

    static String base32Encode(byte[] data) {
        StringBuilder out = new StringBuilder();
        int buffer = 0;
        int bits = 0;
        for (byte b : data) {
            buffer = (buffer << 8) | (b & 0xFF);
            bits += 8;
            while (bits >= 5) {
                out.append(BASE32.charAt((buffer >> (bits - 5)) & 31));
                bits -= 5;
                buffer &= (1 << bits) - 1;
            }
        }
        if (bits > 0) {
            out.append(BASE32.charAt((buffer << (5 - bits)) & 31));
        }
        return out.toString();
    }

    static byte[] base32Decode(String text) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        int buffer = 0;
        int bits = 0;
        for (char c : text.toUpperCase().replace("=", "").toCharArray()) {
            int value = BASE32.indexOf(c);
            if (value < 0) continue;
            buffer = (buffer << 5) | value;
            bits += 5;
            if (bits >= 8) {
                out.write((buffer >> (bits - 8)) & 0xFF);
                bits -= 8;
                buffer &= (1 << bits) - 1;
            }
        }
        return out.toByteArray();
    }
}
