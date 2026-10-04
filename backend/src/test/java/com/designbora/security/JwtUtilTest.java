package com.designbora.security;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class JwtUtilTest {

    @Test
    void generatesAndParsesTokenCorrectly() {
        JwtUtil jwtUtil = new JwtUtil(
                "test-secret-key-that-is-at-least-32-characters-long",
                86400000L
        );

        String token = jwtUtil.generateToken(1L, "+255712345678", "CUSTOMER");

        assertTrue(jwtUtil.isValid(token));
        assertEquals(1L, jwtUtil.extractUserId(token));
        assertEquals("+255712345678", jwtUtil.extractPhone(token));
    }

    @Test
    void invalidTokenFailsValidation() {
        JwtUtil jwtUtil = new JwtUtil(
                "test-secret-key-that-is-at-least-32-characters-long",
                86400000L
        );

        assertFalse(jwtUtil.isValid("this.is.not.a.valid.token"));
    }
}