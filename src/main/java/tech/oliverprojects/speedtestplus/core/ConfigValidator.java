package tech.oliverprojects.speedtestplus.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Validates untrusted UI/profile input without throwing into the host UI. */
public final class ConfigValidator {
    private static final double MAX_MBPS = Long.MAX_VALUE / 125000.0d;

    private ConfigValidator() {
    }

    public static Result validate(SpeedPlusConfig input) {
        SpeedPlusConfig output = input == null ? new SpeedPlusConfig() : input.copy();
        List<String> warnings = new ArrayList<String>();

        if (!validRange(output.downloadMinMbps, output.downloadMaxMbps)) {
            output.downloadMinMbps = null;
            output.downloadMaxMbps = null;
            warnings.add("Download range was ignored");
        }
        if (!validRange(output.uploadMinMbps, output.uploadMaxMbps)) {
            output.uploadMinMbps = null;
            output.uploadMaxMbps = null;
            warnings.add("Upload range was ignored");
        }
        if (!validLatency(output.pingMs)) {
            output.pingMs = null;
            warnings.add("Ping was ignored");
        }
        if (!validLatency(output.jitterMs)) {
            output.jitterMs = null;
            warnings.add("Jitter was ignored");
        }
        if (!validLoss(output.packetLossPercent)) {
            output.packetLossPercent = null;
            warnings.add("Packet loss was ignored");
        } else if (output.packetLossPercent != null) {
            output.packetLossPercent =
                    Math.round(output.packetLossPercent.doubleValue() * 10.0d) / 10.0d;
        }

        output.isp = identity(output.isp);
        output.serverProvider = identity(output.serverProvider);
        output.serverLocation = identity(output.serverLocation);
        return new Result(output, warnings);
    }

    private static boolean validRange(Double min, Double max) {
        if (min == null && max == null) return true;
        if (min == null || max == null) return false;
        return finite(min) && finite(max) && min >= 0.0d && max >= min && max <= MAX_MBPS;
    }

    private static boolean validLatency(Integer value) {
        return value == null || (value >= 0 && value <= 9999);
    }

    private static boolean validLoss(Double value) {
        return value == null || (finite(value) && value >= 0.0d && value <= 100.0d);
    }

    private static boolean finite(Double value) {
        return value != null && !value.isNaN() && !value.isInfinite();
    }

    private static String identity(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        if (trimmed.length() == 0) return null;
        return trimmed.length() <= 64 ? trimmed : trimmed.substring(0, 64);
    }

    public static final class Result {
        private final SpeedPlusConfig config;
        private final List<String> warnings;

        private Result(SpeedPlusConfig config, List<String> warnings) {
            this.config = config;
            this.warnings = Collections.unmodifiableList(new ArrayList<String>(warnings));
        }

        public SpeedPlusConfig config() {
            return config.copy();
        }

        public List<String> warnings() {
            return warnings;
        }
    }
}
