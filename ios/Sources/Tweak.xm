#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <limits.h>
#import "SPState.h"
#import "SPTheme.h"
#import "SPControlsViewController.h"
#import "SPShareBuilder.h"
#import "SPUpdater.h"

// Confirmed from the 7.0.5 suiteStagePrepared switch:
// 1 = latency, 2 = download, 3 = upload.
static const NSInteger SPStageLatency = 1;
static const NSInteger SPStageDownload = 2;
static const NSInteger SPStageUpload = 3;
static const NSInteger SPButtonTag = 0x53505031;
static const NSInteger SPBadgeTag = 0x53505032;
// A transparent, non-accessibility fallback target stays in the provider row
// when the private ISP view drops or swallows long-press gestures.  It is not
// a floating control and is never added to the gauge or navigation bar.
static const NSInteger SPProviderHotspotTag = 0x53505033;
static const void *SPObserverTokenKey = &SPObserverTokenKey;
static const void *SPProviderLayoutRetryKey = &SPProviderLayoutRetryKey;
static const void *SPProviderFallbackTargetKey = &SPProviderFallbackTargetKey;

static id SPObject(id object, SEL selector);

@interface SPObserverToken : NSObject
@property(nonatomic, strong) id token;
@end

@implementation SPObserverToken
- (void)dealloc {
    if (_token) [[NSNotificationCenter defaultCenter] removeObserver:_token];
}
@end

static id SPKVCValue(id object, NSString *key) {
    if (!object || !key.length) return nil;
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}

static void SPSetKVCValue(id object, NSString *key, id value) {
    if (!object || !key.length || !value) return;
    @try { [object setValue:value forKey:key]; }
    @catch (__unused NSException *exception) {}
}

static double SPDouble(id object, SEL selector, double fallback) {
    if (!object || ![object respondsToSelector:selector]) return fallback;
    return ((double (*)(id, SEL))objc_msgSend)(object, selector);
}

static long long SPLongLong(id object, SEL selector, long long fallback) {
    if (!object || ![object respondsToSelector:selector]) return fallback;
    return ((long long (*)(id, SEL))objc_msgSend)(object, selector);
}

static void SPSetDouble(id object, SEL selector, double value) {
    if (object && [object respondsToSelector:selector]) ((void (*)(id, SEL, double))objc_msgSend)(object, selector, value);
}

static void SPSetLongLong(id object, SEL selector, long long value) {
    if (object && [object respondsToSelector:selector]) ((void (*)(id, SEL, long long))objc_msgSend)(object, selector, value);
}

static void SPSetObject(id object, SEL selector, id value) {
    if (object && value && [object respondsToSelector:selector]) ((void (*)(id, SEL, id))objc_msgSend)(object, selector, value);
}

static long long SPRawFromMbps(double mbps) {
    if (!isfinite(mbps) || mbps <= 0.0) return 0;
    long double raw = (long double)mbps * 1000.0L;
    if (raw >= (long double)LLONG_MAX) return LLONG_MAX;
    return (long long)llround((double)raw);
}

static long long SPScaledRaw(long long nativeRaw, long long measuredRaw, long long shownRaw) {
    if (nativeRaw <= 0 || measuredRaw <= 0 || shownRaw <= 0) return shownRaw;
    long double scaled = (long double)nativeRaw * (long double)shownRaw / (long double)measuredRaw;
    if (scaled >= (long double)LLONG_MAX) return LLONG_MAX;
    return (long long)llround((double)scaled);
}

static id SPPacketLossModel(NSNumber *loss) {
    Class lossClass = NSClassFromString(@"ReportPacketLossModel");
    if (!loss || !lossClass) return nil;
    NSInteger sent = loss.doubleValue >= 100.0 ? 10000 : 1000;
    NSInteger received = loss.doubleValue >= 100.0 ? 1 : 1000 - (NSInteger)llround(loss.doubleValue * 10.0);
    id model = [lossClass new];
    SPSetObject(model, NSSelectorFromString(@"setSent:"), @(sent));
    SPSetObject(model, NSSelectorFromString(@"setReceived:"), @(received));
    return model;
}

static NSArray *SPGraphEntries(NSArray<NSDictionary<NSString *, NSNumber *> *> *samples) {
    Class entryClass = NSClassFromString(@"GraphSampleEntryModel");
    if (!entryClass) return nil;
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:samples.count];
    SEL initializer = NSSelectorFromString(@"initWithSpeed:progress:");
    for (NSDictionary *sample in samples) {
        long long rawSpeed = SPRawFromMbps([sample[@"speedMbps"] doubleValue]);
        double progress = [sample[@"progress"] doubleValue];
        id allocated = [entryClass alloc];
        id entry = [allocated respondsToSelector:initializer] ? ((id (*)(id, SEL, long long, double))objc_msgSend)(allocated, initializer, rawSpeed, progress) : nil;
        if (entry) [entries addObject:entry];
    }
    return entries;
}

static id SPGraphSamplesForResult(id savedResult, NSDictionary *last) {
    Class samplesClass = NSClassFromString(@"GraphSamplesModel");
    if (!samplesClass) return nil;
    id existing = SPKVCValue(savedResult, @"graphSamples");
    id download = SPObject(existing, NSSelectorFromString(@"download"));
    id upload = SPObject(existing, NSSelectorFromString(@"upload"));
    if ([last[@"override_download"] boolValue]) download = SPGraphEntries(last[@"download_samples"]);
    if ([last[@"override_upload"] boolValue]) upload = SPGraphEntries(last[@"upload_samples"]);
    SEL initializer = NSSelectorFromString(@"initWithDownload:upload:");
    id allocated = [samplesClass alloc];
    return [allocated respondsToSelector:initializer] ? ((id (*)(id, SEL, id, id))objc_msgSend)(allocated, initializer, download, upload) : nil;
}

