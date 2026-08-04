import tech.oliverprojects.speedtestplus.core.ConfigValidator;
import tech.oliverprojects.speedtestplus.core.DiagnosticsSnapshot;
import tech.oliverprojects.speedtestplus.core.FinalResult;
import tech.oliverprojects.speedtestplus.core.ResultFinalizer;
import tech.oliverprojects.speedtestplus.core.SpeedCurve;
import tech.oliverprojects.speedtestplus.core.SpeedPlusConfig;
import tech.oliverprojects.speedtestplus.core.TelemetryConsent;
import tech.oliverprojects.speedtestplus.core.ThemeCodeCodec;
import tech.oliverprojects.speedtestplus.core.TestMode;

public final class CoreContractTest {
    public static void main(String[] args) {
        validationIgnoresBadFields();
        finalizationIsStable();
        displayCurveMovesAndFinishesExactly();
        telemetryIsOptIn();
        themeCodesRoundTripAndRejectCorruption();
        testModesAreSafeAndPortable();
        diagnosticsSnapshotIsPrivacySafe();
        System.out.println("CoreContractTest: PASS");
    }

    private static void validationIgnoresBadFields() {
        SpeedPlusConfig input = new SpeedPlusConfig();
        input.downloadMinMbps = 100.0d;
        input.downloadMaxMbps = 50.0d;
        input.uploadMinMbps = 25.0d;
        input.uploadMaxMbps = 25.0d;
        input.pingMs = 10000;
        input.packetLossPercent = 1.26d;
        input.isp = "  Example ISP  ";
        ConfigValidator.Result result = ConfigValidator.validate(input);
        SpeedPlusConfig output = result.config();
        require(output.downloadMinMbps == null, "invalid range must be cleared");
        require(output.uploadMinMbps == 25.0d, "valid exact range must remain");
        require(output.pingMs == null, "invalid ping must be cleared");
        require(output.packetLossPercent == 1.3d, "loss must round to one decimal");
        require("Example ISP".equals(output.isp), "identity must be trimmed");
    }

    private static void finalizationIsStable() {
        SpeedPlusConfig config = new SpeedPlusConfig();
        config.downloadMinMbps = 200.0d;
        config.downloadMaxMbps = 300.0d;
        FinalResult measured = new FinalResult(10.0d, 20.0d, 30, 4, 0.0d, "A", "B", "C");
        FinalResult first = ResultFinalizer.finalizeOnce(config, 42L, measured);
        FinalResult second = ResultFinalizer.finalizeOnce(config, 42L, measured);
        require(first.downloadMbps.equals(second.downloadMbps), "same session seed must be stable");
        require(first.uploadMbps.equals(measured.uploadMbps), "blank override must preserve measured value");
    }

    private static void displayCurveMovesAndFinishesExactly() {
        double[] samples = SpeedCurve.displaySamples(666.86d, 7L);
        boolean moved = false;
        for (int i = 1; i < samples.length; i++) {
            if (samples[i] != samples[i - 1]) moved = true;
        }
        require(moved, "configured display must animate");
        require(samples[samples.length - 1] == 666.9d, "last sample must equal saved scalar");
        require(samples[0] < samples[samples.length - 1], "curve must visibly ramp");
    }

    private static void telemetryIsOptIn() {
        require(!new TelemetryConsent(TelemetryConsent.Status.UNKNOWN, 1).permitsCollection(1),
                "unknown consent must be off");
        require(!new TelemetryConsent(TelemetryConsent.Status.DECLINED, 1).permitsCollection(1),
                "declined consent must be off");
        require(new TelemetryConsent(TelemetryConsent.Status.GRANTED, 1).permitsCollection(1),
                "matching granted consent must be on");
        require(!new TelemetryConsent(TelemetryConsent.Status.GRANTED, 1).permitsCollection(2),
                "policy change must require fresh consent");
    }

    private static void themeCodesRoundTripAndRejectCorruption() {
        String json = "{\"schemaVersion\":1,\"name\":\"Ocean\"}";
        String code = ThemeCodeCodec.encode(json);
        require(json.equals(ThemeCodeCodec.decode(code)), "theme code must round trip");
        boolean rejected = false;
        try {
            ThemeCodeCodec.decode(code.substring(0, code.length() - 1) + "0");
        } catch (IllegalArgumentException expected) {
            rejected = true;
        }
        require(rejected, "corrupted theme code must fail closed");
    }

    private static void testModesAreSafeAndPortable() {
        SpeedPlusConfig config = new SpeedPlusConfig();
        config.offlineMode = true;
        config.dataSaverMode = true;
        ConfigValidator.Result validated = ConfigValidator.validate(config);
        require(validated.config().offlineMode, "offline mode must survive validation");
        require(!validated.config().dataSaverMode, "offline mode must disable data saver");
        require(!validated.warnings().isEmpty(), "mode conflict should explain itself");

        SpeedPlusConfig saver = new SpeedPlusConfig();
        saver.dataSaverMode = true;
        require(TestMode.isDataSaver(saver), "data saver mode must be detectable");
        require(TestMode.DATA_SAVER_MAX_BYTES_PER_CONNECTION == 262144,
                "data saver byte budget must stay conservative");
        require(TestMode.DATA_SAVER_MAX_DURATION_SECONDS == 2,
                "data saver duration must stay bounded");

        FinalResult demo = TestMode.offlineResult(validated.config(), 42L);
        require(demo.downloadMbps.equals(100.0d), "blank offline download should use demo baseline");
        require(demo.uploadMbps.equals(20.0d), "blank offline upload should use demo baseline");
        require("Offline demo".equals(demo.isp), "offline identity must be explicit");
        require(!TestMode.allowsRemoteSubmission(validated.config()),
                "offline result must not be remotely submitted");
    }

    private static void diagnosticsSnapshotIsPrivacySafe() {
        java.util.Map<String, Object> config = new java.util.HashMap<>();
        config.put("download_min", 100.0d);
        config.put("isp", "Private ISP");
        java.util.Map<String, Object> result = new java.util.HashMap<>();
        result.put("download_mbps", 274.04d);
        result.put("ping_ms", 15);
        String text = DiagnosticsSnapshot.build("Android", "16\nsecret", "1.8.9", config, result, true, 2, 3, false);
        require(text.contains("Download: 274.0 Mbps"), "diagnostics must include finalized scalar");
        require(text.contains("ISP override: set"), "diagnostics must report override presence");
        require(!text.contains("Private ISP"), "diagnostics must not include free-text identity");
        require(!text.contains("16\nsecret"), "diagnostics must remove line breaks from system text");
        require(text.contains("no IP address"), "diagnostics must explain privacy scope");
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
