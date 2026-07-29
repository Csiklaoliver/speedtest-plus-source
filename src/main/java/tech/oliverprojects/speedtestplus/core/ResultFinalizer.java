package tech.oliverprojects.speedtestplus.core;

import java.util.Random;

/** Finalizes configured ranges once per test session. */
public final class ResultFinalizer {
    private ResultFinalizer() {
    }

    public static FinalResult finalizeOnce(
            SpeedPlusConfig validated,
            long sessionSeed,
            FinalResult measured) {
        SpeedPlusConfig config = validated == null ? new SpeedPlusConfig() : validated;
        FinalResult baseline = measured == null
                ? new FinalResult(null, null, null, null, null, null, null, null)
                : measured;
        Random random = new Random(sessionSeed);
        Double download = choose(config.downloadMinMbps, config.downloadMaxMbps, random);
        Double upload = choose(config.uploadMinMbps, config.uploadMaxMbps, random);
        return new FinalResult(
                download == null ? baseline.downloadMbps : download,
                upload == null ? baseline.uploadMbps : upload,
                config.pingMs == null ? baseline.pingMs : config.pingMs,
                config.jitterMs == null ? baseline.jitterMs : config.jitterMs,
                config.packetLossPercent == null
                        ? baseline.packetLossPercent : config.packetLossPercent,
                config.isp == null ? baseline.isp : config.isp,
                config.serverProvider == null ? baseline.serverProvider : config.serverProvider,
                config.serverLocation == null ? baseline.serverLocation : config.serverLocation);
    }

    private static Double choose(Double min, Double max, Random random) {
        if (min == null || max == null) return null;
        if (min.doubleValue() == max.doubleValue()) return min;
        return min + random.nextDouble() * (max - min);
    }
}
