#import "SPState.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <math.h>

NSString * const SPStateDidChangeNotification = @"SpeedtestPlusStateDidChange";
NSString * const SPThemeDidChangeNotification = @"SpeedtestPlusThemeDidChange";

static NSString * const SPDefaultsKey = @"speedtest_plus_mod";
static NSString * const SPConfigKey = @"active_configuration";
static NSString * const SPProfilesKey = @"profiles";
static NSString * const SPLastResultKey = @"last_finalized_result";

static id SPDefaultsSafeValue(id value) {
    if (!value || value == NSNull.null) return nil;
    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] ||
        [value isKindOfClass:NSData.class] || [value isKindOfClass:NSDate.class]) return value;
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *safe = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id item, BOOL *stop) {
            id cleaned = SPDefaultsSafeValue(item);
            if ([key isKindOfClass:NSString.class] && cleaned) safe[key] = cleaned;
        }];
        return [safe copy];
    }
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *safe = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            id cleaned = SPDefaultsSafeValue(item);
            if (cleaned) [safe addObject:cleaned];
        }
        return [safe copy];
    }
    return nil;
}

@interface SPState ()
@property(nonatomic) NSMutableDictionary<NSString *, id> *store;
@property(nonatomic) NSMutableDictionary<NSString *, id> *mutableConfiguration;
@property(nonatomic) NSMutableDictionary<NSString *, id> *mutableLastResult;
@property(nonatomic) uint64_t testSeed;
@property(nonatomic) NSInteger currentStage;
@property(nonatomic) BOOL testStarted;
@property(nonatomic) NSNumber *finalDownload;
@property(nonatomic) NSNumber *finalUpload;
@end

@implementation SPState

+ (instancetype)shared {
    static SPState *state;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ state = [[self alloc] initPrivate]; });
    return state;
}