static id SPObject(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSDictionary<NSString *, id> *SPResultDictionaryFromModel(id model) {
    if (!model) return @{};
    id downloadRaw = SPKVCValue(model, @"download");
    id uploadRaw = SPKVCValue(model, @"upload");
    id ping = SPKVCValue(model, @"latency");
    id jitter = SPKVCValue(model, @"jitter");
    id sent = SPKVCValue(model, @"packetsSent");
    id received = SPKVCValue(model, @"packetsReceived");
    id loss = NSNull.null;
    if ([sent respondsToSelector:@selector(doubleValue)] && [sent doubleValue] > 0 && [received respondsToSelector:@selector(doubleValue)]) {
        loss = @(SPRoundedMbps((1.0 - [received doubleValue] / [sent doubleValue]) * 100.0));
    }
    return @{
        @"download_mbps": [downloadRaw respondsToSelector:@selector(doubleValue)] ? @([downloadRaw doubleValue] / 1000.0) : NSNull.null,
        @"upload_mbps": [uploadRaw respondsToSelector:@selector(doubleValue)] ? @([uploadRaw doubleValue] / 1000.0) : NSNull.null,
        @"ping_ms": ping ?: NSNull.null,
        @"jitter_ms": jitter ?: NSNull.null,
        @"packet_loss": loss,
        @"isp": SPKVCValue(model, @"isp") ?: @"",
        @"server_provider": SPKVCValue(model, @"serverSponsor") ?: @"",
        @"server_location": SPKVCValue(model, @"serverName") ?: @"",
    };
}

static NSArray<NSDictionary<NSString *, id> *> *SPAllLocalResultDictionaries(void) {
    Class coreData = NSClassFromString(@"CoreDataManager");
    id manager = coreData && [coreData respondsToSelector:@selector(instance)] ? ((id (*)(id, SEL))objc_msgSend)(coreData, @selector(instance)) : nil;
    id models = SPObject(manager, NSSelectorFromString(@"getAllResults"));
    if (![models isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:[models count]];
    for (id model in models) [results addObject:SPResultDictionaryFromModel(model)];
    return results;
}

static UILabel *SPLabel(id object, NSString *getter) {
    id value = SPObject(object, NSSelectorFromString(getter));
    return [value isKindOfClass:UILabel.class] ? value : nil;
}

static void SPCollectLabels(UIView *view, NSMutableArray<UILabel *> *labels) {
    if ([view isKindOfClass:UILabel.class]) [labels addObject:(UILabel *)view];
    for (UIView *child in view.subviews) SPCollectLabels(child, labels);
}

static UILabel *SPDisplayLabel(id object, NSString *getter) {
    id value = SPObject(object, NSSelectorFromString(getter));
    if ([value isKindOfClass:UILabel.class]) return value;
    if (![value isKindOfClass:UIView.class]) return nil;
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    SPCollectLabels(value, labels);
    UILabel *best = nil;
    for (UILabel *candidate in labels) {
        BOOL containsDigit = [candidate.text rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound;
        if (!best || (containsDigit && candidate.font.pointSize > best.font.pointSize)) best = candidate;
    }
    return best;
}

static NSNumber *SPNumberObjectFromLabel(UILabel *label) {
    NSString *text = [label.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!text.length || [text rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location == NSNotFound) return nil;
    NSNumberFormatter *localized = [NSNumberFormatter new];
    localized.numberStyle = NSNumberFormatterDecimalStyle;
    localized.locale = NSLocale.currentLocale;
    NSNumber *number = [localized numberFromString:text];
    if (!number) {
        NSNumberFormatter *invariant = [NSNumberFormatter new];
        invariant.numberStyle = NSNumberFormatterDecimalStyle;
        invariant.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        number = [invariant numberFromString:text];
    }
    return number && isfinite(number.doubleValue) ? number : nil;
}

static double SPNumberFromLabel(UILabel *label) {
    return [SPNumberObjectFromLabel(label) doubleValue];
}

static NSString *SPFormatMbps(double value) {
    return [NSString stringWithFormat:@"%.1f", value];
}

static void SPApplyLastResultIdentityLabels(id controller, NSDictionary *result);

static void SPSetInteger(id object, SEL selector, NSInteger value) {
    if (object && [object respondsToSelector:selector]) ((void (*)(id, SEL, NSInteger))objc_msgSend)(object, selector, value);
}

// The private suite has changed its owner object between releases.  Apply the
// bounded data-saver budget defensively through any config object that exposes
// the documented native setter names.  If a setter is absent we leave the
// stock engine untouched rather than risking a verifier or selector crash.
static void SPApplyDataSaverToObject(id owner) {
    if (!owner || ![SPState.shared runBoolForKey:@"data_saver_mode"]) return;
    NSMutableArray *candidates = [NSMutableArray arrayWithObject:owner];
    for (NSString *key in @[@"suiteConfig", @"configuration", @"testConfiguration", @"config"]) {
        id value = SPKVCValue(owner, key);
        if (value && ![candidates containsObject:value]) [candidates addObject:value];
    }
    for (id config in candidates) {
        SPSetInteger(config, NSSelectorFromString(@"setDownloadMaxDurationSeconds:"), 2);
        SPSetInteger(config, NSSelectorFromString(@"setUploadMaxDurationSeconds:"), 2);
        SPSetInteger(config, NSSelectorFromString(@"setDownloadMaxBytesPerConnection:"), 262144);
        SPSetInteger(config, NSSelectorFromString(@"setUploadMaxBytesPerConnection:"), 262144);
        SPSetInteger(config, NSSelectorFromString(@"setDownloadMinDurationSeconds:"), 1);
        SPSetInteger(config, NSSelectorFromString(@"setUploadMinDurationSeconds:"), 1);
    }
}

static void SPSetOfflineFrame(id controller, SPDirection direction, double value) {
    NSString *text = SPFormatMbps(value);
    UILabel *label = SPDisplayLabel(controller, direction == SPDirectionDownload ? @"downloadResult" : @"uploadResult");
    if (label) label.text = text;
    // Some builds expose the gauge display directly, while others keep it in
    // a child object.  Both calls are optional and therefore safe on either.
    id display = SPObject(controller, NSSelectorFromString(@"speedDisplay"));
    if (!display) display = SPObject(controller, NSSelectorFromString(@"display"));
    if (display) SPSetDouble(display, NSSelectorFromString(@"t0:"), value);
}

static void SPStartOfflineDemo(id controller) {
    SPState *state = SPState.shared;
    [state setStage:SPStageDownload];
    UILabel *download = SPDisplayLabel(controller, @"downloadResult");
    UILabel *upload = SPDisplayLabel(controller, @"uploadResult");
    UILabel *ping = SPDisplayLabel(controller, @"pingResult");
    UILabel *jitter = SPDisplayLabel(controller, @"jitterResult");
    if (download) download.text = @"0.0";
    if (upload) upload.text = @"0.0";
    if (ping) ping.text = @"-";
    if (jitter) jitter.text = @"-";
    __weak id weakController = controller;
    const NSInteger frames = 24;
    for (NSInteger frame = 0; frame <= frames; frame++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(frame * 100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            id strongController = weakController;
            if (!strongController || !state.testActive) return;
            double progress = (double)frame / (double)frames;
            if (frame <= 12) {
                [state setStage:SPStageDownload];
                double shown = [state displayMbpsForDirection:SPDirectionDownload measuredMbps:100.0 progress:progress];
                SPSetOfflineFrame(strongController, SPDirectionDownload, shown);
            } else {
                [state setStage:SPStageUpload];
                double uploadProgress = (double)(frame - 12) / (double)(frames - 12);
                double shown = [state displayMbpsForDirection:SPDirectionUpload measuredMbps:20.0 progress:uploadProgress];
                SPSetOfflineFrame(strongController, SPDirectionUpload, shown);
            }
            if (frame == 12) {
                NSNumber *demoPing = [state runNumberForKey:@"ping"] ?: @20;
                NSNumber *demoJitter = [state runNumberForKey:@"jitter"] ?: @3;
                if (ping) ping.text = demoPing.stringValue;
                if (jitter) jitter.text = demoJitter.stringValue;
            }
            if (frame == frames) {
                [state completeOfflineDemo];
                NSDictionary *last = state.lastResult;
                if (download) download.text = SPFormatMbps([last[@"download_mbps"] doubleValue]);
                if (upload) upload.text = SPFormatMbps([last[@"upload_mbps"] doubleValue]);
                if (ping && last[@"ping_ms"] != NSNull.null) ping.text = [last[@"ping_ms"] stringValue];
                if (jitter && last[@"jitter_ms"] != NSNull.null) jitter.text = [last[@"jitter_ms"] stringValue];
                SPApplyLastResultIdentityLabels(strongController, last);
                UILabel *message = SPLabel(strongController, @"userMessageLabel");
                if (message) message.text = @"Offline demo - local only (not submitted)";
            }
        });
    }
}

// A few 7.x builds can deliver transfer callbacks before the visible result
// label has been laid out, or briefly stop delivering callbacks while the
// socket is warming up.  In that window the stock label can remain at a small
// measured value (the reported "6 Mbps cap") even though the custom target is
// already finalized.  Keep a short, guarded label-only fallback in parallel
// with the native callbacks.  It never touches the native transfer model or
// server selection, and it stops as soon as the stage changes or the test
// completes.
static void SPScheduleLiveLabelFallback(id controller, SPDirection direction) {
    SPState *state = SPState.shared;
    if (!controller || !state.testActive || ![state runHasSpeedOverrideForDirection:direction]) return;
    NSInteger expectedStage = direction == SPDirectionDownload ? SPStageDownload : SPStageUpload;
    __weak id weakController = controller;
    for (NSInteger frame = 0; frame < 160; frame++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(frame * 100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            id strongController = weakController;
            if (!strongController || !state.testActive || state.stage != expectedStage ||
                ![state runHasSpeedOverrideForDirection:direction]) return;
            NSString *getter = direction == SPDirectionDownload ? @"downloadResult" : @"uploadResult";
            UILabel *label = SPDisplayLabel(strongController, getter);
            if (!label) return;
            double measured = SPNumberFromLabel(label);
            double shown = [state displayMbpsForDirection:direction measuredMbps:measured progress:0.0];
            if (isfinite(shown) && shown >= 0.0) label.text = SPFormatMbps(shown);
        });
    }
}

static void SPApplyIdentityLabels(id controller) {
    SPState *state = SPState.shared;
    if (!state.active) return;
    NSString *isp = [state stringForKey:@"isp"];
    NSString *provider = [state stringForKey:@"server_provider"];
    NSString *location = [state stringForKey:@"server_location"];
    if (isp) SPLabel(controller, @"endOfTestISPLabel").text = isp;
    if (provider) SPLabel(controller, @"endOfTestServerNameLabel").text = provider;
    if (location) SPLabel(controller, @"endOfTestServerLocationLabel").text = location;
}

static void SPApplyRunIdentityLabels(id controller) {
    NSString *isp = [SPState.shared runStringForKey:@"isp"];
    NSString *provider = [SPState.shared runStringForKey:@"server_provider"];
    NSString *location = [SPState.shared runStringForKey:@"server_location"];
    if (isp) SPLabel(controller, @"endOfTestISPLabel").text = isp;
    if (provider) SPLabel(controller, @"endOfTestServerNameLabel").text = provider;
    if (location) SPLabel(controller, @"endOfTestServerLocationLabel").text = location;
}

static void SPApplyLastResultIdentityLabels(id controller, NSDictionary *result) {
    if ([result[@"override_isp"] boolValue]) SPLabel(controller, @"endOfTestISPLabel").text = result[@"isp"];
    if ([result[@"override_server_provider"] boolValue]) SPLabel(controller, @"endOfTestServerNameLabel").text = result[@"server_provider"];
    if ([result[@"override_server_location"] boolValue]) SPLabel(controller, @"endOfTestServerLocationLabel").text = result[@"server_location"];
}

static void SPHideOfficialUpdateBanner(id controller) {
    UILabel *message = SPLabel(controller, @"userMessageLabel");
    NSString *text = message.text.lowercaseString;
    if ([text containsString:@"update available"] || [text containsString:@"new version"] || [text containsString:@"update speedtest"]) {
        message.hidden = YES;
    }
}

static UIWindow *SPActiveWindow(void) {
    UIApplication *application = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] ||
                (scene.activationState != UISceneActivationStateForegroundActive &&
                 scene.activationState != UISceneActivationStateForegroundInactive)) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) if (window.isKeyWindow) return window;
            for (UIWindow *window in windowScene.windows) if (!window.hidden && window.alpha > 0.0) return window;
        }
    }
    for (UIWindow *window in application.windows) if (window.isKeyWindow) return window;
    return application.windows.firstObject;
}

