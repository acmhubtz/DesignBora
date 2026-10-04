package com.designbora.payment;

import com.designbora.common.ApiException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Muunganisho wa pamoja na ClickPesa: token, checksum, maombi ya POST/GET */
@Slf4j
@Component
@ConditionalOnProperty(name = "app.clickpesa.enabled", havingValue = "true")
public class ClickPesaClient {

    private static final Pattern MESSAGE = Pattern.compile("\"message\"\\s*:\\s*\"([^\"]*)\"");

    private final ClickPesaProperties props;
    private final RestClient restClient;

    private String cachedToken;
    private Instant tokenExpiresAt = Instant.EPOCH;

    public ClickPesaClient(ClickPesaProperties props) {
        this.props = props;
        if (isBlank(props.getClientId()) || isBlank(props.getApiKey())) {
            throw new IllegalStateException(
                    "ClickPesa imewashwa lakini CLICKPESA_CLIENT_ID au CLICKPESA_API_KEY haijawekwa");
        }
        this.restClient = RestClient.builder().baseUrl(props.getBaseUrl()).build();
        log.info("ClickPesa IMEWASHWA (malipo na payouts halisi)");
    }

    /** Namba ya kumbukumbu: herufi na tarakimu tu, <= 20 */
    public static String reference(String prefix, Long id) {
        return prefix + id + "T" + Long.toString(System.currentTimeMillis() / 1000, 36).toUpperCase();
    }

    public Map<?, ?> post(String path, Map<String, Object> body) {
        Map<String, Object> payload = new TreeMap<>(body);
        if (!isBlank(props.getChecksumKey())) {
            payload.put("checksum", checksum(new TreeMap<>(body)));
        }
        try {
            return restClient.post()
                    .uri(path)
                    .header(HttpHeaders.AUTHORIZATION, token())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .body(Map.class);
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 401) cachedToken = null;
            log.warn("ClickPesa POST {} imeshindwa: {} {}", path, e.getStatusCode(), e.getResponseBodyAsString());
            throw ApiException.badRequest("ClickPesa: " + extractMessage(e));
        }
    }

    /** Kipengele cha kwanza cha jibu la orodha; null kama hakipo bado */
    public Map<?, ?> getFirst(String path, Object... uriVariables) {
        try {
            List<?> results = restClient.get()
                    .uri(path, uriVariables)
                    .header(HttpHeaders.AUTHORIZATION, token())
                    .retrieve()
                    .body(List.class);
            return (results != null && !results.isEmpty() && results.get(0) instanceof Map<?, ?> item) ? item : null;
        } catch (HttpClientErrorException.NotFound e) {
            return null;
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 401) cachedToken = null;
            log.warn("ClickPesa GET {} imeshindwa: {} {}", path, e.getStatusCode(), e.getResponseBodyAsString());
            return null;
        }
    }

    /** Jibu la orodha nzima; orodha tupu kama imeshindwa */
    public List<?> getList(String path) {
        try {
            List<?> results = restClient.get()
                    .uri(path)
                    .header(HttpHeaders.AUTHORIZATION, token())
                    .retrieve()
                    .body(List.class);
            return results == null ? List.of() : results;
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 401) cachedToken = null;
            log.warn("ClickPesa GET {} imeshindwa: {} {}", path, e.getStatusCode(), e.getResponseBodyAsString());
            return List.of();
        }
    }

    private synchronized String token() {
        if (cachedToken != null && Instant.now().isBefore(tokenExpiresAt)) {
            return cachedToken;
        }
        Map<?, ?> response = restClient.post()
                .uri("/generate-token")
                .header("client-id", props.getClientId())
                .header("api-key", props.getApiKey())
                .retrieve()
                .body(Map.class);
        Object token = response == null ? null : response.get("token");
        if (token == null) {
            throw ApiException.badRequest("ClickPesa: imeshindwa kupata token");
        }
        cachedToken = token.toString(); // tayari ina "Bearer "
        tokenExpiresAt = Instant.now().plus(Duration.ofMinutes(55));
        return cachedToken;
    }

    /** HMAC-SHA256 ya JSON iliyopangwa kwa alfabeti (payload ya ngazi moja: strings na namba) */
    private String checksum(Map<String, Object> sortedPayload) {
        StringBuilder json = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> entry : sortedPayload.entrySet()) {
            if (!first) json.append(',');
            first = false;
            json.append(quote(entry.getKey())).append(':');
            Object value = entry.getValue();
            json.append(value instanceof Number ? value.toString() : quote(String.valueOf(value)));
        }
        json.append('}');
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.getChecksumKey().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(json.toString().getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) hex.append(String.format("%02x", b));
            return hex.toString();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Imeshindwa kutengeneza checksum", e);
        }
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    private static String extractMessage(RestClientResponseException e) {
        Matcher m = MESSAGE.matcher(e.getResponseBodyAsString());
        return m.find() ? m.group(1) : ("hitilafu " + e.getStatusCode().value());
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
