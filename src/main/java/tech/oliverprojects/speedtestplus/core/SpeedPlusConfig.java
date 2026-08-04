package tech.oliverprojects.speedtestplus.core;

/**
 * Platform-neutral optional configuration. Null values preserve measurements.
 * This class contains no Android or third-party application dependencies.
 */
public final class SpeedPlusConfig {
    public Double downloadMinMbps;
    public Double downloadMaxMbps;
    public Double uploadMinMbps;
    public Double uploadMaxMbps;
    public Integer pingMs;
    public Integer jitterMs;
    public Double packetLossPercent;
    public String isp;
    public String serverProvider;
    public String serverLocation;

    /**
     * Run a clearly-labelled local demonstration without opening a network
     * connection.  Platform adapters must never submit this result remotely.
     */
    public boolean offlineMode;

    /**
     * Keep the normal measured test, but ask the native engine to use a small
     * per-connection byte/time budget.  The adapter must disclose that the
     * resulting throughput is a bounded, data-saving measurement.
     */
    public boolean dataSaverMode;

    public SpeedPlusConfig copy() {
        SpeedPlusConfig value = new SpeedPlusConfig();
        value.downloadMinMbps = downloadMinMbps;
        value.downloadMaxMbps = downloadMaxMbps;
        value.uploadMinMbps = uploadMinMbps;
        value.uploadMaxMbps = uploadMaxMbps;
        value.pingMs = pingMs;
        value.jitterMs = jitterMs;
        value.packetLossPercent = packetLossPercent;
        value.isp = isp;
        value.serverProvider = serverProvider;
        value.serverLocation = serverLocation;
        value.offlineMode = offlineMode;
        value.dataSaverMode = dataSaverMode;
        return value;
    }
}
