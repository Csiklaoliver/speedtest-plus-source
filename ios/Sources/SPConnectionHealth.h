#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs a bounded, privacy-safe transport check without starting a speed test.
/// The completion is always delivered on the main queue with a user-readable
/// summary containing only fixed status text and an HTTP status code.
@interface SPConnectionHealth : NSObject

+ (void)runWithOfflineMode:(BOOL)offline completion:(void (^)(NSString *summary))completion;

/// Records whether the native provider row has been observed in this app
/// session. This is intentionally local state; it never probes or changes the
/// native server-selection flow.
+ (void)noteNativeServerListReady:(BOOL)ready;

@end

NS_ASSUME_NONNULL_END