- (instancetype)initPrivate {
    self = [super init];
    if (!self) return nil;
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SPDefaultsKey];
    _store = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    _mutableConfiguration = [_store[SPConfigKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    _mutableLastResult = [_store[SPLastResultKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    _currentStage = 0;
    return self;
}

- (instancetype)init { return [SPState shared]; }

- (void)persist {
    self.store[SPConfigKey] = [self.mutableConfiguration copy];
    self.store[SPLastResultKey] = [self.mutableLastResult copy];
    NSDictionary *safeStore = SPDefaultsSafeValue(self.store);
    self.store = [safeStore mutableCopy] ?: [NSMutableDictionary dictionary];
    [[NSUserDefaults standardUserDefaults] setObject:safeStore ?: @{} forKey:SPDefaultsKey];
}

- (NSDictionary<NSString *,id> *)configuration { return [self.mutableConfiguration copy]; }
- (NSDictionary<NSString *,id> *)lastResult { return [self.mutableLastResult copy]; }
- (BOOL)active { return [self.store[@"active"] boolValue]; }
- (NSInteger)themeIndex { return [self.store[@"theme_index"] integerValue]; }
- (BOOL)introSeen { return [self.store[@"intro_version_seen"] integerValue] >= 1; }
- (BOOL)panelHidden { return [self.store[@"panel_hidden"] boolValue]; }
- (BOOL)updateChecksEnabled { return self.store[@"update_checks"] ? [self.store[@"update_checks"] boolValue] : YES; }
- (NSString *)lastPromptedUpdateVersion { id value = self.store[@"last_prompted_update_version"]; return [value isKindOfClass:NSString.class] ? value : nil; }
- (NSInteger)stage { return self.currentStage; }

- (NSNumber *)numberForKey:(NSString *)key {
    id value = self.mutableConfiguration[key];
    return [value isKindOfClass:NSNumber.class] ? value : nil;
}

- (NSString *)stringForKey:(NSString *)key {
    id value = self.mutableConfiguration[key];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

- (NSInteger)activeOverrideCount {
    if (!self.active) return 0;
    NSInteger count = 0;
    if ([self numberForKey:@"download_min"] || [self numberForKey:@"download_max"]) count++;
    if ([self numberForKey:@"upload_min"] || [self numberForKey:@"upload_max"]) count++;
    if ([self numberForKey:@"ping"]) count++;
    if ([self numberForKey:@"jitter"]) count++;
    if ([self numberForKey:@"packet_loss"]) count++;
    if ([self stringForKey:@"isp"]) count++;
    if ([self stringForKey:@"server_provider"]) count++;
    if ([self stringForKey:@"server_location"]) count++;
    return count;
}

- (void)applyConfiguration:(NSDictionary<NSString *,id> *)configuration {
    self.mutableConfiguration = [configuration mutableCopy];
    self.store[@"active"] = @YES;
    [self persist];
    [[NSNotificationCenter defaultCenter] postNotificationName:SPStateDidChangeNotification object:self];
}

- (void)disableAll {
    self.store[@"active"] = @NO;
    [self persist];
    [[NSNotificationCenter defaultCenter] postNotificationName:SPStateDidChangeNotification object:self];
}

- (void)setThemeIndex:(NSInteger)themeIndex {
    self.store[@"theme_index"] = @(MAX(0, MIN(themeIndex, 9)));
    [self persist];
    [[NSNotificationCenter defaultCenter] postNotificationName:SPThemeDidChangeNotification object:self];
}

- (void)setIntroSeen:(BOOL)seen { self.store[@"intro_version_seen"] = seen ? @1 : @0; [self persist]; }

static NSString *SPPasswordHash(NSString *password) {
    NSData *data = [password dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

- (void)setPanelHidden:(BOOL)hidden password:(NSString *)password {
    self.store[@"panel_hidden"] = @(hidden);
    if (password.length) self.store[@"panel_password_hash"] = SPPasswordHash(password);
    else [self.store removeObjectForKey:@"panel_password_hash"];
    [self persist];
}

- (BOOL)unlockWithPassword:(NSString *)password {
    NSString *expected = self.store[@"panel_password_hash"];
    return !expected.length || [expected isEqualToString:SPPasswordHash(password ?: @"")];
}

- (void)setUpdateChecksEnabled:(BOOL)enabled { self.store[@"update_checks"] = @(enabled); [self persist]; }
- (void)setLastPromptedUpdateVersion:(NSString *)version { if (version.length) self.store[@"last_prompted_update_version"] = version; [self persist]; }

- (NSDictionary<NSString *,id> *)profileAtIndex:(NSInteger)index {
    if (index < 0 || index > 2) return nil;
    id savedProfiles = self.store[SPProfilesKey];
    id profile = nil;
    if ([savedProfiles isKindOfClass:NSDictionary.class]) {
        profile = savedProfiles[[NSString stringWithFormat:@"%ld", (long)index]];
    } else if ([savedProfiles isKindOfClass:NSArray.class] && index < (NSInteger)[savedProfiles count]) {
        profile = savedProfiles[index];
    }
    if (![profile isKindOfClass:NSDictionary.class]) return nil;
    NSString *name = profile[@"name"];
    NSDictionary *configuration = profile[@"configuration"];
    return [name isKindOfClass:NSString.class] && name.length && [configuration isKindOfClass:NSDictionary.class] ? profile : nil;
}

- (void)saveProfile:(NSDictionary<NSString *,id> *)profile atIndex:(NSInteger)index {
    if (index < 0 || index > 2) return;
    NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
    id savedProfiles = self.store[SPProfilesKey];
    if ([savedProfiles isKindOfClass:NSDictionary.class]) {
        [profiles addEntriesFromDictionary:savedProfiles];
    } else if ([savedProfiles isKindOfClass:NSArray.class]) {
        [savedProfiles enumerateObjectsUsingBlock:^(id item, NSUInteger oldIndex, BOOL *stop) {
            if (oldIndex < 3 && [item isKindOfClass:NSDictionary.class]) profiles[[NSString stringWithFormat:@"%lu", (unsigned long)oldIndex]] = item;
        }];
    }
    profiles[[NSString stringWithFormat:@"%ld", (long)index]] = [profile copy];
    self.store[SPProfilesKey] = profiles;
    [self persist];
}

- (void)deleteProfileAtIndex:(NSInteger)index {
    if (index < 0 || index > 2) return;
    NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
    for (NSInteger slot = 0; slot < 3; slot++) {
        NSDictionary *profile = [self profileAtIndex:slot];
        if (profile && slot != index) profiles[[NSString stringWithFormat:@"%ld", (long)slot]] = profile;
    }
    self.store[SPProfilesKey] = [profiles copy];
    [self persist];
}

- (void)beginTest {
    uint64_t random = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *)&random) != errSecSuccess) {
        random = (uint64_t)(NSDate.date.timeIntervalSince1970 * 1000.0);
    }
    self.testSeed = random;
    self.testStarted = YES;
    self.currentStage = 0;
    self.finalDownload = nil;
    self.finalUpload = nil;
}

- (void)setStage:(NSInteger)stage { self.currentStage = stage; }

- (BOOL)hasSpeedOverrideForDirection:(SPDirection)direction {
    if (!self.active) return NO;
    NSString *prefix = direction == SPDirectionDownload ? @"download" : @"upload";
    return [self numberForKey:[prefix stringByAppendingString:@"_min"]] || [self numberForKey:[prefix stringByAppendingString:@"_max"]];
}

- (double)targetForDirection:(SPDirection)direction measured:(double)measured {
    NSString *prefix = direction == SPDirectionDownload ? @"download" : @"upload";
    NSNumber *minimum = [self numberForKey:[prefix stringByAppendingString:@"_min"]];
    NSNumber *maximum = [self numberForKey:[prefix stringByAppendingString:@"_max"]];
    if (!minimum && !maximum) return measured;
    double low = minimum ? minimum.doubleValue : maximum.doubleValue;
    double high = maximum ? maximum.doubleValue : minimum.doubleValue;
    if (high <= low) return SPRoundedMbps(low);
    uint64_t mixed = self.testSeed ^ ((uint64_t)direction * 0xD6E8FEB86659FD93ULL);
    double unit = (double)(mixed & 0xffffff) / (double)0xffffff;
    return SPRoundedMbps(low + (high - low) * unit);
}

- (double)finalMbpsForDirection:(SPDirection)direction measuredMbps:(double)measured {
    if (![self hasSpeedOverrideForDirection:direction]) return measured;
    if (direction == SPDirectionDownload) {
        if (!self.finalDownload) self.finalDownload = @([self targetForDirection:direction measured:measured]);
        return self.finalDownload.doubleValue;
    }
    if (!self.finalUpload) self.finalUpload = @([self targetForDirection:direction measured:measured]);
    return self.finalUpload.doubleValue;
}

- (double)displayMbpsForDirection:(SPDirection)direction measuredMbps:(double)measured progress:(double)progress {
    if (![self hasSpeedOverrideForDirection:direction]) return measured;
    double target = [self finalMbpsForDirection:direction measuredMbps:measured];
    return SPRealisticMbps(target, progress, self.testSeed, direction);
}

- (void)completeTestWithMeasuredDownload:(double)download
                                  upload:(double)upload
                                    ping:(NSNumber *)ping
                                  jitter:(NSNumber *)jitter
                              packetLoss:(NSNumber *)packetLoss
                                     isp:(NSString *)isp
                          serverProvider:(NSString *)serverProvider
                          serverLocation:(NSString *)serverLocation {
    double finalDown = [self finalMbpsForDirection:SPDirectionDownload measuredMbps:download];
    double finalUp = [self finalMbpsForDirection:SPDirectionUpload measuredMbps:upload];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"download_mbps"] = @(SPRoundedMbps(finalDown));
    result[@"upload_mbps"] = @(SPRoundedMbps(finalUp));
    result[@"ping_ms"] = [self numberForKey:@"ping"] ?: ping ?: NSNull.null;
    result[@"jitter_ms"] = [self numberForKey:@"jitter"] ?: jitter ?: NSNull.null;
    result[@"packet_loss"] = [self numberForKey:@"packet_loss"] ?: packetLoss ?: NSNull.null;
    result[@"isp"] = [self stringForKey:@"isp"] ?: isp ?: @"";
    result[@"server_provider"] = [self stringForKey:@"server_provider"] ?: serverProvider ?: @"";
    result[@"server_location"] = [self stringForKey:@"server_location"] ?: serverLocation ?: @"";
    result[@"download_samples"] = SPSavedSamples(finalDown);
    result[@"upload_samples"] = SPSavedSamples(finalUp);
    result[@"completed_at"] = @((long long)(NSDate.date.timeIntervalSince1970 * 1000.0));
    self.mutableLastResult = result;
    self.testStarted = NO;
    [self persist];
}

@end
