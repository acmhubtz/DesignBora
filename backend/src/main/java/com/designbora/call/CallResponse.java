package com.designbora.call;

public record CallResponse(
        Long id,
        Long orderId,
        String status,
        Long callerId,
        String callerName,
        String callerAvatarUrl,
        Long calleeId,
        String calleeName,
        String createdAt,
        String answeredAt
) {
    public static CallResponse from(CallLog c) {
        return new CallResponse(
                c.getId(),
                c.getOrder().getId(),
                c.getStatus().name(),
                c.getCaller().getId(),
                c.getCaller().getFullName(),
                null,
                c.getCallee().getId(),
                c.getCallee().getFullName(),
                c.getCreatedAt().toString(),
                c.getAnsweredAt() == null ? null : c.getAnsweredAt().toString());
    }
}
