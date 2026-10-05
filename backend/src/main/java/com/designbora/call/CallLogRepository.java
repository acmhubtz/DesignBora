package com.designbora.call;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface CallLogRepository extends JpaRepository<CallLog, Long> {

    @Query("select c from CallLog c where c.status in :statuses and (c.caller.id = :userId or c.callee.id = :userId)")
    List<CallLog> findActiveForUser(@Param("userId") Long userId, @Param("statuses") Collection<CallStatus> statuses);

    Optional<CallLog> findFirstByCalleeIdAndStatusAndCreatedAtAfterOrderByIdDesc(
            Long calleeId, CallStatus status, LocalDateTime after);

    List<CallLog> findByStatusAndCreatedAtBefore(CallStatus status, LocalDateTime before);

    List<CallLog> findByStatusAndAnsweredAtBefore(CallStatus status, LocalDateTime before);
}
