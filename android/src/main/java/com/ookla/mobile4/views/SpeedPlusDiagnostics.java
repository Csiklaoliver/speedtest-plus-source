package com.ookla.mobile4.views;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.widget.Toast;

import java.util.Locale;

/**
 * Android adapter for the privacy-safe diagnostics snapshot.  The controls
 * dialog calls {@link #copyToClipboard(Context)}; this class intentionally
 * reads only Speedtest+ private preferences and Android release metadata.
 */
public final class SpeedPlusDiagnostics {
    private static final String PREFS = "speedtest_plus_mod";
    private static final String[] OVERRIDES = {
            "download_min", "download_max", "upload_min", "upload_max",
            "ping", "jitter", "packet_loss", "isp", "server_provider", "server_location"
    };

    private SpeedPlusDiagnostics() { }

    public static void copyToClipboard(Context context) {
        if (context == null) return;
        String text = build(context);
        Object service = context.getSystemService(Context.CLIPBOARD_SERVICE);
        if (service instanceof ClipboardManager) {
            ((ClipboardManager) service).setPrimaryClip(ClipData.newPlainText("Speedtest+ diagnostics", text));
            Toast.makeText(context, "Diagnostics copied. No identifiers or identity text included.", Toast.LENGTH_SHORT).show();
        }
    }

    public static String build(Context context) {
        if (context == null) return "Speedtest+ Diagnostics\nUnavailable";
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        int count = activeOverrideCount(prefs);
        String mode = prefs.getBoolean("offline_mode", false) ? "offline demo"
                : prefs.getBoolean("data_saver_mode", false) ? "data saver" : "idle";
        String version = "unknown";
        try {
            android.content.pm.PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            if (info.versionName != null) version = clean(info.versionName, "unknown");
        } catch (Exception ignored) { }
        StringBuilder text = new StringBuilder(768);
        text.append("Speedtest+ Diagnostics\n");
        text.append("Platform: Android\n");
        text.append("OS: ").append(clean(Build.VERSION.RELEASE, "unknown")).append('\n');
        text.append("App build: ").append(version).append('\n');
        text.append("Mode: ").append(mode).append('\n');
        text.append("Theme index: ").append(Math.max(0, prefs.getInt("theme_palette_index", 0))).append('\n');
        text.append("Active overrides: ").append(count).append('\n');
        presence(text, "Download override", prefs, "active_download_min", "active_download_max");
        presence(text, "Upload override", prefs, "active_upload_min", "active_upload_max");
        presence(text, "Ping override", prefs, "active_ping");
        presence(text, "Jitter override", prefs, "active_jitter");
        presence(text, "Packet-loss override", prefs, "active_packet_loss");
        presence(text, "ISP override", prefs, "active_isp");
        presence(text, "Server-provider override", prefs, "active_server_provider");
        presence(text, "Server-location override", prefs, "active_server_location");
        text.append('\n').append("Last local result\n");
        if (!prefs.getBoolean("last_download_valid", false) && !prefs.getBoolean("last_upload_valid", false)) {
            text.append("No completed local result\n");
        } else {
            text.append("Download: ").append(number(prefs, "last_download", "last_download_valid", " Mbps")).append('\n');
            text.append("Upload: ").append(number(prefs, "last_upload", "last_upload_valid", " Mbps")).append('\n');
            text.append("Ping: ").append(integer(prefs, "last_ping", " ms")).append('\n');
            text.append("Jitter: ").append(integer(prefs, "last_jitter", " ms")).append('\n');
            text.append("Packet loss: ").append(number(prefs, "last_packet_loss", null, "%")).append('\n');
        }
        text.append('\n').append("Privacy: this snapshot contains no IP address, account, device ID, exact location, credentials, or identity text.");
        return text.toString();
    }

    private static int activeOverrideCount(SharedPreferences prefs) {
        int count = 0;
        if (filled(prefs, "active_download_min") || filled(prefs, "active_download_max")) count++;
        if (filled(prefs, "active_upload_min") || filled(prefs, "active_upload_max")) count++;
        if (filled(prefs, "active_ping")) count++;
        if (filled(prefs, "active_jitter")) count++;
        if (filled(prefs, "active_packet_loss")) count++;
        if (filled(prefs, "active_isp")) count++;
        if (filled(prefs, "active_server_provider")) count++;
        if (filled(prefs, "active_server_location")) count++;
        return count;
    }

    private static void presence(StringBuilder out, String label, SharedPreferences prefs, String... keys) {
        boolean present = false;
        for (String key : keys) if (filled(prefs, key)) { present = true; break; }
        out.append(label).append(": ").append(present ? "set" : "blank").append('\n');
    }

    private static boolean filled(SharedPreferences prefs, String key) {
        return prefs.contains(key) && !prefs.getString(key, "").trim().isEmpty();
    }

    private static String number(SharedPreferences prefs, String key, String validKey, String suffix) {
        if (validKey != null && !prefs.getBoolean(validKey, false)) return "N/A";
        try { return String.format(Locale.US, "%.1f%s", Double.parseDouble(prefs.getString(key, "")), suffix); }
        catch (RuntimeException ignored) { return "N/A"; }
    }

    private static String integer(SharedPreferences prefs, String key, String suffix) {
        try { return Long.parseLong(prefs.getString(key, "")) + suffix; }
        catch (RuntimeException ignored) { return "N/A"; }
    }

    private static String clean(String value, String fallback) {
        if (value == null || value.trim().isEmpty()) return fallback;
        String safe = value.replace('\r', ' ').replace('\n', ' ').trim();
        return safe.length() > 64 ? safe.substring(0, 64) : safe;
    }
}
