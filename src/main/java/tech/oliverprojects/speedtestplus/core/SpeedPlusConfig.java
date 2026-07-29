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
        return value;
    }
}
