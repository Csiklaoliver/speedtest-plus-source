package tech.oliverprojects.speedtestplus.core;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Locale;
import java.util.zip.CRC32;

/** Versioned corruption-detecting envelope for schema-validated theme JSON. */
public final class ThemeCodeCodec {
    private static final String PREFIX = "SPT1.";
    private static final int MAX_BYTES = 4096;

    private ThemeCodeCodec() {
    }

    public static String encode(String canonicalThemeJson) {
        if (canonicalThemeJson == null) throw new IllegalArgumentException("theme JSON is required");
        byte[] bytes = canonicalThemeJson.getBytes(StandardCharsets.UTF_8);
        if (bytes.length == 0 || bytes.length > MAX_BYTES) {
            throw new IllegalArgumentException("theme JSON size is invalid");
        }
        String body = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        return PREFIX + body + "." + crcHex(bytes);
    }

    public static String decode(String code) {
        if (code == null || !code.startsWith(PREFIX) || code.length() > 8192) {
            throw new IllegalArgumentException("invalid theme code");
        }
        int separator = code.lastIndexOf('.');
        if (separator <= PREFIX.length() || separator == code.length() - 1) {
            throw new IllegalArgumentException("invalid theme code");
        }
        byte[] bytes;
        try {
            bytes = Base64.getUrlDecoder().decode(code.substring(PREFIX.length(), separator));
        } catch (IllegalArgumentException error) {
            throw new IllegalArgumentException("invalid theme encoding");
        }
        if (bytes.length == 0 || bytes.length > MAX_BYTES) {
            throw new IllegalArgumentException("theme JSON size is invalid");
        }
        String actual = crcHex(bytes);
        String expected = code.substring(separator + 1).toLowerCase(Locale.US);
        if (!actual.equals(expected)) throw new IllegalArgumentException("theme code checksum failed");
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static String crcHex(byte[] bytes) {
        CRC32 crc = new CRC32();
        crc.update(bytes);
        return String.format(Locale.US, "%08x", crc.getValue());
    }
}
