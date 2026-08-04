package tech.oliverprojects.speedtestplus.core;

import java.util.Locale;
import java.util.Map;

/**
 * Creates a copy-ready, privacy-safe support snapshot.  It deliberately
 * reports only override presence and finalized scalar values; it never emits
 * free-text identities, IP addresses, account data, location, or device IDs.
 */
public final class DiagnosticsSnapshot {
    private DiagnosticsSnapshot() { }

    public static String build(
            String platform,
            String operatingSystem,
            String appVersion,
            Map<String, ?> configuration,
            Map<String, ?> lastResult,
            boolean active,
            int activeOverrideCount,
            int themeIndex,
            boolean testActive) {
        Map<String, ?> config = configuration == null ? java.util.Collections.<String, Object>emptyMap() : configuration;
        Map<String, ?> result = lastResult == null ? java.util.Collections.<String, Object>emptyMap() : lastResult;
        String mode = testActive ? "test running" : "idle";
        if (Boolean.TRUE.equals(config.get("offline_mode"))) mode = "offline demo";
        else if (Boolean.TRUE.equals(config.get("data_saver_mode"))) mode = "data saver";
        StringBuilder text = new StringBuilder(768);
        text.append("Speedtest+ Diagnostics\n");
        text.append("Platform: ").append(clean(platform, "unknown")).append('\n');
        text.append("OS: ").append(clean(operatingSystem, "unknown")).append('\n');
        text.append("App build: ").append(clean(appVersion, "unknown")).append('\n');
        text.append("Mode: ").append(mode).append('\n');
        text.append("Theme index: ").append(Math.max(0, themeIndex)).append('\n');
        text.append("Active overrides: ").append(Math.max(0, active ? activeOverrideCount : 0)).append('\n');
        appendPresence(text, "Download override", config, "download_min", "download_max");
        appendPresence(text, "Upload override", config, "upload_min", "upload_max");
        appendPresence(text, "Ping override", config, "ping");
        appendPresence(text, "Jitter override", config, "jitter");
        appendPresence(text, "Packet-loss override", config, "packet_loss");
        appendPresence(text, "ISP override", config, "isp");
        appendPresence(text, "Server-provider override", config, "server_provider");
        appendPresence(text, "Server-location override", config, "server_location");
        text.append('\n').append("Last local result\n");
        if (result.isEmpty()) {
            text.append("No completed local result\n");
        } else {
            text.append("Download: ").append(number(result.get("download_mbps"), " Mbps")).append('\n');
            text.append("Upload: ").append(number(result.get("upload_mbps"), " Mbps")).append('\n');
            text.append("Ping: ").append(integer(result.get("ping_ms"), " ms")).append('\n');
            text.append("Jitter: ").append(integer(result.get("jitter_ms"), " ms")).append('\n');
            text.append("Packet loss: ").append(number(result.get("packet_loss"), "%")).append('\n');
        }
        text.append('\n').append("Privacy: this snapshot contains no IP address, account, device ID, exact location, credentials, or identity text.");
        return text.toString();
    }

    private static void appendPresence(StringBuilder text, String label, Map<String, ?> values, String... keys) {
        boolean present = false;
        for (String key : keys) {
            Object value = values.get(key);
            if (value instanceof String ? !((String) value).trim().isEmpty() : value != null) {
                present = true;
                break;
            }
        }
        text.append(label).append(": ").append(present ? "set" : "blank").append('\n');
    }

    private static String number(Object value, String suffix) {
        if (!(value instanceof Number)) return "—";
        return String.format(Locale.US, "%.1f%s", ((Number) value).doubleValue(), suffix);
    }

    private static String integer(Object value, String suffix) {
        if (!(value instanceof Number)) return "—";
        return String.format(Locale.US, "%d%s", ((Number) value).longValue(), suffix);
    }

    private static String clean(String value, String fallback) {
        if (value == null || value.trim().isEmpty()) return fallback;
        String safe = value.replace('\r', ' ').replace('\n', ' ').trim();
        return safe.length() > 64 ? safe.substring(0, 64) : safe;
    }
}
