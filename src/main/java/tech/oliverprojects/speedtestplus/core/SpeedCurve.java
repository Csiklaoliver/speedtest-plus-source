package tech.oliverprojects.speedtestplus.core;

/**
 * Builds a visible ramp that approaches one immutable finalized speed.
 * The last sample is always exactly the saved scalar.
 */
public final class SpeedCurve {
    private static final int[] PERMILLE = {
            20, 60, 130, 240, 390, 570, 760, 910, 1030, 970, 1015, 1000
    };

    private SpeedCurve() {
    }

    public static double[] displaySamples(double finalMbps, long seed) {
        if (Double.isNaN(finalMbps) || Double.isInfinite(finalMbps) || finalMbps < 0.0d) {
            throw new IllegalArgumentException("finalMbps must be finite and non-negative");
        }
        double[] samples = new double[PERMILLE.length];
        long state = mix(seed);
        for (int i = 0; i < samples.length - 1; i++) {
            state = mix(state + i + 1L);
            double jitter = (((state >>> 11) & 0x3ffL) / 1023.0d - 0.5d) * 0.05d;
            double ratio = Math.max(0.0d, PERMILLE[i] / 1000.0d + jitter);
            samples[i] = oneHundredth(finalMbps * ratio);
        }
        samples[samples.length - 1] = oneDecimal(finalMbps);
        return samples;
    }

    private static long mix(long value) {
        value ^= value >>> 33;
        value *= 0xff51afd7ed558ccdl;
        value ^= value >>> 33;
        value *= 0xc4ceb9fe1a85ec53l;
        return value ^ (value >>> 33);
    }

    private static double oneHundredth(double value) {
        return Math.round(value * 100.0d) / 100.0d;
    }

    private static double oneDecimal(double value) {
        return Math.round(value * 10.0d) / 10.0d;
    }
}
