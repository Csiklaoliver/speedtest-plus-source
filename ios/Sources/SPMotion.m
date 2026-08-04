#import "SPMotion.h"
#import <math.h>

double SPMotionClampProgress(double progress) {
    if (!isfinite(progress)) return 0.0;
    return fmax(0.0, fmin(1.0, progress));
}

double SPMotionPresentationProgress(double suppliedProgress,
                                    NSTimeInterval elapsed,
                                    BOOL reducedMotion) {
    double supplied = SPMotionClampProgress(suppliedProgress);
    double safeElapsed = isfinite(elapsed) ? fmax(0.0, elapsed) : 0.0;
    double elapsedProgress;
    if (reducedMotion) {
        // A slower monotonic ramp avoids the original needle/pulse
        // oscillation without freezing the configured result display.
        elapsedProgress = fmin(0.96, safeElapsed / 8.0 * 0.96);
    } else if (safeElapsed < 5.0) {
        elapsedProgress = (safeElapsed / 5.0) * 0.96;
    } else {
        double oscillation = 0.5 + 0.5 * sin((safeElapsed - 5.0) * 2.35);
        elapsedProgress = 0.90 + oscillation * 0.07;
    }
    return fmax(supplied, SPMotionClampProgress(elapsedProgress));
}

NSTimeInterval SPMotionTransitionDuration(NSTimeInterval normalDuration,
                                           BOOL reducedMotion) {
    return reducedMotion ? 0.0 : fmax(0.0, normalDuration);
}
