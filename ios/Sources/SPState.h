#import <Foundation/Foundation.h>
#import "SPCurve.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const SPStateDidChangeNotification;
FOUNDATION_EXPORT NSString * const SPThemeDidChangeNotification;

@interface SPState : NSObject

@property(nonatomic, readonly) BOOL active;
@property(nonatomic, readonly) NSInteger themeIndex;
@property(nonatomic, readonly) NSInteger activeOverrideCount;
@property(nonatomic, readonly) NSDictionary<NSString *, id> *configuration;
@property(nonatomic, readonly) NSDictionary<NSString *, id> *lastResult;
@property(nonatomic, readonly) BOOL introSeen;
@property(nonatomic, readonly) BOOL panelHidden;
@property(nonatomic, readonly) BOOL updateChecksEnabled;
@property(nonatomic, readonly, getter=isTestActive) BOOL testActive;
@property(nonatomic, readonly, nullable) NSString *lastPromptedUpdateVersion;

+ (instancetype)shared;

- (void)applyConfiguration:(NSDictionary<NSString *, id> *)configuration;
- (void)disableAll;
- (void)setThemeIndex:(NSInteger)themeIndex;
- (void)setIntroSeen:(BOOL)seen;
- (void)setPanelHidden:(BOOL)hidden password:(nullable NSString *)password;
- (BOOL)unlockWithPassword:(NSString *)password;
- (void)setUpdateChecksEnabled:(BOOL)enabled;
- (void)setLastPromptedUpdateVersion:(NSString *)version;

- (nullable NSDictionary<NSString *, id> *)profileAtIndex:(NSInteger)index;
- (void)saveProfile:(NSDictionary<NSString *, id> *)profile atIndex:(NSInteger)index;
- (void)deleteProfileAtIndex:(NSInteger)index;

- (void)beginTest;
- (void)setStage:(NSInteger)stage;
- (NSInteger)stage;
- (BOOL)hasSpeedOverrideForDirection:(SPDirection)direction;
- (BOOL)runHasSpeedOverrideForDirection:(SPDirection)direction;
- (nullable NSNumber *)runNumberForKey:(NSString *)key;
- (nullable NSString *)runStringForKey:(NSString *)key;
- (BOOL)runBoolForKey:(NSString *)key;
- (nullable NSDictionary<NSString *, id> *)consumePendingLocalResult;
- (double)displayMbpsForDirection:(SPDirection)direction measuredMbps:(double)measured progress:(double)progress;
- (double)finalMbpsForDirection:(SPDirection)direction measuredMbps:(double)measured;
- (void)completeTestWithMeasuredDownload:(double)download
                                  upload:(double)upload
                                    ping:(nullable NSNumber *)ping
                                  jitter:(nullable NSNumber *)jitter
                              packetLoss:(nullable NSNumber *)packetLoss
                                     isp:(nullable NSString *)isp
                          serverProvider:(nullable NSString *)serverProvider
                          serverLocation:(nullable NSString *)serverLocation;

/// Finishes a local, clearly-labelled demo without contacting the network.
- (void)completeOfflineDemo;

- (nullable NSNumber *)numberForKey:(NSString *)key;
- (nullable NSString *)stringForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