static UIViewController *SPTopController(UIViewController *controller) {
    while (controller) {
        if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
            controller = controller.presentedViewController;
        } else if ([controller isKindOfClass:UINavigationController.class]) {
            controller = ((UINavigationController *)controller).visibleViewController;
        } else if ([controller isKindOfClass:UITabBarController.class]) {
            controller = ((UITabBarController *)controller).selectedViewController;
        } else {
            break;
        }
    }
    return controller;
}

static UIViewController *SPPresenter(id object) {
    UIViewController *controller = [object isKindOfClass:UIViewController.class] ? object : SPActiveWindow().rootViewController;
    return SPTopController(controller);
}

static void SPPresentUnlock(UIViewController *presenter) {
    UIViewController *host = presenter ?: SPPresenter(nil);
    if (!host) return;
    if (!SPState.shared.panelHidden) { [SPControlsViewController presentFrom:host]; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unlock Speedtest+" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Password"; field.secureTextEntry = YES; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Unlock" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if ([SPState.shared unlockWithPassword:alert.textFields.firstObject.text ?: @""]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [SPControlsViewController presentFrom:host]; });
        }
        else {
            UIAlertController *failed = [UIAlertController alertControllerWithTitle:@"Speedtest+" message:@"Incorrect password." preferredStyle:UIAlertControllerStyleAlert];
            [failed addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            dispatch_async(dispatch_get_main_queue(), ^{ [host presentViewController:failed animated:YES completion:nil]; });
        }
    }]];
    [host presentViewController:alert animated:YES completion:nil];
}

@interface SPActionTarget : NSObject
@property(nonatomic, weak) UIViewController *presenter;
- (void)openControls;
- (void)openGuide;
- (void)longPressed:(UILongPressGestureRecognizer *)recognizer;
@end

@implementation SPActionTarget
- (void)openControls { SPPresentUnlock(self.presenter ?: SPPresenter(nil)); }
- (void)openGuide {
    UIViewController *host = self.presenter ?: SPPresenter(nil);
    if (SPState.shared.panelHidden) SPPresentUnlock(host);
    else [SPControlsViewController presentGuideFrom:host allowOpenControls:YES];
}
- (void)longPressed:(UILongPressGestureRecognizer *)recognizer { if (recognizer.state == UIGestureRecognizerStateBegan) SPPresentUnlock(self.presenter); }
@end

static const void *SPActionTargetKey = &SPActionTargetKey;
static const void *SPOriginalLabelTextKey = &SPOriginalLabelTextKey;
static const void *SPPreviousLabelOverrideKey = &SPPreviousLabelOverrideKey;
static const void *SPProviderGestureKey = &SPProviderGestureKey;
static const void *SPProviderHotspotKey = &SPProviderHotspotKey;

static UIViewController *SPViewControllerForView(UIView *view) {
    UIResponder *responder = view;
    while ((responder = responder.nextResponder)) {
        if ([responder isKindOfClass:UIViewController.class]) return (UIViewController *)responder;
    }
    return SPPresenter(nil);
}

