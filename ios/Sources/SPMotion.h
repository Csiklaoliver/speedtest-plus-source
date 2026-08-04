#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Presentation-only motion helpers shared by the iOS gauge and controls.
FOUNDATION_EXPORT double SPMotionClampProgress(double progress);
FOUNDATION_EXPORT double SPMotionPresentationProgress(double suppliedProgress,
                                                       NSTimeInterval elapsed,
                                                       BOOL reducedMotion);
FOUNDATION_EXPORT NSTimeInterval SPMotionTransitionDuration(NSTimeInterval normalDuration,
                                                             BOOL reducedMotion);

NS_ASSUME_NONNULL_END
