package com.designbora.notification;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.io.FileInputStream;
import java.io.InputStream;
import java.util.List;
import java.util.Map;

/** Inatuma arifa kupitia Firebase (nyuma ya pazia, haichelewishi majibu ya API) */
@Slf4j
@Component
@RequiredArgsConstructor
public class PushSender {

    static final String CHANNEL_ID = "designbora_default";

    private final DeviceTokenRepository deviceTokenRepository;

    @Value("${app.firebase.credentials:}")
    private String credentialsPath;

    private volatile boolean initialized;
    private volatile boolean disabled;

    private synchronized boolean ready() {
        if (initialized) return true;
        if (disabled) return false;
        if (credentialsPath == null || credentialsPath.isBlank()) {
            disabled = true;
            log.info("Arifa (FCM) zimezimwa: FIREBASE_CREDENTIALS haijawekwa");
            return false;
        }
        try (InputStream in = new FileInputStream(credentialsPath)) {
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(in))
                        .build());
            }
            initialized = true;
            log.info("Arifa (FCM) IMEWASHWA");
            return true;
        } catch (Exception e) {
            disabled = true;
            log.warn("Arifa (FCM) hazikuwashwa: {}", e.getMessage());
            return false;
        }
    }

    @Async
    public void notifyUser(Long userId, String title, String body, Map<String, String> data) {
        if (userId == null || !ready()) return;

        List<String> tokens = deviceTokenRepository.findByUserId(userId).stream()
                .map(DeviceToken::getToken)
                .toList();
        if (tokens.isEmpty()) return;

        MulticastMessage message = MulticastMessage.builder()
                .addAllTokens(tokens)
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body == null ? "" : (body.length() > 180 ? body.substring(0, 180) + "…" : body))
                        .build())
                .putAllData(data == null ? Map.of() : data)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder().setChannelId(CHANNEL_ID).build())
                        .build())
                .build();

        try {
            BatchResponse response = FirebaseMessaging.getInstance().sendEachForMulticast(message);
            List<SendResponse> results = response.getResponses();
            for (int i = 0; i < results.size(); i++) {
                SendResponse result = results.get(i);
                if (!result.isSuccessful() && result.getException() != null) {
                    MessagingErrorCode code = result.getException().getMessagingErrorCode();
                    // App imeondolewa au token imekufa: ifute
                    if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
                        deviceTokenRepository.deleteByToken(tokens.get(i));
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Arifa haikutumwa kwa mtumiaji #{}: {}", userId, e.getMessage());
        }
    }

    /**
     * Data-only + HIGH priority: inaamsha app hata ikiwa imefungwa au simu iko kwenye usingizi.
     * App yenyewe inaamua cha kuonyesha (mf. skrini ya simu inayoingia).
     */
    @Async
    public void sendData(Long userId, Map<String, String> data, long ttlSeconds) {
        if (userId == null || !ready()) return;

        List<String> tokens = deviceTokenRepository.findByUserId(userId).stream()
                .map(DeviceToken::getToken)
                .toList();
        if (tokens.isEmpty()) return;

        MulticastMessage message = MulticastMessage.builder()
                .addAllTokens(tokens)
                .putAllData(data)
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setTtl(ttlSeconds * 1000)
                        .build())
                .build();

        try {
            BatchResponse response = FirebaseMessaging.getInstance().sendEachForMulticast(message);
            List<SendResponse> results = response.getResponses();
            for (int i = 0; i < results.size(); i++) {
                SendResponse result = results.get(i);
                if (!result.isSuccessful() && result.getException() != null) {
                    MessagingErrorCode code = result.getException().getMessagingErrorCode();
                    if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
                        deviceTokenRepository.deleteByToken(tokens.get(i));
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Arifa ya data haikutumwa kwa mtumiaji #{}: {}", userId, e.getMessage());
        }
    }
}