static void SPApplyLabelOverride(UILabel *label, NSString *override, BOOL active) {
    if (!label) return;
    NSString *original = objc_getAssociatedObject(label, SPOriginalLabelTextKey);
    NSString *previousOverride = objc_getAssociatedObject(label, SPPreviousLabelOverrideKey);
    if (active && override.length) {
        if (!original) {
            objc_setAssociatedObject(label, SPOriginalLabelTextKey, label.text ?: @"", OBJC_ASSOCIATION_COPY_NONATOMIC);
        } else if (previousOverride && ![label.text isEqualToString:previousOverride]) {
            objc_setAssociatedObject(label, SPOriginalLabelTextKey, label.text ?: @"", OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        label.text = override;
        objc_setAssociatedObject(label, SPPreviousLabelOverrideKey, override, OBJC_ASSOCIATION_COPY_NONATOMIC);
    } else if (original) {
        label.text = original;
        objc_setAssociatedObject(label, SPOriginalLabelTextKey, nil, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(label, SPPreviousLabelOverrideKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
}

static void SPApplyProviderLabels(id hostController) {
    BOOL active = SPState.shared.active;
    SPApplyLabelOverride(SPLabel(hostController, @"ispNameLabel"), [SPState.shared stringForKey:@"isp"], active);
    SPApplyLabelOverride(SPLabel(hostController, @"hostNameLabel"), [SPState.shared stringForKey:@"server_provider"], active);
    SPApplyLabelOverride(SPLabel(hostController, @"hostLocationLabel"), [SPState.shared stringForKey:@"server_location"], active);
}

static void SPRefreshBadge(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class]) return;
    UIButton *button = [controller.view viewWithTag:SPButtonTag];
    UILabel *badge = [controller.view viewWithTag:SPBadgeTag];
    NSInteger count = SPState.shared.activeOverrideCount;
    // Keep the Speedtest+ affordance present even when the panel is locked.
    // Hiding it made the password-protected mode impossible to rediscover on
    // builds where the provider long-press was swallowed by a private view.
    button.hidden = NO;
    if (button) [SPTheme applyFunctionalMaterialToView:button theme:[SPTheme themeAtIndex:SPState.shared.themeIndex]];
    button.accessibilityHint = SPState.shared.panelHidden
        ? @"Unlocks the password-protected Speedtest+ controls"
        : @"Opens the Speedtest+ guide and controls";
    badge.hidden = count == 0 || SPState.shared.panelHidden;
    badge.text = [NSString stringWithFormat:@"CUSTOM \u2022 %ld", (long)count];
}

static BOOL SPViewIsDescendantOf(UIView *view, UIView *ancestor) {
    if (!view || !ancestor) return NO;
    UIView *cursor = view;
    while (cursor) {
        if (cursor == ancestor) return YES;
        cursor = cursor.superview;
    }
    return NO;
}

static void SPInstallProviderLongPress(UIView *view, SPActionTarget *target) {
    if (![view isKindOfClass:UIView.class] || !target) return;
    // Some builds expose ispView as a passive container and some put a label
    // above it.  Explicitly enabling interaction and installing the gesture
    // on each provider-only view makes the shortcut work in both layouts.
    view.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *oldGesture = objc_getAssociatedObject(view, SPProviderGestureKey);
    if (oldGesture) [view removeGestureRecognizer:oldGesture];
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:@selector(longPressed:)];
    gesture.minimumPressDuration = 0.55;
    gesture.allowableMovement = 24.0;
    gesture.cancelsTouchesInView = NO;
    [view addGestureRecognizer:gesture];
    objc_setAssociatedObject(view, SPProviderGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIButton *SPInstallProviderHotspot(UIViewController *presenter, UIView *providerView, UILabel *ispLabel, SPActionTarget *target) {
    if (!presenter || ![providerView isKindOfClass:UIView.class] || !target) return nil;
    providerView.userInteractionEnabled = YES;
    UIButton *hotspot = [presenter.view viewWithTag:SPProviderHotspotTag];
    if (hotspot && !SPViewIsDescendantOf(hotspot, providerView)) {
        [hotspot removeFromSuperview];
        hotspot = nil;
    }
    if (!hotspot) {
        hotspot = [UIButton buttonWithType:UIButtonTypeCustom];
        hotspot.tag = SPProviderHotspotTag;
        hotspot.translatesAutoresizingMaskIntoConstraints = NO;
        hotspot.backgroundColor = UIColor.clearColor;
        hotspot.alpha = 0.01; // still hit-testable, but visually invisible
        hotspot.isAccessibilityElement = NO;
        hotspot.accessibilityElementsHidden = YES;
        hotspot.accessibilityIdentifier = @"speedtest_plus_controls_hotspot";
        [providerView addSubview:hotspot];
        [hotspot.widthAnchor constraintEqualToConstant:48].active = YES;
        [hotspot.heightAnchor constraintEqualToConstant:48].active = YES;
        [hotspot.trailingAnchor constraintEqualToAnchor:providerView.trailingAnchor].active = YES;
        if ([ispLabel isKindOfClass:UILabel.class]) {
            [hotspot.centerYAnchor constraintEqualToAnchor:ispLabel.centerYAnchor].active = YES;
        } else {
            [hotspot.centerYAnchor constraintEqualToAnchor:providerView.centerYAnchor].active = YES;
        }
    }
    [hotspot removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [hotspot addTarget:target action:@selector(openControls) forControlEvents:UIControlEventTouchUpInside];
    hotspot.hidden = NO;
    [providerView bringSubviewToFront:hotspot];
    objc_setAssociatedObject(providerView, SPProviderHotspotKey, hotspot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return hotspot;
}

// The provider host is private UIKit/Swift code and has changed shape across
// minor Speedtest releases.  When its class or accessors are renamed, the
// selector hooks above cannot find an anchor even though the native provider
// row is already on screen.  Pick a conservative, bottom-row text label as a
// last-resort anchor.  This never replaces the native provider/server
// controls: the custom button is a small sibling of the label and its gesture
// recognizer does not cancel touches in the row.
static BOOL SPFallbackLabelIsUsable(UILabel *label) {
    if (![label isKindOfClass:UILabel.class] || label.hidden || label.alpha < 0.05) return NO;
    NSString *text = [label.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!text.length || text.length > 64) return NO;
    NSString *lower = text.lowercaseString;
    // Survey/question labels can sit below the provider row and are often
    // hosted by generic UIView subclasses.  Exclude their actual text too,
    // otherwise the hierarchy fallback can attach the controls affordance to
    // the feedback card instead of the ISP row on a rebuilt UI.
    for (NSString *excluded in @[@"download", @"upload", @"ping", @"jitter", @"mbps", @"feedback", @"speedtest", @"video", @"map", @"downdetector", @"how would", @"how does", @"expectation", @"compare your", @"rate "]) {
        if ([lower containsString:excluded]) return NO;
    }
    // Device model labels commonly look like SM-S928B or contain only
    // digits/punctuation.  Prefer the ISP text rather than that second line.
    if ([text rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location == NSNotFound) return NO;
    if ([text containsString:@"-"] && [text rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound) return NO;
    return YES;
}

static BOOL SPFallbackLabelIsInNonProviderSurface(UILabel *label, UIViewController *controller) {
    UIView *cursor = label.superview;
    while (cursor && cursor != controller.view) {
        NSString *name = NSStringFromClass(cursor.class).lowercaseString;
        // Never put the entry point in the feedback survey, tab bar, or a
        // navigation/guide surface merely because it happens to be lower on
        // screen than the provider row.
        for (NSString *excluded in @[@"feedback", @"survey", @"question", @"tabbar", @"navigation", @"guide"]) {
            if ([name containsString:excluded]) return YES;
        }
        cursor = cursor.superview;
    }
    return NO;
}

static UILabel *SPFallbackProviderLabel(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class] || !controller.view) return nil;
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    SPCollectLabels(controller.view, labels);
    CGRect bounds = controller.view.bounds;
    UILabel *best = nil;
    CGRect bestRect = CGRectZero;
    for (UILabel *label in labels) {
        if (!SPFallbackLabelIsUsable(label) || !label.superview) continue;
        if (SPFallbackLabelIsInNonProviderSurface(label, controller)) continue;
        CGRect rect = [label.superview convertRect:label.frame toView:controller.view];
        if (CGRectIsNull(rect) || CGRectIsInfinite(rect) || rect.size.width < 24.0 || CGRectGetMidY(rect) < bounds.size.height * 0.55) continue;
        // The ISP row is the lowest text cluster in the speed card.  Prefer
        // the leftmost label when ISP and server labels share a baseline.
        if (!best || rect.origin.y > bestRect.origin.y + 16.0 ||
            (fabs(rect.origin.y - bestRect.origin.y) <= 16.0 && rect.origin.x < bestRect.origin.x)) {
            best = label;
            bestRect = rect;
        }
    }
    return best;
}

static UIButton *SPInstallFallbackProviderButton(UIViewController *controller, UILabel *ispLabel) {
    if (![controller isKindOfClass:UIViewController.class] || ![ispLabel isKindOfClass:UILabel.class]) return nil;
    UIView *row = ispLabel.superview;
    if (![row isKindOfClass:UIView.class]) return nil;
    // Keep the stable speed controller as the weak target owner.  Resolving
    // SPPresenter here could capture a transient native setup sheet; after it
    // is dismissed that sheet is gone and the button would lose its action.
    UIViewController *presenter = controller;
    if (!presenter) return nil;

    UIButton *existing = [controller.view viewWithTag:SPButtonTag];
    if (existing) return existing;
    SPActionTarget *target = [SPActionTarget new];
    target.presenter = presenter;
    objc_setAssociatedObject(controller, SPProviderFallbackTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SPButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = ispLabel.textColor ?: UIColor.whiteColor;
    button.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:@"info.circle"];
        if (image) [button setImage:image forState:UIControlStateNormal];
        else [button setTitle:@"\u24d8" forState:UIControlStateNormal];
    } else {
        [button setTitle:@"\u24d8" forState:UIControlStateNormal];
    }
    button.accessibilityLabel = @"Open Speedtest+ information and controls";
    button.accessibilityHint = SPState.shared.panelHidden
        ? @"Unlocks the password-protected Speedtest+ controls"
        : @"Opens the Speedtest+ guide and controls";
    button.accessibilityIdentifier = @"speedtest_plus_provider_info_fallback";
    button.backgroundColor = UIColor.clearColor;
    button.alpha = 1.0;
    button.userInteractionEnabled = YES;
    [SPTheme applyFunctionalMaterialToView:button theme:[SPTheme themeAtIndex:SPState.shared.themeIndex]];
    [button.widthAnchor constraintEqualToConstant:48].active = YES;
    [button.heightAnchor constraintEqualToConstant:48].active = YES;
    [button addTarget:target action:@selector(openGuide) forControlEvents:UIControlEventTouchUpInside];

    if ([row isKindOfClass:UIStackView.class] && [((UIStackView *)row).arrangedSubviews containsObject:ispLabel]) {
        UIStackView *stack = (UIStackView *)row;
        NSUInteger index = [stack.arrangedSubviews indexOfObject:ispLabel];
        [stack insertArrangedSubview:button atIndex:MIN(index + 1, stack.arrangedSubviews.count)];
    } else {
        [row addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.leadingAnchor constraintEqualToAnchor:ispLabel.trailingAnchor constant:6.0],
            [button.centerYAnchor constraintEqualToAnchor:ispLabel.centerYAnchor],
            [button.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-4.0]
        ]];
    }
    SPInstallProviderLongPress(row, target);
    SPInstallProviderLongPress(ispLabel, target);
    SPInstallProviderHotspot(presenter, row, ispLabel, target);
    [row bringSubviewToFront:button];
    return button;
}

static void SPAttachFallbackProviderControls(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class] || [controller.view viewWithTag:SPButtonTag]) return;
    UILabel *label = SPFallbackProviderLabel(controller);
    if (!label) return;
    SPInstallFallbackProviderButton(controller, label);
}

static void SPRemoveLegacyFloatingControls(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class]) return;
    // Builds before 0.1.3 placed the controls in the lower-right corner of
    // the whole screen. Remove only those direct children; the new provider
    // icon lives below ispView and must be preserved.
    UIButton *button = [controller.view viewWithTag:SPButtonTag];
    if (button && button.superview == controller.view) [button removeFromSuperview];
    UILabel *badge = [controller.view viewWithTag:SPBadgeTag];
    if (badge && badge.superview == controller.view) [badge removeFromSuperview];
}

static void SPAttachControls(UIViewController *controller) {
    // The info affordance is intentionally attached to the ISP row by
    // SPAttachProviderControls. Keep this hook only as a migration cleanup for
    // already-loaded screens from an older dylib. There is deliberately no
    // floating or navigation-bar S+ control here; the ISP row is the sole
    // controls entry point, matching the Android layout.
    SPRemoveLegacyFloatingControls(controller);
}

