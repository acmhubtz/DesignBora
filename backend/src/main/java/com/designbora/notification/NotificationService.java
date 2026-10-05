package com.designbora.notification;

import com.designbora.designer.DesignerProfile;
import com.designbora.order.Order;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

/** Njia rahisi za kutuma arifa za oda (pamoja na taarifa za kufungua chat sahihi) */
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final PushSender pushSender;

    public void toCustomer(Order order, String type, String title, String body) {
        send(order, true, type, title, body);
    }

    public void toDesigner(Order order, String type, String title, String body) {
        send(order, false, type, title, body);
    }

    public void toUser(Long userId, String type, String title, String body) {
        pushSender.notifyUser(userId, title, body, Map.of("type", type));
    }

    private void send(Order order, boolean toCustomer, String type, String title, String body) {
        if (order == null) return;
        DesignerProfile designer = order.getDesigner();
        Long userId = toCustomer
                ? (order.getCustomer() == null ? null : order.getCustomer().getId())
                : (designer == null || designer.getUser() == null ? null : designer.getUser().getId());

        // "otherName" = mtu wa upande wa pili kwenye chat (kwa kichwa cha chat)
        String otherName = toCustomer ? designerName(designer)
                : (order.getCustomer() == null ? "Mteja" : order.getCustomer().getFullName());

        Map<String, String> data = new HashMap<>();
        data.put("type", type);
        data.put("orderId", String.valueOf(order.getId()));
        data.put("otherName", otherName == null ? "" : otherName);
        data.put("serviceTitle", order.getService() == null ? "Oda #" + order.getId() : order.getService().getTitle());

        // Thamani zinasomwa hapa (thread ya ombi), kisha kutumwa nyuma ya pazia
        pushSender.notifyUser(userId, title, body, data);
    }

    private static String designerName(DesignerProfile d) {
        if (d == null) return "Mbunifu";
        if (d.getCompanyName() != null && !d.getCompanyName().isBlank()) return d.getCompanyName();
        return d.getUser() == null ? "Mbunifu" : d.getUser().getFullName();
    }
}
