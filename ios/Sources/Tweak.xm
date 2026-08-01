#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "SPState.h"
#import "SPTheme.h"
#import "SPControlsViewController.h"
#import "SPShareBuilder.h"
#import "SPUpdater.h"

// Confirmed from the 7.0.5 suiteStagePrepared switch:
// 1 = latency, 2 = download, 3 = upload.
static const NSInteger SPStageDownload = 2;
static const NSInteger SPStageUpload = 3;
static const NSInteger SPButtonTag = 0x53505031;
static const NSInteger SPBadgeTag = 0x53505032;

static id SPObject(id object, SEL selector);

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
        long long rawSpeed = (long long)llround([sample[@"speedMbps"] doubleValue] * 1000.0);
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
    id existing = SPObject(savedResult, NSSelectorFromString(@"graphSamples"));
    id download = SPObject(existing, NSSelectorFromString(@"download"));
    id upload = SPObject(existing, NSSelectorFromString(@"upload"));
    if ([SPState.shared hasSpeedOverrideForDirection:SPDirectionDownload]) download = SPGraphEntries(last[@"download_samples"]);
    if ([SPState.shared hasSpeedOverrideForDirection:SPDirectionUpload]) upload = SPGraphEntries(last[@"upload_samples"]);
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
    id downloadRaw = SPObject(model, NSSelectorFromString(@"download"));
    id uploadRaw = SPObject(model, NSSelectorFromString(@"upload"));
    id ping = SPObject(model, NSSelectorFromString(@"latency"));
    id jitter = SPObject(model, NSSelectorFromString(@"jitter"));
    id sent = SPObject(model, NSSelectorFromString(@"packetsSent"));
    id received = SPObject(model, NSSelectorFromString(@"packetsReceived"));
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
        @"isp": SPObject(model, NSSelectorFromString(@"isp")) ?: @"",
        @"server_provider": SPObject(model, NSSelectorFromString(@"serverSponsor")) ?: @"",
        @"server_location": SPObject(model, NSSelectorFromString(@"serverName")) ?: @"",
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