static void SPAttachProviderControls(id hostController, UIStackView *stack) {
    UIView *ispView = SPObject(hostController, NSSelectorFromString(@"ispView"));
    UILabel *ispLabel = SPLabel(hostController, @"ispNameLabel");
    // A few iOS builds return nil for the private ispView accessor even though
    // the label is already attached.  Use its row as a safe provider-only
    // fallback instead of abandoning the controls entry point.  If the label
    // accessor itself changed, the provider host/stack is still a safe custom
    // anchor for the Speedtest+ button and gesture.
    if (![ispView isKindOfClass:UIView.class] && [ispLabel.superview isKindOfClass:UIView.class]) ispView = ispLabel.superview;
    if (![ispView isKindOfClass:UIView.class] && [stack isKindOfClass:UIView.class]) ispView = stack;
    if (![ispView isKindOfClass:UIView.class]) return;
    UIViewController *presenter = SPViewControllerForView(ispView);
    if (!presenter) return;

    UIButton *existing = [presenter.view viewWithTag:SPButtonTag];
    UILabel *existingBadge = [presenter.view viewWithTag:SPBadgeTag];
    if (existing && !SPViewIsDescendantOf(existing, ispView) && !SPViewIsDescendantOf(existing, stack)) {
        [existing removeFromSuperview];
        [existingBadge removeFromSuperview];
        existing = nil;
    }
    if (existing) {
        // Provider rows can be rebuilt after the first guide is dismissed.
        // Rebind the action target and long-press recognizer every time so a
        // retained button never points at a stale presenter.
        SPActionTarget *target = [SPActionTarget new];
        target.presenter = presenter;
        objc_setAssociatedObject(hostController, SPActionTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [existing removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [existing addTarget:target action:@selector(openGuide) forControlEvents:UIControlEventTouchUpInside];
        SPInstallProviderLongPress(ispView, target);
        SPInstallProviderLongPress(ispLabel, target);
        if (ispLabel.superview != ispView) SPInstallProviderLongPress(ispLabel.superview, target);
        SPInstallProviderHotspot(presenter, ispView, ispLabel, target);
        SPApplyProviderLabels(hostController);
        SPRefreshBadge(presenter);
        return;
    }

    SPActionTarget *target = [SPActionTarget new];
    target.presenter = presenter;
    objc_setAssociatedObject(hostController, SPActionTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILabel *badge = [UILabel new];
    badge.tag = SPBadgeTag;
    badge.font = [UIFont boldSystemFontOfSize:10];
    badge.textColor = UIColor.whiteColor;
    badge.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    badge.layer.cornerRadius = 8;
    badge.layer.masksToBounds = YES;
    badge.textAlignment = NSTextAlignmentCenter;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    [badge.widthAnchor constraintGreaterThanOrEqualToConstant:68].active = YES;
    [badge.heightAnchor constraintEqualToConstant:18].active = YES;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SPButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = ispLabel.textColor ?: UIColor.whiteColor;
    button.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:@"info.circle"];
        if (image) [button setImage:image forState:UIControlStateNormal];
        else [button setTitle:@"\u24d8" forState:UIControlStateNormal];
    } else {
        [button setTitle:@"\u24d8" forState:UIControlStateNormal];
    }
    button.accessibilityLabel = @"Open Speedtest+ information and controls";
    button.accessibilityHint = @"Opens the Speedtest+ guide and controls";
    button.backgroundColor = UIColor.clearColor;
    button.clipsToBounds = NO;
    [SPTheme applyFunctionalMaterialToView:button theme:[SPTheme themeAtIndex:SPState.shared.themeIndex]];
    // Keep the visual icon compact while providing the full 48pt touch target
    // expected by iOS accessibility and by the controls guide.
    [button.widthAnchor constraintEqualToConstant:48].active = YES;
    [button.heightAnchor constraintEqualToConstant:48].active = YES;
    [button addTarget:target action:@selector(openGuide) forControlEvents:UIControlEventTouchUpInside];

    [button addSubview:badge];
    [NSLayoutConstraint activateConstraints:@[
        [badge.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [badge.bottomAnchor constraintEqualToAnchor:button.topAnchor constant:2]
    ]];

    UIView *ispRow = ispLabel.superview;
    if ([ispLabel isKindOfClass:UILabel.class] && [ispRow isKindOfClass:UIStackView.class] && [((UIStackView *)ispRow).arrangedSubviews containsObject:ispLabel]) {
        UIStackView *row = (UIStackView *)ispRow;
        NSUInteger labelIndex = [row.arrangedSubviews indexOfObject:ispLabel];
        [row insertArrangedSubview:button atIndex:MIN(labelIndex + 1, row.arrangedSubviews.count)];
    } else if (![ispLabel isKindOfClass:UILabel.class]) {
        // The label getter is private and has changed between app builds.  A
        // trailing button on the provider host keeps the custom entry point
        // available without changing any stock server controls.
        [ispView addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.trailingAnchor constraintEqualToAnchor:ispView.trailingAnchor constant:-4],
            [button.centerYAnchor constraintEqualToAnchor:ispView.centerYAnchor]
        ]];
    } else {
        UIView *container = [ispRow isKindOfClass:UIView.class] && SPViewIsDescendantOf(ispLabel, ispRow) ? ispRow : ispView;
        [container addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.leadingAnchor constraintEqualToAnchor:ispLabel.trailingAnchor constant:6],
            [button.centerYAnchor constraintEqualToAnchor:ispLabel.centerYAnchor],
            [button.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-4]
        ]];
    }

    UIView *providerView = ispView;
    SPInstallProviderLongPress(providerView, target);
    if ([ispLabel isKindOfClass:UILabel.class]) {
        SPInstallProviderLongPress(ispLabel, target);
        if (ispLabel.superview != providerView) SPInstallProviderLongPress(ispLabel.superview, target);
    }
    SPInstallProviderHotspot(presenter, providerView, ispLabel, target);
    __weak UIViewController *weakPresenter = presenter;
    __weak id weakHost = hostController;
    SPObserverToken *observer = [SPObserverToken new];
    observer.token = [[NSNotificationCenter defaultCenter] addObserverForName:nil object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        UIViewController *strongPresenter = weakPresenter;
        id strongHost = weakHost;
        if ([note.name isEqualToString:SPThemeDidChangeNotification] && strongPresenter) {
            [SPTheme applyTheme:[SPTheme themeAtIndex:SPState.shared.themeIndex] toView:strongPresenter.view];
        }
        if ([note.name isEqualToString:SPStateDidChangeNotification]) {
            if (strongPresenter) SPRefreshBadge(strongPresenter);
            if (strongHost) SPApplyProviderLabels(strongHost);
        }
    }];
    objc_setAssociatedObject(hostController, SPObserverTokenKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SPApplyProviderLabels(hostController);
    SPRefreshBadge(presenter);
}

static void SPFindProviderControlsInView(UIView *view) {
    if (![view isKindOfClass:UIView.class]) return;

    UIResponder *responder = view;
    while ((responder = responder.nextResponder)) {
        NSString *className = NSStringFromClass(responder.class);
        if ([className containsString:@"ISPHostController"]) {
            UIStackView *stack = SPObject(responder, NSSelectorFromString(@"assemblyStackView"));
            // The provider host is enough to install the row hotspot.  Some
            // builds expose the stack only after the first layout pass.
            SPAttachProviderControls(responder, [stack isKindOfClass:UIStackView.class] ? stack : nil);
            return;
        }
        if ([responder isKindOfClass:UIViewController.class]) break;
    }

    for (UIView *child in view.subviews) SPFindProviderControlsInView(child);
}

static void SPRetryProviderControls(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class]) return;
    __weak UIViewController *weakController = controller;
    // The provider row is lazy on some iOS 17/18 devices.  Keep the normal
    // private-host retries, then run the public-view fallback after the row
    // has had time to finish its first layout pass.
    for (NSNumber *delay in @[@0.0, @0.25, @0.75, @1.5, @2.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIViewController *strongController = weakController;
            if (!strongController) return;
            SPFindProviderControlsInView(strongController.view);
            if (delay.doubleValue >= 2.5) SPAttachFallbackProviderControls(strongController);
        });
    }
}

// The stock app can present its privacy/educational setup modal just after
// the speed controller's first viewDidAppear.  Presenting the Speedtest+
// guide in that small race window leaves the native Continue button visually
// present underneath an alert and makes it appear unresponsive.  Wait until
// the provider row (our real entry point) is attached and never put the guide
// above a stock onboarding/setup controller.
static BOOL SPHasStockSetupModal(UIViewController *controller) {
    UIViewController *shown = controller.presentedViewController;
    if (!shown) return NO;
    NSString *name = NSStringFromClass(shown.class).lowercaseString;
    return [name containsString:@"onboarding"] ||
           [name containsString:@"educational"] ||
           [name containsString:@"setup"] ||
           [name containsString:@"privacy"] ||
           [name containsString:@"consent"];
}

static void SPQueueIntroGuideAttempt(UIViewController *controller, NSInteger attempt) {
    if (![controller isKindOfClass:UIViewController.class] || SPState.shared.introSeen || attempt > 10) return;
    __weak UIViewController *weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.50 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (!strongController || SPState.shared.introSeen) return;
        SPFindProviderControlsInView(strongController.view);
        UIButton *providerButton = [strongController.view viewWithTag:SPButtonTag];
        if (strongController.presentedViewController || SPHasStockSetupModal(strongController) || !providerButton) {
            SPQueueIntroGuideAttempt(strongController, attempt + 1);
            return;
        }
        [SPControlsViewController presentGuideFrom:strongController allowOpenControls:YES];
    });
}

