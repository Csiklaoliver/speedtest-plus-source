package tech.oliverprojects.speedtestplus.core;

/**
 * Shared contracts for the two optional test modes.
 *
 * <p>The native Android/iOS adapters are responsible for applying the
 * data-saver limits to their own engine configuration.  Keeping the values in
 * this dependency-free class prevents the platforms from drifting apart.</p>
 */
public final class TestMode {
    /** Conservative per-connection cap used by both platform adapters. */
    public static final int DATA_SAVER_MAX_BYTES_PER_CONNECTION = 262144;
    /** Maximum transfer time used by both platform adapters. */
    public static final int DATA_SAVER_MAX_DURATION_SECONDS = 2;

    private TestMode() {
    }

    public static boolean isOffline(SpeedPlusConfig config) {
        return config != null && config.offlineMode;
    }

    public static boolean isDataSaver(SpeedPlusConfig config) {
        return config != null && config.dataSaverMode && !config.offlineMode;
    }

    /**
     * Produces a local, deterministic demo result when no network is
     * available.  The caller must mark the result as {@code offline_demo} in
     * its platform result model and must not send it to a remote service.
     * Blank metric fields use modest, obviously synthetic defaults; entered
     * ranges/latency/identity values are still honoured by ResultFinalizer.
     */
    public static FinalResult offlineResult(SpeedPlusConfig validated, long sessionSeed) {
        FinalResult baseline = new FinalResult(
                100.0d,
                20.0d,
                20,
                3,
                0.0d,
                "Offline demo",
                "Local simulation",
                "Offline");
        return ResultFinalizer.finalizeOnce(validated, sessionSeed, baseline);
    }

    public static boolean allowsRemoteSubmission(SpeedPlusConfig config) {
        return !isOffline(config);
    }
}