static double SPNumberFromLabel(UILabel *label) {
    if (!label.text.length) return 0.0;
    NSString *normalized = [[label.text stringByReplacingOccurrencesOfString:@"," withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSScanner *scanner = [NSScanner scannerWithString:normalized];
    double result = 0;
    return [scanner scanDouble:&result] ? result : 0.0;
}

static NSString *SPFormatMbps(double value) {
    return [NSString stringWithFormat:@"%.1f", value];
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

static void SPHideOfficialUpdateBanner(id controller) {
    UILabel *message = SPLabel(controller, @"userMessageLabel");
    NSString *text = message.text.lowercaseString;
    if ([text containsString:@"update available"] || [text containsString:@"new version"] || [text containsString:@"update speedtest"]) {
        message.hidden = YES;
    }
}

static UIViewController *SPPresenter(id object) {
    if ([object isKindOfClass:UIViewController.class]) return object;
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

static void SPPresentUnlock(UIViewController *presenter) {
    if (!SPState.shared.panelHidden) { [SPControlsViewController presentFrom:presenter]; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unlock Speedtest+" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Password"; field.secureTextEntry = YES; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Unlock" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if ([SPState.shared unlockWithPassword:alert.textFields.firstObject.text ?: @""]) [SPControlsViewController presentFrom:presenter];
        else {
            UIAlertController *failed = [UIAlertController alertControllerWithTitle:@"Speedtest+" message:@"Incorrect password." preferredStyle:UIAlertControllerStyleAlert];
            [failed addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [presenter presentViewController:failed animated:YES completion:nil];
        }
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@interface SPActionTarget : NSObject
@property(nonatomic, weak) UIViewController *presenter;
- (void)openControls;
- (void)openGuide;
- (void)longPressed:(UILongPressGestureRecognizer *)recognizer;
@end

@implementation SPActionTarget
- (void)openControls { SPPresentUnlock(self.presenter); }
- (void)openGuide { [SPControlsViewController presentGuideFrom:self.presenter allowOpenControls:YES]; }
- (void)longPressed:(UILongPressGestureRecognizer *)recognizer { if (recognizer.state == UIGestureRecognizerStateBegan) SPPresentUnlock(self.presenter); }
@end

static const void *SPActionTargetKey = &SPActionTargetKey;
static const void *SPOriginalLabelTextKey = &SPOriginalLabelTextKey;
static const void *SPPreviousLabelOverrideKey = &SPPreviousLabelOverrideKey;

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
    UIButton *button = [controller.view viewWithTag:SPButtonTag];
    UILabel *badge = [controller.view viewWithTag:SPBadgeTag];
    NSInteger count = SPState.shared.activeOverrideCount;
    button.hidden = SPState.shared.panelHidden;
    badge.hidden = count == 0 || SPState.shared.panelHidden;
    badge.text = [NSString stringWithFormat:@"CUSTOM • %ld", (long)count];
}

static void SPAttachControls(UIViewController *controller) {
    if ([controller.view viewWithTag:SPButtonTag]) { SPRefreshBadge(controller); return; }
    SPActionTarget *target = [SPActionTarget new];
    target.presenter = controller;
    objc_setAssociatedObject(controller, SPActionTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = SPButtonTag;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:@"S+  i" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    button.accessibilityLabel = @"Open Speedtest+ information and controls";
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.50];
    button.layer.cornerRadius = 12;
    [button addTarget:target action:@selector(openGuide) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:button];

    UILabel *badge = [UILabel new];
    badge.tag = SPBadgeTag;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.font = [UIFont boldSystemFontOfSize:10];
    badge.textColor = UIColor.whiteColor;
    badge.backgroundColor = [UIColor colorWithWhite:0 alpha:0.60];
    badge.layer.cornerRadius = 8;
    badge.layer.masksToBounds = YES;
    badge.textAlignment = NSTextAlignmentCenter;
    [controller.view addSubview:badge];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:@selector(longPressed:)];
    longPress.minimumPressDuration = 0.75;
    longPress.cancelsTouchesInView = NO;
    [controller.view addGestureRecognizer:longPress];

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [button.bottomAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.bottomAnchor constant:-70],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:48],
        [button.heightAnchor constraintEqualToConstant:48],
        [badge.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [badge.bottomAnchor constraintEqualToAnchor:button.topAnchor constant:-5],
        [badge.widthAnchor constraintGreaterThanOrEqualToConstant:68],
        [badge.heightAnchor constraintEqualToConstant:18]
    ]];
    [[NSNotificationCenter defaultCenter] addObserverForName:SPStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { SPRefreshBadge(controller); }];
    SPRefreshBadge(controller);
}

static void SPAttachProviderControls(id hostController, UIStackView *stack) {
    if (![stack isKindOfClass:UIStackView.class]) return;
    UIViewController *presenter = SPViewControllerForView(stack);
    if (!presenter) return;

    UIButton *existing = [presenter.view viewWithTag:SPButtonTag];
    UILabel *existingBadge = [presenter.view viewWithTag:SPBadgeTag];
    if (existing && existing.superview != stack) {
        [existing removeFromSuperview];
        [existingBadge removeFromSuperview];
        existing = nil;
    }
    if (existing) { SPRefreshBadge(presenter); return; }

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
    [button setTitle:@"S+  i" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    button.accessibilityLabel = @"Open Speedtest+ information and controls";
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    button.layer.cornerRadius = 12;
    button.clipsToBounds = NO;
    [button.widthAnchor constraintEqualToConstant:48].active = YES;
    [button.heightAnchor constraintEqualToConstant:48].active = YES;
    [button addTarget:target action:@selector(openGuide) forControlEvents:UIControlEventTouchUpInside];

    [button addSubview:badge];
    [NSLayoutConstraint activateConstraints:@[
        [badge.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [badge.bottomAnchor constraintEqualToAnchor:button.topAnchor constant:2]
    ]];
    [stack addArrangedSubview:button];
    UIView *providerView = SPObject(hostController, NSSelectorFromString(@"ispView"));
    if ([providerView isKindOfClass:UIView.class]) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:@selector(longPressed:)];
        gesture.minimumPressDuration = 0.75;
        gesture.cancelsTouchesInView = NO;
        [providerView addGestureRecognizer:gesture];
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:SPStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        SPRefreshBadge(presenter);
        SPApplyProviderLabels(hostController);
    }];
    SPApplyProviderLabels(hostController);
    SPRefreshBadge(presenter);
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
    if (!SPState.shared.active) return;
    NSInteger stage = [parameters respondsToSelector:@selector(stageType)] ? ((unsigned char (*)(id, SEL))objc_msgSend)(parameters, @selector(stageType)) : SPState.shared.stage;
    SPDirection direction;
    if (stage == SPStageDownload) direction = SPDirectionDownload;
    else if (stage == SPStageUpload) direction = SPDirectionUpload;
    else return;
    if (![SPState.shared hasSpeedOverrideForDirection:direction]) return;
    double progress = SPDouble(parameters, @selector(progress), 0.0);
    long long measuredRaw = SPLongLong(parameters, @selector(speed), 0);
    double measuredMbps = (double)measuredRaw / 1000.0;
    double shownMbps = [SPState.shared displayMbpsForDirection:direction measuredMbps:measuredMbps progress:progress];
    long long raw = (long long)llround(shownMbps * 1000.0);
    SPSetLongLong(parameters, @selector(setSpeed:), raw);
    SPSetLongLong(parameters, @selector(setSpeedMST:), raw);
    SPSetLongLong(parameters, @selector(setSpeedSuperSpeed:), raw);
    SPSetLongLong(parameters, @selector(setSpeedAverage:), raw);
    id packetLoss = SPPacketLossModel([SPState.shared numberForKey:@"packet_loss"]);
    if (packetLoss) SPSetObject(parameters, @selector(setPacketLoss:), packetLoss);
}

static void SPMutateTransferCompletion(id parameters) {
    if (!SPState.shared.active) return;
    NSInteger stage = [parameters respondsToSelector:@selector(stageType)] ? ((unsigned char (*)(id, SEL))objc_msgSend)(parameters, @selector(stageType)) : SPState.shared.stage;
    SPDirection direction;
    if (stage == SPStageDownload) direction = SPDirectionDownload;
    else if (stage == SPStageUpload) direction = SPDirectionUpload;
    else return;
    if (![SPState.shared hasSpeedOverrideForDirection:direction]) return;
    double measuredMbps = (double)SPLongLong(parameters, @selector(speed), 0) / 1000.0;
    long long raw = (long long)llround([SPState.shared finalMbpsForDirection:direction measuredMbps:measuredMbps] * 1000.0);
    SPSetLongLong(parameters, @selector(setSpeed:), raw);
    SPSetLongLong(parameters, @selector(setSpeedMST:), raw);
    SPSetLongLong(parameters, @selector(setSpeedSuperSpeed:), raw);
    SPSetLongLong(parameters, @selector(setSpeedAverage:), raw);
}

static void SPMutateLatency(id parameters) {
    if (!SPState.shared.active) return;
    NSNumber *ping = [SPState.shared numberForKey:@"ping"];
    NSNumber *jitter = [SPState.shared numberForKey:@"jitter"];
    if (ping) SPSetDouble(parameters, @selector(setPing:), ping.doubleValue);
    if (jitter) SPSetDouble(parameters, @selector(setJitter:), jitter.doubleValue);
}

static void SPMutateSavedModel(id model) {
    if (!SPState.shared.active || !model) return;
    NSDictionary *last = SPState.shared.lastResult;
    @try {
        if ([SPState.shared hasSpeedOverrideForDirection:SPDirectionDownload]) SPSetObject(model, NSSelectorFromString(@"setDownload:"), @(llround([last[@"download_mbps"] doubleValue] * 1000.0)));
        if ([SPState.shared hasSpeedOverrideForDirection:SPDirectionUpload]) SPSetObject(model, NSSelectorFromString(@"setUpload:"), @(llround([last[@"upload_mbps"] doubleValue] * 1000.0)));
        NSNumber *ping = [SPState.shared numberForKey:@"ping"];
        NSNumber *jitter = [SPState.shared numberForKey:@"jitter"];
        if (ping) {
            SPSetObject(model, NSSelectorFromString(@"setLatency:"), ping);
            SPSetObject(model, NSSelectorFromString(@"setIdleIqmLatency:"), ping);
        }
        if (jitter) {
            SPSetObject(model, NSSelectorFromString(@"setJitter:"), jitter);
            SPSetObject(model, NSSelectorFromString(@"setDownloadJitter:"), jitter);
            SPSetObject(model, NSSelectorFromString(@"setUploadJitter:"), jitter);
        }
        NSString *isp = [SPState.shared stringForKey:@"isp"];
        NSString *provider = [SPState.shared stringForKey:@"server_provider"];
        NSString *location = [SPState.shared stringForKey:@"server_location"];
        SPSetObject(model, NSSelectorFromString(@"setIsp:"), isp);
        SPSetObject(model, NSSelectorFromString(@"setServerSponsor:"), provider);
        SPSetObject(model, NSSelectorFromString(@"setServerName:"), location);

        NSNumber *loss = [SPState.shared numberForKey:@"packet_loss"];
        if (loss) {
            NSInteger sent = loss.doubleValue >= 100.0 ? 10000 : 1000;
            NSInteger received = loss.doubleValue >= 100.0 ? 1 : 1000 - (NSInteger)llround(loss.doubleValue * 10.0);
            SPSetObject(model, NSSelectorFromString(@"setPacketsSent:"), @(sent));
            SPSetObject(model, NSSelectorFromString(@"setPacketsReceived:"), @(received));
        }
        id graphSamples = SPGraphSamplesForResult(model, last);
        if (graphSamples) SPSetObject(model, NSSelectorFromString(@"setGraphSamples:"), graphSamples);
    } @catch (__unused NSException *exception) {}
}

static void (*OrigSpeedViewDidLoad)(id, SEL);
static void HookSpeedViewDidLoad(id self, SEL _cmd) {
    OrigSpeedViewDidLoad(self, _cmd);
    UIViewController *controller = self;
    SPAttachControls(controller);
    SPApplyThemeToController(controller);
    UIView *ad = SPObject(self, NSSelectorFromString(@"rectangleAdView"));
    ad.hidden = YES;
    [[SPUpdater shared] checkSilentlyFromViewController:controller];
}

static void (*OrigSpeedViewDidAppear)(id, SEL, BOOL);
static void HookSpeedViewDidAppear(id self, SEL _cmd, BOOL animated) {
    OrigSpeedViewDidAppear(self, _cmd, animated);
    UIViewController *controller = self;
    if (!SPState.shared.introSeen && !controller.presentedViewController) {
        [SPControlsViewController presentGuideFrom:controller allowOpenControls:YES];
    }
    SPHideOfficialUpdateBanner(self);
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
static void HookSuiteStagePrepared(id self, SEL _cmd, unsigned char stage) { [SPState.shared setStage:stage]; OrigSuiteStagePrepared(self, _cmd, stage); }

static void (*OrigHandleProgress)(id, SEL, id);
static void HookHandleProgress(id self, SEL _cmd, id parameters) { SPMutateTransferProgress(parameters); OrigHandleProgress(self, _cmd, parameters); }

static void (*OrigHandleLoadedLatency)(id, SEL, id);
static void HookHandleLoadedLatency(id self, SEL _cmd, id parameters) { SPMutateLatency(parameters); OrigHandleLoadedLatency(self, _cmd, parameters); }

static void (*OrigHandleCompletion)(id, SEL, id);
static void HookHandleCompletion(id self, SEL _cmd, id result) {
    SPMutateTransferCompletion(result);
    SPMutateLatency(result);
    OrigHandleCompletion(self, _cmd, result);
    SPApplyIdentityLabels(self);
}

static void (*OrigSuiteComplete)(id, SEL);
static void SPCaptureCompletedTest(id self) {
    double download = SPNumberFromLabel(SPDisplayLabel(self, @"downloadResult"));
    double upload = SPNumberFromLabel(SPDisplayLabel(self, @"uploadResult"));
    NSNumber *ping = @(SPNumberFromLabel(SPDisplayLabel(self, @"pingResult")));
    NSNumber *jitter = @(SPNumberFromLabel(SPDisplayLabel(self, @"jitterResult")));
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
    SPCaptureCompletedTest(self);
    NSDictionary *last = SPState.shared.lastResult;
    if ([SPState.shared hasSpeedOverrideForDirection:SPDirectionDownload]) SPDisplayLabel(self, @"downloadResult").text = SPFormatMbps([last[@"download_mbps"] doubleValue]);
    if ([SPState.shared hasSpeedOverrideForDirection:SPDirectionUpload]) SPDisplayLabel(self, @"uploadResult").text = SPFormatMbps([last[@"upload_mbps"] doubleValue]);
    if ([SPState.shared numberForKey:@"ping"]) SPDisplayLabel(self, @"pingResult").text = [[SPState.shared numberForKey:@"ping"] stringValue];
    if ([SPState.shared numberForKey:@"jitter"]) SPDisplayLabel(self, @"jitterResult").text = [[SPState.shared numberForKey:@"jitter"] stringValue];
    SPApplyIdentityLabels(self);
}

static void (*OrigGaugeBegin)(id, SEL, id, id);
static void HookGaugeBegin(id self, SEL _cmd, id sender, id event) { [SPState.shared beginTest]; OrigGaugeBegin(self, _cmd, sender, event); }

static void (*OrigSetAssemblyStackView)(id, SEL, id);
static void HookSetAssemblyStackView(id self, SEL _cmd, id stack) {
    OrigSetAssemblyStackView(self, _cmd, stack);
    dispatch_async(dispatch_get_main_queue(), ^{ SPAttachProviderControls(self, stack); });
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

static void (*OrigCompareViewWillAppear)(id, SEL, BOOL);
static void HookCompareViewWillAppear(id self, SEL _cmd, BOOL animated) {
    OrigCompareViewWillAppear(self, _cmd, animated);
    NSDictionary *result = SPState.shared.lastResult;
    if (result.count) {
        SPLabel(self, @"downloadValueLabel").text = [NSString stringWithFormat:@"%.1f", [result[@"download_mbps"] doubleValue]];
        SPLabel(self, @"uploadValueLabel").text = [NSString stringWithFormat:@"%.1f", [result[@"upload_mbps"] doubleValue]];
        if (result[@"ping_ms"] != NSNull.null) SPLabel(self, @"pingValueLabel").text = [NSString stringWithFormat:@"%.0f", [result[@"ping_ms"] doubleValue]];
        if ([result[@"server_provider"] length]) SPLabel(self, @"providerNameLabel").text = result[@"server_provider"];
        if ([result[@"server_location"] length]) SPLabel(self, @"cityLabel").text = result[@"server_location"];
    }
    double customMaximum = MAX([result[@"download_mbps"] doubleValue], [result[@"upload_mbps"] doubleValue]) * 1.10;
    if (customMaximum > 0.0) SPExpandChartAxesInView(((UIViewController *)self).view, customMaximum);
    SPApplyThemeToController(self);
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
    NSString *isp = [SPState.shared stringForKey:@"isp"];
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

static id (*OrigCSVItem)(id, SEL, id, id);
static id HookCSVItem(id self, SEL _cmd, id controller, id activityType) {
    id original = OrigCSVItem(self, _cmd, controller, activityType);
    if (![original isKindOfClass:NSString.class]) return original;
    return [SPShareBuilder appendSpeedtestColumnsToCSV:original results:SPAllLocalResultDictionaries()];
}

static void (*OrigSaveReportAsResult)(id, SEL, id);
static void HookSaveReportAsResult(id self, SEL _cmd, id report) {
    OrigSaveReportAsResult(self, _cmd, report);
    id localResult = SPObject(self, NSSelectorFromString(@"lastSavedResult"));
    SPMutateSavedModel(localResult);
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

        Class details = NSClassFromString(@"_TtC9SpeedTest27ResultDetailsViewController");
        SPHook(details, @"viewDidLoad", (IMP)HookResultDetailsViewDidLoad, (IMP *)&OrigGenericViewDidLoad);
        SPHook(details, @"shareResult:", (IMP)HookResultDetailsShare, (IMP *)&OrigResultDetailsShare);

        Class compare = NSClassFromString(@"_TtC9SpeedTest33CompareResultsOfferViewController");
        SPHook(compare, @"viewWillAppear:", (IMP)HookCompareViewWillAppear, (IMP *)&OrigCompareViewWillAppear);
        Class resultList = NSClassFromString(@"_TtC9SpeedTest24ResultListViewController");
        SPHook(resultList, @"viewWillAppear:", (IMP)HookResultListViewWillAppear, (IMP *)&OrigResultListViewWillAppear);

        Class feedback = NSClassFromString(@"_TtC9SpeedTest30PreparedFeedbackViewController");
        SPHook(feedback, @"viewDidLoad", (IMP)HookFeedbackViewDidLoad, (IMP *)&OrigFeedbackViewDidLoad);
        Class cards = NSClassFromString(@"_TtC9SpeedTest28SpeedtestCardsViewController");
        SPHook(cards, @"collectionView:willDisplayCell:forItemAtIndexPath:", (IMP)HookCardsWillDisplayCell, (IMP *)&OrigCardsWillDisplayCell);

        Class share = NSClassFromString(@"_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8023SharingTextActivityItem");
        SPHook(share, @"item", (IMP)HookShareItem, (IMP *)&OrigShareItem);
        Class csv = NSClassFromString(@"_TtC9SpeedTestP33_A9A507B3669C583A38FE6357D8AFFD8033SharingResultsCSVTextActivityItem");
        SPHook(csv, @"activityViewController:itemForActivityType:", (IMP)HookCSVItem, (IMP *)&OrigCSVItem);

        // CoreDataManager is the local history boundary. ResultSaver and the
        // network report builder are intentionally not hooked.
        Class coreData = NSClassFromString(@"CoreDataManager");
        SPHook(coreData, @"saveReportAsResult:", (IMP)HookSaveReportAsResult, (IMP *)&OrigSaveReportAsResult);
    });
}