static void SPAttachProviderControlsAfterLayout(UIViewController *controller) {
    if (![controller isKindOfClass:UIViewController.class]) return;
    // Do not treat any existing tag as proof that the button is still on the
    // current provider row.  iOS rebuilds that row after server selection;
    // the old button can remain on the controller while the visible row has
    // been replaced.  SPAttachProviderControls will reparent stale controls
    // and rebind the gesture/target to the new row.
    // The provider host is lazy on some iOS builds and can be created after
    // both viewDidLoad and viewDidAppear.  Use the first few layout passes as
    // a bounded retry, rather than relying on a private setter being called.
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
    NSNumber *last = objc_getAssociatedObject(controller, SPProviderLayoutRetryKey);
    if (last && now - last.doubleValue < 0.25) return;
    objc_setAssociatedObject(controller, SPProviderLayoutRetryKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SPFindProviderControlsInView(controller.view);
    // A renamed private host can make every selector hook a no-op.  Once the
    // visible speed card has laid out, repair the provider-row affordance from
    // the public UIView/UILabel hierarchy instead of adding a floating button.
    if (![controller.view viewWithTag:SPButtonTag]) SPAttachFallbackProviderControls(controller);
}

static BOOL SPIsScopedController(UIViewController *controller) {
    NSString *name = NSStringFromClass(controller.class);
    return [name containsString:@"SpeedTestViewController"] || [name containsString:@"Result"] ||
           [name containsString:@"Compare"] || [name containsString:@"Feedback"];
}

static void SPApplyThemeToController(UIViewController *controller) {
    if (SPIsScopedController(controller)) [SPTheme applyTheme:[SPTheme themeAtIndex:SPState.shared.themeIndex] toView:controller.view];
}

static void SPExpandChartAxesInView(UIView *view, double requestedMaximum) {
    NSString *name = NSStringFromClass(view.class);
    if ([name containsString:@"Chart"] || [name containsString:@"Axis"]) {
        for (NSString *selectorName in @[@"leftAxis", @"rightAxis", @"yAxis"]) {
            id axis = SPObject(view, NSSelectorFromString(selectorName));
            if (!axis || ![axis respondsToSelector:NSSelectorFromString(@"setAxisMaximum:")]) continue;
            double nativeMaximum = SPDouble(axis, NSSelectorFromString(@"axisMaximum"), 0.0);
            SPSetDouble(axis, NSSelectorFromString(@"setAxisMaximum:"), MAX(nativeMaximum, requestedMaximum));
        }
    }
    for (UIView *child in view.subviews) SPExpandChartAxesInView(child, requestedMaximum);
}

static void SPMutateTransferProgress(id parameters) {
    NSInteger stage = [parameters respondsToSelector:@selector(stageType)] ? ((unsigned char (*)(id, SEL))objc_msgSend)(parameters, @selector(stageType)) : SPState.shared.stage;
    SPDirection direction;
    if (stage == SPStageDownload) direction = SPDirectionDownload;
    else if (stage == SPStageUpload) direction = SPDirectionUpload;
    else return;
    id packetLoss = SPPacketLossModel([SPState.shared runNumberForKey:@"packet_loss"]);
    if (packetLoss) SPSetObject(parameters, @selector(setPacketLoss:), packetLoss);
    if (![SPState.shared runHasSpeedOverrideForDirection:direction]) return;
    double progress = SPDouble(parameters, @selector(progress), 0.0);
    long long measuredRaw = SPLongLong(parameters, @selector(speed), 0);
    long long nativeMST = SPLongLong(parameters, @selector(speedMST), measuredRaw);
    long long nativeSuper = SPLongLong(parameters, @selector(speedSuperSpeed), measuredRaw);
    long long nativeAverage = SPLongLong(parameters, @selector(speedAverage), measuredRaw);
    double measuredMbps = (double)measuredRaw / 1000.0;
    double shownMbps = [SPState.shared displayMbpsForDirection:direction measuredMbps:measuredMbps progress:progress];
    long long raw = SPRawFromMbps(shownMbps);
    SPSetLongLong(parameters, @selector(setSpeed:), raw);
    SPSetLongLong(parameters, @selector(setSpeedMST:), SPScaledRaw(nativeMST, measuredRaw, raw));
    SPSetLongLong(parameters, @selector(setSpeedSuperSpeed:), SPScaledRaw(nativeSuper, measuredRaw, raw));
    SPSetLongLong(parameters, @selector(setSpeedAverage:), SPScaledRaw(nativeAverage, measuredRaw, raw));
}

static void SPMutateTransferCompletion(id parameters) {
    NSInteger stage = [parameters respondsToSelector:@selector(stageType)] ? ((unsigned char (*)(id, SEL))objc_msgSend)(parameters, @selector(stageType)) : SPState.shared.stage;
    SPDirection direction;
    if (stage == SPStageDownload) direction = SPDirectionDownload;
    else if (stage == SPStageUpload) direction = SPDirectionUpload;
    else return;
    if (![SPState.shared runHasSpeedOverrideForDirection:direction]) return;
    long long measuredRaw = SPLongLong(parameters, @selector(speed), 0);
    long long nativeMST = SPLongLong(parameters, @selector(speedMST), measuredRaw);
    long long nativeSuper = SPLongLong(parameters, @selector(speedSuperSpeed), measuredRaw);
    long long nativeAverage = SPLongLong(parameters, @selector(speedAverage), measuredRaw);
    double measuredMbps = (double)measuredRaw / 1000.0;
    long long raw = SPRawFromMbps([SPState.shared finalMbpsForDirection:direction measuredMbps:measuredMbps]);
    SPSetLongLong(parameters, @selector(setSpeed:), raw);
    SPSetLongLong(parameters, @selector(setSpeedMST:), SPScaledRaw(nativeMST, measuredRaw, raw));
    SPSetLongLong(parameters, @selector(setSpeedSuperSpeed:), SPScaledRaw(nativeSuper, measuredRaw, raw));
    SPSetLongLong(parameters, @selector(setSpeedAverage:), SPScaledRaw(nativeAverage, measuredRaw, raw));
}

static void SPMutateLatency(id parameters) {
    NSNumber *ping = [SPState.shared runNumberForKey:@"ping"];
    NSNumber *jitter = [SPState.shared runNumberForKey:@"jitter"];
    if (ping) SPSetDouble(parameters, @selector(setPing:), ping.doubleValue);
    if (jitter) SPSetDouble(parameters, @selector(setJitter:), jitter.doubleValue);
}

static void SPMutateSavedModel(id model, NSDictionary *last) {
    if (!model) return;
    @try {
        if ([last[@"override_download"] boolValue]) SPSetKVCValue(model, @"download", @(SPRawFromMbps([last[@"download_mbps"] doubleValue])));
        if ([last[@"override_upload"] boolValue]) SPSetKVCValue(model, @"upload", @(SPRawFromMbps([last[@"upload_mbps"] doubleValue])));
        NSNumber *ping = [last[@"override_ping"] boolValue] ? last[@"ping_ms"] : nil;
        NSNumber *jitter = [last[@"override_jitter"] boolValue] ? last[@"jitter_ms"] : nil;
        if (ping) {
            SPSetKVCValue(model, @"latency", ping);
            SPSetKVCValue(model, @"idleIqmLatency", ping);
        }
        if (jitter) {
            SPSetKVCValue(model, @"jitter", jitter);
            SPSetKVCValue(model, @"downloadJitter", jitter);
            SPSetKVCValue(model, @"uploadJitter", jitter);
        }
        NSString *isp = [last[@"override_isp"] boolValue] ? last[@"isp"] : nil;
        NSString *provider = [last[@"override_server_provider"] boolValue] ? last[@"server_provider"] : nil;
        NSString *location = [last[@"override_server_location"] boolValue] ? last[@"server_location"] : nil;
        SPSetKVCValue(model, @"isp", isp);
        SPSetKVCValue(model, @"serverSponsor", provider);
        SPSetKVCValue(model, @"serverName", location);

        NSNumber *loss = [last[@"override_packet_loss"] boolValue] ? last[@"packet_loss"] : nil;
        if (loss) {
            NSInteger sent = loss.doubleValue >= 100.0 ? 10000 : 1000;
            NSInteger received = loss.doubleValue >= 100.0 ? 1 : 1000 - (NSInteger)llround(loss.doubleValue * 10.0);
            SPSetKVCValue(model, @"packetsSent", @(sent));
            SPSetKVCValue(model, @"packetsReceived", @(received));
        }
        id graphSamples = SPGraphSamplesForResult(model, last);
        if (graphSamples) SPSetKVCValue(model, @"graphSamples", graphSamples);
    } @catch (__unused NSException *exception) {}
}

static void (*OrigSpeedViewDidLoad)(id, SEL);
static void HookSpeedViewDidLoad(id self, SEL _cmd) {
    OrigSpeedViewDidLoad(self, _cmd);
    UIViewController *controller = self;
    SPAttachControls(controller);
    SPRetryProviderControls(controller);
    SPApplyThemeToController(controller);
    UIView *ad = SPObject(self, NSSelectorFromString(@"rectangleAdView"));
    ad.hidden = YES;
    [[SPUpdater shared] checkSilentlyFromViewController:controller];
}

static void (*OrigSpeedViewDidAppear)(id, SEL, BOOL);
static void HookSpeedViewDidAppear(id self, SEL _cmd, BOOL animated) {
    OrigSpeedViewDidAppear(self, _cmd, animated);
    UIViewController *controller = self;
    // Provider controls can be assembled lazily after viewDidLoad. Retry once
    // after the screen is on-window so the ISP-row button remains available
    // even when the private host setter is not observed on this app build.
    SPRetryProviderControls(controller);
    if (!SPState.shared.introSeen) SPQueueIntroGuideAttempt(controller, 0);
    SPHideOfficialUpdateBanner(self);
}

static void (*OrigSpeedViewDidLayoutSubviews)(id, SEL);
static void HookSpeedViewDidLayoutSubviews(id self, SEL _cmd) {
    OrigSpeedViewDidLayoutSubviews(self, _cmd);
    SPAttachProviderControlsAfterLayout((UIViewController *)self);
}

static void (*OrigSpeedViewWillAppear)(id, SEL, BOOL);
static void HookSpeedViewWillAppear(id self, SEL _cmd, BOOL animated) {
    OrigSpeedViewWillAppear(self, _cmd, animated);
    SPApplyIdentityLabels(self);
    SPHideOfficialUpdateBanner(self);
    SPRefreshBadge(self);
    SPApplyThemeToController(self);
}

static void (*OrigSuiteStagePrepared)(id, SEL, unsigned char);
static void HookSuiteStagePrepared(id self, SEL _cmd, unsigned char stage) {
    if (stage == SPStageLatency && !SPState.shared.testActive) [SPState.shared beginTest];
    [SPState.shared setStage:stage];
    SPApplyDataSaverToObject(self);
    OrigSuiteStagePrepared(self, _cmd, stage);
    if (stage == SPStageDownload || stage == SPStageUpload) {
        SPDirection direction = stage == SPStageDownload ? SPDirectionDownload : SPDirectionUpload;
        SPScheduleLiveLabelFallback(self, direction);
    }
}

static void (*OrigHandleProgress)(id, SEL, id);
static void HookHandleProgress(id self, SEL _cmd, id parameters) {
    SPMutateTransferProgress(parameters);
    SPMutateLatency(parameters);
    OrigHandleProgress(self, _cmd, parameters);
}

static void (*OrigHandleLoadedLatency)(id, SEL, id);
static void HookHandleLoadedLatency(id self, SEL _cmd, id parameters) { SPMutateLatency(parameters); OrigHandleLoadedLatency(self, _cmd, parameters); }

static void (*OrigHandleCompletion)(id, SEL, id);
static void HookHandleCompletion(id self, SEL _cmd, id result) {
    SPMutateTransferCompletion(result);
    SPMutateLatency(result);
    OrigHandleCompletion(self, _cmd, result);
    SPApplyRunIdentityLabels(self);
}

static void (*OrigSuiteComplete)(id, SEL);
static void SPCaptureCompletedTest(id self) {
    double download = SPNumberFromLabel(SPDisplayLabel(self, @"downloadResult"));
    double upload = SPNumberFromLabel(SPDisplayLabel(self, @"uploadResult"));
    NSNumber *ping = SPNumberObjectFromLabel(SPDisplayLabel(self, @"pingResult"));
    NSNumber *jitter = SPNumberObjectFromLabel(SPDisplayLabel(self, @"jitterResult"));
    [SPState.shared completeTestWithMeasuredDownload:download
                                              upload:upload
                                                ping:ping
                                              jitter:jitter
                                          packetLoss:nil
                                                 isp:SPLabel(self, @"endOfTestISPLabel").text
                                      serverProvider:SPLabel(self, @"endOfTestServerNameLabel").text
                                      serverLocation:SPLabel(self, @"endOfTestServerLocationLabel").text];
}

static void HookSuiteComplete(id self, SEL _cmd) {
    SPCaptureCompletedTest(self);
    OrigSuiteComplete(self, _cmd);
    NSDictionary *last = SPState.shared.lastResult;
    if ([last[@"override_download"] boolValue]) SPDisplayLabel(self, @"downloadResult").text = SPFormatMbps([last[@"download_mbps"] doubleValue]);
    if ([last[@"override_upload"] boolValue]) SPDisplayLabel(self, @"uploadResult").text = SPFormatMbps([last[@"upload_mbps"] doubleValue]);
    if ([last[@"override_ping"] boolValue]) SPDisplayLabel(self, @"pingResult").text = [last[@"ping_ms"] stringValue];
    if ([last[@"override_jitter"] boolValue]) SPDisplayLabel(self, @"jitterResult").text = [last[@"jitter_ms"] stringValue];
    SPApplyLastResultIdentityLabels(self, last);
}

static void (*OrigGaugeBegin)(id, SEL, id, id);
static void HookGaugeBegin(id self, SEL _cmd, id sender, id event) {
    [SPState.shared beginTest];
    if ([SPState.shared runBoolForKey:@"offline_mode"]) {
        SPStartOfflineDemo(self);
        return;
    }
    SPApplyDataSaverToObject(self);
    OrigGaugeBegin(self, _cmd, sender, event);
}

static void (*OrigSetAssemblyStackView)(id, SEL, id);
static void HookSetAssemblyStackView(id self, SEL _cmd, id stack) {
    OrigSetAssemblyStackView(self, _cmd, stack);
    dispatch_async(dispatch_get_main_queue(), ^{ SPAttachProviderControls(self, stack); });
}

static void (*OrigSetIspView)(id, SEL, id);
static void HookSetIspView(id self, SEL _cmd, id view) {
    OrigSetIspView(self, _cmd, view);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStackView *stack = SPObject(self, NSSelectorFromString(@"assemblyStackView"));
        SPAttachProviderControls(self, [stack isKindOfClass:UIStackView.class] ? stack : nil);
    });
}

