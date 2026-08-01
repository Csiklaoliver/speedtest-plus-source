#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPDirection) {
    SPDirectionDownload = 1,
    SPDirectionUpload = 2,
};

FOUNDATION_EXPORT double SPClamp(double value, double minimum, double maximum);
FOUNDATION_EXPORT double SPRoundedMbps(double value);
FOUNDATION_EXPORT double SPRealisticMbps(double targetMbps, double progress, uint64_t seed, SPDirection direction);
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSNumber *> *> *SPSavedSamples(double finalMbps);

NS_ASSUME_NONNULL_END

