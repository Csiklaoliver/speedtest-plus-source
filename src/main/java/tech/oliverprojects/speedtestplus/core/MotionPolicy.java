package tech.oliverprojects.speedtestplus.core;

/**
 * Platform-neutral reduced-motion rules.
 *
 * <p>Reduced motion changes presentation only.  It never changes measured or
 * finalized values, network budgets, or result persistence.  Native adapters
 * can use these helpers for gauge transitions and progress labels while still
 * respecting the operating system's accessibility setting.</p>
 */
public final class MotionPolicy {
    /** Shared preference key used by both platform adapters. */
    public static final String PREFERENCE_KEY = "reduce_motion";

    private MotionPolicy() {
    }

    /**
     * Returns a finite progress value in the inclusive [0, 1] range.
     */
    public static double clampProgress(double progress) {
        if (Double.isNaN(progress) || Double.isInfinite(progress)) return 0.0d;
        return Math.max(0.0d, Math.min(1.0d, progress));
    }

    /**
     * Computes the synthetic presentation progress used while a configured
     * run is active.  Normal mode keeps the short settling oscillation used by
     * the original gauge.  Reduced mode uses a slower monotonic ramp and no
     * oscillation, avoiding flashes/jumps for motion-sensitive users.
     */
    public static double presentationProgress(double suppliedProgress,
                                               double elapsedSeconds,
                                               boolean reducedMotion) {
        double supplied = clampProgress(suppliedProgress);
        double elapsed = Double.isNaN(elapsedSeconds) || Double.isInfinite(elapsedSeconds)
                ? 0.0d : Math.max(0.0d, elapsedSeconds);
        double elapsedProgress;
        if (reducedMotion) {
            // Keep the display moving without the original needle/pulse
            // oscillation.  The cap leaves room for the final exact scalar.
            elapsedProgress = Math.min(0.96d, elapsed / 8.0d * 0.96d);
        } else if (elapsed < 5.0d) {
            elapsedProgress = (elapsed / 5.0d) * 0.96d;
        } else {
            double oscillation = 0.5d + 0.5d * Math.sin((elapsed - 5.0d) * 2.35d);
            elapsedProgress = 0.90d + oscillation * 0.07d;
        }
        return Math.max(supplied, clampProgress(elapsedProgress));
    }

    /**
     * Returns a safe animation duration for a native transition.
     */
    public static long transitionDurationMillis(long normalDurationMillis, boolean reducedMotion) {
        long normal = Math.max(0L, normalDurationMillis);
        return reducedMotion ? 0L : normal;
    }
}