static void (*OrigSetIspNameLabel)(id, SEL, id);
static void HookSetIspNameLabel(id self, SEL _cmd, id label) {
    OrigSetIspNameLabel(self, _cmd, label);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStackView *stack = SPObject(self, NSSelectorFromString(@"assemblyStackView"));
        SPAttachProviderControls(self, [stack isKindOfClass:UIStackView.class] ? stack : nil);
    });
}

// The provider host is assembled in pieces on recent iOS builds.  The ISP
// view/label setters are not guaranteed to run in a fixed order, and the
// visible row can be replaced after a server selection.  Rebind after every
// provider-only setter so the Speedtest+ entry point follows the current row
// without touching the native server-selection button.
static void (*OrigSetHostView)(id, SEL, id);
static void HookSetHostView(id self, SEL _cmd, id view) {
    OrigSetHostView(self, _cmd, view);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStackView *stack = SPObject(self, NSSelectorFromString(@"assemblyStackView"));
        SPAttachProviderControls(self, [stack isKindOfClass:UIStackView.class] ? stack : nil);
    });
}

static void (*OrigSetHostNameLabel)(id, SEL, id);
static void HookSetHostNameLabel(id self, SEL _cmd, id label) {
    OrigSetHostNameLabel(self, _cmd, label);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStackView *stack = SPObject(self, NSSelectorFromString(@"assemblyStackView"));
        SPAttachProviderControls(self, [stack isKindOfClass:UIStackView.class] ? stack : nil);
    });
}

static void (*OrigSetHostLocationLabel)(id, SEL, id);
static void HookSetHostLocationLabel(id self, SEL _cmd, id label) {
    OrigSetHostLocationLabel(self, _cmd, label);
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStackView *stack = SPObject(self, NSSelectorFromString(@"assemblyStackView"));
        SPAttachProviderControls(self, [stack isKindOfClass:UIStackView.class] ? stack : nil);
    });
}

static BOOL (*OrigCanShowAd)(id, SEL, id);
static BOOL HookCanShowAd(id self, SEL _cmd, id view) { return NO; }

static void (*OrigGenericViewDidLoad)(id, SEL);
static void HookResultDetailsViewDidLoad(id self, SEL _cmd) {
    OrigGenericViewDidLoad(self, _cmd);
    SPApplyThemeToController(self);
}

static void (*OrigResultDetailsShare)(id, SEL, id);
static void HookResultDetailsShare(id self, SEL _cmd, id sender) {
    id model = nil;
    @try { model = [self valueForKey:@"result"]; } @catch (__unused NSException *exception) {}
    NSDictionary *result = SPResultDictionaryFromModel(model);
    if (!result.count) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[SPShareBuilder plainTextFromResult:result]] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = [sender isKindOfClass:UIView.class] ? sender : ((UIViewController *)self).view;
    activity.popoverPresentationController.sourceRect = [sender isKindOfClass:UIView.class] ? ((UIView *)sender).bounds : ((UIViewController *)self).view.bounds;
    [(UIViewController *)self presentViewController:activity animated:YES completion:nil];
}

static void (*OrigResultListViewWillAppear)(id, SEL, BOOL);
static void HookResultListViewWillAppear(id self, SEL _cmd, BOOL animated) {
    OrigResultListViewWillAppear(self, _cmd, animated);
    NSDictionary *result = SPState.shared.lastResult;
    double customMaximum = MAX([result[@"download_mbps"] doubleValue], [result[@"upload_mbps"] doubleValue]) * 1.10;
    if (customMaximum > 0.0) SPExpandChartAxesInView(((UIViewController *)self).view, customMaximum);
    SPApplyThemeToController(self);
}

static void (*OrigFeedbackViewDidLoad)(id, SEL);
static void HookFeedbackViewDidLoad(id self, SEL _cmd) {
    OrigFeedbackViewDidLoad(self, _cmd);
    NSString *isp = SPState.shared.active ? [SPState.shared stringForKey:@"isp"] : nil;
    UILabel *title = SPLabel(self, @"titleLabel");
    if (isp.length && title) title.text = [NSString stringWithFormat:@"How would you rate %@?", isp];
    SPApplyThemeToController(self);
}

