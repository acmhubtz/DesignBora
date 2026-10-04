package com.designbora.admin.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/** /api/admin/** inafikiwa kutoka IP zilizoruhusiwa tu (app.admin.allowed-ips). Tupu = zote. */
@Component
public class AdminIpFilter extends OncePerRequestFilter {

    private final Set<String> allowedIps;

    public AdminIpFilter(@Value("${app.admin.allowed-ips:}") String allowedIps) {
        this.allowedIps = Arrays.stream(allowedIps.split(","))
                .map(String::trim)
                .filter(ip -> !ip.isEmpty())
                .collect(Collectors.toSet());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        if (!allowedIps.isEmpty()
                && request.getRequestURI().startsWith("/api/admin/")
                && !allowedIps.contains(request.getRemoteAddr())) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"success\":false,\"message\":\"Admin Panel haipatikani kutoka mtandao huu\"}");
            return;
        }
        chain.doFilter(request, response);
    }
}
