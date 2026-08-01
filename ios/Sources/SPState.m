#import "SPState.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <math.h>
#import <limits.h>

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

static NSDictionary<NSString *, id> *SPNormalizedConfiguration(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return @{};
    NSDictionary *input = value;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    double maximumMbps = ((double)LLONG_MAX - 1000.0) / 1000.0;
    for (NSString *key in @[@"download_min", @"download_max", @"upload_min", @"upload_max"]) {
        id candidate = input[key];
        double number = [candidate isKindOfClass:NSNumber.class] ? [candidate doubleValue] : NAN;
        if (isfinite(number) && number >= 0.0 && number <= maximumMbps) result[key] = @(number);
    }
    for (NSString *prefix in @[@"download", @"upload"]) {
        NSString *minimumKey = [prefix stringByAppendingString:@"_min"];
        NSString *maximumKey = [prefix stringByAppendingString:@"_max"];
        NSNumber *minimum = result[minimumKey];
        NSNumber *maximum = result[maximumKey];
        if (!minimum || !maximum || minimum.doubleValue > maximum.doubleValue) {
            [result removeObjectForKey:minimumKey];
            [result removeObjectForKey:maximumKey];
        }
    }
    for (NSString *key in @[@"ping", @"jitter"]) {
        id candidate = input[key];
        double number = [candidate isKindOfClass:NSNumber.class] ? [candidate doubleValue] : NAN;
        if (isfinite(number) && number >= 0.0 && number <= 9999.0 && floor(number) == number) result[key] = @(number);
    }
    id lossCandidate = input[@"packet_loss"];
    double loss = [lossCandidate isKindOfClass:NSNumber.class] ? [lossCandidate doubleValue] : NAN;
    if (isfinite(loss) && loss >= 0.0 && loss <= 100.0) result[@"packet_loss"] = @(round(loss * 10.0) / 10.0);
    for (NSString *key in @[@"isp", @"server_provider", @"server_location"]) {
        id candidate = input[key];
        if (![candidate isKindOfClass:NSString.class]) continue;
        NSString *text = [candidate stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length > 64) text = [text substringToIndex:64];
        if (text.length) result[key] = text;
    }
    return [result copy];
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
@property(nonatomic) BOOL runActive;
@property(nonatomic) NSDictionary<NSString *, id> *runConfiguration;
@property(nonatomic) NSDictionary<NSString *, id> *pendingLocalResult;
@property(nonatomic) NSTimeInterval downloadAnimationStartedAt;
@property(nonatomic) NSTimeInterval uploadAnimationStartedAt;
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
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:SPDefaultsKey];
    NSDictionary *saved = [storedValue isKindOfClass:NSDictionary.class] ? SPDefaultsSafeValue(storedValue) : @{};
    _store = [saved mutableCopy] ?: [NSMutableDictionary dictionary];
    _mutableConfiguration = [SPNormalizedConfiguration(_store[SPConfigKey]) mutableCopy];
    id lastResult = _store[SPLastResultKey];
    _mutableLastResult = [lastResult isKindOfClass:NSDictionary.class] ? [lastResult mutableCopy] : [NSMutableDictionary dictionary];
    _runConfiguration = @{};
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
- (BOOL)isTestActive { return self.testStarted; }

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
    NSDictionary *normalized = SPNormalizedConfiguration(configuration);
    self.mutableConfiguration = [normalized mutableCopy];
    self.store[@"active"] = @(normalized.count > 0);
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
    NSString *name = [profile[@"name"] isKindOfClass:NSString.class] ? [profile[@"name"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
    if (name.length > 24) name = [name substringToIndex:24];
    NSDictionary *configuration = SPNormalizedConfiguration(profile[@"configuration"]);
    return name.length ? @{ @"name": name, @"configuration": configuration } : nil;
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
    NSString *name = [profile[@"name"] isKindOfClass:NSString.class] ? [profile[@"name"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (name.length > 24) name = [name substringToIndex:24];
    if (!name.length) return;
    profiles[[NSString stringWithFormat:@"%ld", (long)index]] = @{ @"name": name, @"configuration": SPNormalizedConfiguration(profile[@"configuration"]) };
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
    self.runActive = self.active;
    self.runConfiguration = [self.mutableConfiguration copy];
    self.currentStage = 0;
    self.finalDownload = nil;
    self.finalUpload = nil;
    self.pendingLocalResult = nil;
    self.downloadAnimationStartedAt = 0;
    self.uploadAnimationStartedAt = 0;
}

- (void)setStage:(NSInteger)stage {
    if (stage != self.currentStage) {
        if (stage == 2) self.downloadAnimationStartedAt = 0;
        if (stage == 3) self.uploadAnimationStartedAt = 0;
    }
    self.currentStage = stage;
}

- (BOOL)hasSpeedOverrideForDirection:(SPDirection)direction {
    if (!self.active) return NO;
    NSString *prefix = direction == SPDirectionDownload ? @"download" : @"upload";
    return [self numberForKey:[prefix stringByAppendingString:@"_min"]] || [self numberForKey:[prefix stringByAppendingString:@"_max"]];
}

- (NSNumber *)runNumberForKey:(NSString *)key {
    if (!self.runActive) return nil;
    id value = self.runConfiguration[key];
    return [value isKindOfClass:NSNumber.class] ? value : nil;
}

- (NSString *)runStringForKey:(NSString *)key {
    if (!self.runActive) return nil;
    id value = self.runConfiguration[key];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

- (BOOL)runHasSpeedOverrideForDirection:(SPDirection)direction {
    if (!self.runActive) return NO;
    NSString *prefix = direction == SPDirectionDownload ? @"download" : @"upload";
    return [self runNumberForKey:[prefix stringByAppendingString:@"_min"]] && [self runNumberForKey:[prefix stringByAppendingString:@"_max"]];
}

- (NSDictionary<NSString *,id> *)consumePendingLocalResult {
    NSDictionary *pending = self.pendingLocalResult;
    self.pendingLocalResult = nil;
    return pending;
}

- (double)targetForDirection:(SPDirection)direction measured:(double)measured {
    NSString *prefix = direction == SPDirectionDownload ? @"download" : @"upload";
    NSNumber *minimum = [self runNumberForKey:[prefix stringByAppendingString:@"_min"]];
    NSNumber *maximum = [self runNumberForKey:[prefix stringByAppendingString:@"_max"]];
    if (!minimum && !maximum) return measured;
    double low = minimum ? minimum.doubleValue : maximum.doubleValue;
    double high = maximum ? maximum.doubleValue : minimum.doubleValue;
    if (high <= low) return SPRoundedMbps(low);
    uint64_t mixed = self.testSeed ^ ((uint64_t)direction * 0xD6E8FEB86659FD93ULL);
    double unit = (double)(mixed & 0xffffff) / (double)0xffffff;
    return SPRoundedMbps(low + (high - low) * unit);
}

- (double)finalMbpsForDirection:(SPDirection)direction measuredMbps:(double)measured {
    if (![self runHasSpeedOverrideForDirection:direction]) return measured;
    if (direction == SPDirectionDownload) {
        if (!self.finalDownload) self.finalDownload = @([self targetForDirection:direction measured:measured]);
        return self.finalDownload.doubleValue;
    }
    if (!self.finalUpload) self.finalUpload = @([self targetForDirection:direction measured:measured]);
    return self.finalUpload.doubleValue;
}

- (double)displayMbpsForDirection:(SPDirection)direction measuredMbps:(double)measured progress:(double)progress {
    if (![self runHasSpeedOverrideForDirection:direction]) return measured;
    if (!isfinite(measured) || measured <= 0.0) return 0.0;
    double target = [self finalMbpsForDirection:direction measuredMbps:measured];
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSTimeInterval started = direction == SPDirectionDownload ? self.downloadAnimationStartedAt : self.uploadAnimationStartedAt;
    if (started <= 0.0) {
        started = now;
        if (direction == SPDirectionDownload) self.downloadAnimationStartedAt = now;
        else self.uploadAnimationStartedAt = now;
    }
    NSTimeInterval elapsed = MAX(0.0, now - started);
    double curveProgress;
    if (elapsed < 5.0) {
        curveProgress = (elapsed / 5.0) * 0.96;
    } else {
        double oscillation = 0.5 + 0.5 * sin((elapsed - 5.0) * 2.35 + (double)direction);
        curveProgress = 0.90 + oscillation * 0.07;
    }
    return SPRealisticMbps(target, curveProgress, self.testSeed + (uint64_t)floor(elapsed * 4.0), direction);
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
    result[@"ping_ms"] = [self runNumberForKey:@"ping"] ?: ping ?: NSNull.null;
    result[@"jitter_ms"] = [self runNumberForKey:@"jitter"] ?: jitter ?: NSNull.null;
    result[@"packet_loss"] = [self runNumberForKey:@"packet_loss"] ?: packetLoss ?: NSNull.null;
    result[@"isp"] = [self runStringForKey:@"isp"] ?: isp ?: @"";
    result[@"server_provider"] = [self runStringForKey:@"server_provider"] ?: serverProvider ?: @"";
    result[@"server_location"] = [self runStringForKey:@"server_location"] ?: serverLocation ?: @"";
    result[@"override_download"] = @([self runHasSpeedOverrideForDirection:SPDirectionDownload]);
    result[@"override_upload"] = @([self runHasSpeedOverrideForDirection:SPDirectionUpload]);
    result[@"override_ping"] = @([self runNumberForKey:@"ping"] != nil);
    result[@"override_jitter"] = @([self runNumberForKey:@"jitter"] != nil);
    result[@"override_packet_loss"] = @([self runNumberForKey:@"packet_loss"] != nil);
    result[@"override_isp"] = @([self runStringForKey:@"isp"] != nil);
    result[@"override_server_provider"] = @([self runStringForKey:@"server_provider"] != nil);
    result[@"override_server_location"] = @([self runStringForKey:@"server_location"] != nil);
    result[@"download_samples"] = SPSavedSamples(finalDown);
    result[@"upload_samples"] = SPSavedSamples(finalUp);
    result[@"completed_at"] = @((long long)(NSDate.date.timeIntervalSince1970 * 1000.0));
    self.mutableLastResult = result;
    self.pendingLocalResult = [result copy];
    self.testStarted = NO;
    [self persist];
}

@end