static void SPRewriteSurveyLabels(UIView *view) {
    NSString *isp = [SPState.shared stringForKey:@"isp"];
    if (SPState.shared.active && isp.length && [view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        NSString *lower = label.text.lowercaseString;
        if ([lower containsString:@"expect"]) label.text = [NSString stringWithFormat:@"How does %@ compare with your expectations?", isp];
        else if ([lower containsString:@"how would you rate"]) label.text = [NSString stringWithFormat:@"How would you rate %@?", isp];
    }
    for (UIView *child in view.subviews) SPRewriteSurveyLabels(child);
}

static void (*OrigCardsWillDisplayCell)(id, SEL, id, id, id);
static void HookCardsWillDisplayCell(id self, SEL _cmd, id collectionView, id cell, id indexPath) {
    OrigCardsWillDisplayCell(self, _cmd, collectionView, cell, indexPath);
    if ([cell isKindOfClass:UIView.class]) {
        SPRewriteSurveyLabels(cell);
        [SPTheme applyTheme:[SPTheme themeAtIndex:SPState.shared.themeIndex] toView:cell];
        __weak UIView *weakCell = cell;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (weakCell) SPRewriteSurveyLabels(weakCell); });
    }
}

static id (*OrigShareItem)(id, SEL);
static id HookShareItem(id self, SEL _cmd) {
    NSDictionary *result = SPState.shared.lastResult;
    return result.count ? [SPShareBuilder plainTextFromResult:result] : OrigShareItem(self, _cmd);
}

static id HookSuppressedURLItem(id self, SEL _cmd) { return @""; }
static id HookSuppressedURLActivityItem(id self, SEL _cmd, id controller, id activityType) { return nil; }

static id (*OrigCSVItem)(id, SEL, id, id);
static id HookCSVItem(id self, SEL _cmd, id controller, id activityType) {
    id original = OrigCSVItem(self, _cmd, controller, activityType);
    if (![original isKindOfClass:NSString.class]) return original;
    return [SPShareBuilder appendSpeedtestColumnsToCSV:original results:SPAllLocalResultDictionaries()];
}

static id SPRewriteCSVFile(id original) {
    if (![original isKindOfClass:NSURL.class] || ![(NSURL *)original isFileURL]) return original;
    NSString *csv = [NSString stringWithContentsOfURL:original encoding:NSUTF8StringEncoding error:nil];
    if (!csv.length) return original;
    NSString *rewritten = [SPShareBuilder appendSpeedtestColumnsToCSV:csv results:SPAllLocalResultDictionaries()];
    NSURL *directory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *output = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"SpeedtestPlus-%@.csv", NSUUID.UUID.UUIDString]];
    return [rewritten writeToURL:output atomically:YES encoding:NSUTF8StringEncoding error:nil] ? output : original;
}

static id (*OrigCSVFileItem)(id, SEL);
static id HookCSVFileItem(id self, SEL _cmd) { return SPRewriteCSVFile(OrigCSVFileItem(self, _cmd)); }
static id (*OrigCSVFileActivityItem)(id, SEL, id, id);
static id HookCSVFileActivityItem(id self, SEL _cmd, id controller, id activityType) {
    return SPRewriteCSVFile(OrigCSVFileActivityItem(self, _cmd, controller, activityType));
}

static void (*OrigSaveReportAsResult)(id, SEL, id);
static void HookSaveReportAsResult(id self, SEL _cmd, id report) {
    OrigSaveReportAsResult(self, _cmd, report);
    id localResult = SPKVCValue(report, @"speedTestResult");
    if (!localResult) localResult = SPObject(self, NSSelectorFromString(@"lastSavedResult"));
    if (!localResult) return;
    NSDictionary *pending = [SPState.shared consumePendingLocalResult];
    if (!pending) return;
    SPMutateSavedModel(localResult, pending);
    if (localResult && [self respondsToSelector:@selector(save)]) ((void (*)(id, SEL))objc_msgSend)(self, @selector(save));
}

static void SPHook(Class cls, NSString *selectorName, IMP replacement, IMP *original) {
    if (!cls) return;
    SEL selector = NSSelectorFromString(selectorName);
    if (!class_getInstanceMethod(cls, selector)) return;
    Method method = class_getInstanceMethod(cls, selector);
    if (original) *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
}

__attribute__((constructor)) static void SpeedtestPlusInitialize(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class speed = NSClassFromString(@"_TtC9SpeedTest23SpeedTestViewController");
        SPHook(speed, @"viewDidLoad", (IMP)HookSpeedViewDidLoad, (IMP *)&OrigSpeedViewDidLoad);
        SPHook(speed, @"viewWillAppear:", (IMP)HookSpeedViewWillAppear, (IMP *)&OrigSpeedViewWillAppear);
        SPHook(speed, @"viewDidAppear:", (IMP)HookSpeedViewDidAppear, (IMP *)&OrigSpeedViewDidAppear);
        SPHook(speed, @"viewDidLayoutSubviews", (IMP)HookSpeedViewDidLayoutSubviews, (IMP *)&OrigSpeedViewDidLayoutSubviews);
        SPHook(speed, @"suiteStagePrepared:", (IMP)HookSuiteStagePrepared, (IMP *)&OrigSuiteStagePrepared);
        SPHook(speed, @"handleProgress:", (IMP)HookHandleProgress, (IMP *)&OrigHandleProgress);
        SPHook(speed, @"handleLoadedLatencyProgress:", (IMP)HookHandleLoadedLatency, (IMP *)&OrigHandleLoadedLatency);
        SPHook(speed, @"handleCompletion:", (IMP)HookHandleCompletion, (IMP *)&OrigHandleCompletion);
        SPHook(speed, @"suiteComplete", (IMP)HookSuiteComplete, (IMP *)&OrigSuiteComplete);
        SPHook(speed, @"canShowAdForAdView:", (IMP)HookCanShowAd, (IMP *)&OrigCanShowAd);

        Class gauge = NSClassFromString(@"_TtC5Gauge22GaugeViewControlleriOS");
        SPHook(gauge, @"beginPressedWithSender:event:", (IMP)HookGaugeBegin, (IMP *)&OrigGaugeBegin);
        Class provider = NSClassFromString(@"_TtC5Gauge17ISPHostController");
        SPHook(provider, @"setAssemblyStackView:", (IMP)HookSetAssemblyStackView, (IMP *)&OrigSetAssemblyStackView);
        SPHook(provider, @"setIspView:", (IMP)HookSetIspView, (IMP *)&OrigSetIspView);
        SPHook(provider, @"setIspNameLabel:", (IMP)HookSetIspNameLabel, (IMP *)&OrigSetIspNameLabel);
        SPHook(provider, @"setHostView:", (IMP)HookSetHostView, (IMP *)&OrigSetHostView);
        SPHook(provider, @"setHostNameLabel:", (IMP)HookSetHostNameLabel, (IMP *)&OrigSetHostNameLabel);
        SPHook(provider, @"setHostLocationLabel:", (IMP)HookSetHostLocationLabel, (IMP *)&OrigSetHostLocationLabel);

        Class details = NSClassFromString(@"_TtC9SpeedTest27ResultDetailsViewController");
        SPHook(details, @"viewDidLoad", (IMP)HookResultDetailsViewDidLoad, (IMP *)&OrigGenericViewDidLoad);
        SPHook(details, @"shareResult:", (IMP)HookResultDetailsShare, (IMP *)&OrigResultDetailsShare);

        Class resultList = NSClassFromString(@"_TtC9SpeedTest24ResultListViewController");
        SPHook(resultList, @"viewWillAppear:", (IMP)HookResultListViewWillAppear, (IMP *)&OrigResultListViewWillAppear);

        Class feedback = NSClassFromString(@"_TtC9SpeedTest30PreparedFeedbackViewController");
        SPHook(feedback, @"viewDidLoad", (IMP)HookFeedbackViewDidLoad, (IMP *)&OrigFeedbackViewDidLoad);
        Class cards = NSClassFromString(@"_TtC9SpeedTest28SpeedtestCardsViewController");
        SPHook(cards, @"collectionView:willDisplayCell:forItemAtIndexPath:", (IMP)HookCardsWillDisplayCell, (IMP *)&OrigCardsWillDisplayCell);

        Class share = NSClassFromString(@"_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8023SharingTextActivityItem");
        SPHook(share, @"item", (IMP)HookShareItem, (IMP *)&OrigShareItem);
        Class urlShare = NSClassFromString(@"_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8022SharingURLActivityItem");
        SPHook(urlShare, @"item", (IMP)HookSuppressedURLItem, NULL);
        SPHook(urlShare, @"activityViewController:itemForActivityType:", (IMP)HookSuppressedURLActivityItem, NULL);
        Class csv = NSClassFromString(@"_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8033SharingResultsCSVTextActivityItem");
        SPHook(csv, @"activityViewController:itemForActivityType:", (IMP)HookCSVItem, (IMP *)&OrigCSVItem);
        Class csvFile = NSClassFromString(@"_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8033SharingResultsCSVFileActivityItem");
        SPHook(csvFile, @"item", (IMP)HookCSVFileItem, (IMP *)&OrigCSVFileItem);
        SPHook(csvFile, @"activityViewController:itemForActivityType:", (IMP)HookCSVFileActivityItem, (IMP *)&OrigCSVFileActivityItem);

        // CoreDataManager is the local history boundary. ResultSaver and the
        // network report builder are intentionally not hooked.
        Class coreData = NSClassFromString(@"CoreDataManager");
        SPHook(coreData, @"saveReportAsResult:", (IMP)HookSaveReportAsResult, (IMP *)&OrigSaveReportAsResult);
    });
}
