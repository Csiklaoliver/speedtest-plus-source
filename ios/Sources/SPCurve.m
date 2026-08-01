#import "SPCurve.h"
#import <math.h>

double SPClamp(double value, double minimum, double maximum) {
    return fmin(maximum, fmax(minimum, value));
}

double SPRoundedMbps(double value) {
    if (!isfinite(value) || value < 0.0) return 0.0;
    return round(value * 10.0) / 10.0;
}

static double SPNoise(uint64_t seed, NSInteger index) {
    uint64_t x = seed ^ ((uint64_t)index * 0x9E3779B97F4A7C15ULL);
    x ^= x >> 30;
    x *= 0xBF58476D1CE4E5B9ULL;
    x ^= x >> 27;
    x *= 0x94D049BB133111EBULL;
    x ^= x >> 31;
    return ((double)(x & 0xffff) / 32767.5) - 1.0;
}

double SPRealisticMbps(double targetMbps, double progress, uint64_t seed, SPDirection direction) {
    targetMbps = SPRoundedMbps(targetMbps);
    progress = SPClamp(progress, 0.0, 1.0);
    if (targetMbps <= 0.0 || progress <= 0.0) return 0.0;

    // The opening section follows the stock gauge reveal. It rises continuously
    // from zero and never alternates between a placeholder and the target value.
    double rise = 1.0 - exp(-7.2 * progress);
    double settle = progress < 0.62 ? 1.0 : 1.0 - (progress - 0.62) * 0.025;
    NSInteger bucket = (NSInteger)floor(progress * 32.0);
    double noise = SPNoise(seed + (uint64_t)direction * 97ULL, bucket);
    double amplitude = progress < 0.20 ? 0.018 : (progress < 0.72 ? 0.035 : 0.024);
    double wave = sin(progress * 31.0 + (double)direction) * 0.012;
    double factor = rise * settle + noise * amplitude + wave;

    if (progress > 0.97) {
        double t = (progress - 0.97) / 0.03;
        factor = factor * (1.0 - t) + t;
    }
    return SPRoundedMbps(SPClamp(targetMbps * factor, 0.0, targetMbps * 1.08));
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *SPSavedSamples(double finalMbps) {
    static const double progress[] = {0.00, 0.09, 0.18, 0.27, 0.36, 0.45, 0.55, 0.64, 0.73, 0.82, 0.91, 1.00};
    static const NSInteger permille[] = {40, 160, 380, 620, 800, 920, 1010, 980, 1030, 1000, 1010, 1000};
    NSMutableArray *samples = [NSMutableArray arrayWithCapacity:12];
    for (NSInteger index = 0; index < 12; index++) {
        double speed = index == 11 ? finalMbps : finalMbps * ((double)permille[index] / 1000.0);
        [samples addObject:@{ @"progress": @(progress[index]), @"speedMbps": @(SPRoundedMbps(speed)) }];
    }
    return samples;
}

