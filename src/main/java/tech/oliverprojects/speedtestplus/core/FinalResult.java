package tech.oliverprojects.speedtestplus.core;

/** Immutable finalized values reused by display, persistence, share, and CSV. */
public final class FinalResult {
    public final Double downloadMbps;
    public final Double uploadMbps;
    public final Integer pingMs;
    public final Integer jitterMs;
    public final Double packetLossPercent;
    public final String isp;
    public final String serverProvider;
    public final String serverLocation;

    public FinalResult(
            Double downloadMbps,
            Double uploadMbps,
            Integer pingMs,
            Integer jitterMs,
            Double packetLossPercent,
            String isp,
            String serverProvider,
            String serverLocation) {
        this.downloadMbps = oneDecimal(downloadMbps);
        this.uploadMbps = oneDecimal(uploadMbps);
        this.pingMs = pingMs;
        this.jitterMs = jitterMs;
        this.packetLossPercent = oneDecimal(packetLossPercent);
        this.isp = isp;
        this.serverProvider = serverProvider;
        this.serverLocation = serverLocation;
    }

    private static Double oneDecimal(Double value) {
        return value == null ? null : Math.round(value.doubleValue() * 10.0d) / 10.0d;
    }
}
