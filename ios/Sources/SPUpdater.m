#import "SPUpdater.h"
#import "SPState.h"

static NSString * const SPManifestURL = @"https://speedtest.oliverprojects.tech/api/ota/manifest";
// Keep this in sync with the IPA's CFBundleShortVersionString.  A stale
// value here makes every current install report its own release as an update.
static NSString * const SPCurrentVersion = @"0.1.15";

static BOOL SPIsNativeSetupController(UIViewController *controller) {
    if (!controller) return NO;
    NSString *name = NSStringFromClass(controller.class).lowercaseString;
    for (NSString *token in @[@"onboarding", @"educational", @"setup", @"privacy", @"consent", @"welcome", @"intro", @"permission"]) {
        if ([name containsString:token]) return YES;
    }
    return NO;
}

// Update alerts must never be placed above the stock onboarding/privacy
// controller.  In particular, presenting an alert while that controller's
// Continue action is visible can swallow the touch and leave setup looking
// frozen.  Treat every non-dismissing modal as a blocking presentation; this
// also avoids interrupting a user's unrelated native dialog.
static BOOL SPHasBlockingPresentation(UIViewController *controller) {
    // Check the exact controller first.  A setup sheet can be presented by a
    // child inside a navigation controller without appearing as the
    // navigation controller's own `presentedViewController`.
    for (UIViewController *direct = controller; direct; direct = direct.presentingViewController) {
        if ((direct.presentedViewController && !direct.presentedViewController.isBeingDismissed) ||
            SPIsNativeSetupController(direct) || [direct isKindOfClass:UIAlertController.class]) return YES;
    }
    UIViewController *cursor = controller.navigationController ?: controller.tabBarController ?: controller;
    while (cursor.presentingViewController && !cursor.presentingViewController.isBeingDismissed) {
        cursor = cursor.presentingViewController;
    }
    while (cursor) {
        UIViewController *presented = cursor.presentedViewController;
        if (presented && !presented.isBeingDismissed) return YES;
        if (SPIsNativeSetupController(cursor)) return YES;
        if ([cursor isKindOfClass:UIAlertController.class]) return YES;
        if ([cursor isKindOfClass:UINavigationController.class]) cursor = ((UINavigationController *)cursor).visibleViewController;
        else if ([cursor isKindOfClass:UITabBarController.class]) cursor = ((UITabBarController *)cursor).selectedViewController;
        else break;
    }
    return NO;
}

static UIViewController *SPUpdatePresenter(UIViewController *preferred) {
    UIViewController *controller = preferred;
    if ([controller isKindOfClass:UIViewController.class]) {
        controller = controller.navigationController ?: controller.tabBarController ?: controller;
        while (controller.presentingViewController && !controller.presentingViewController.isBeingDismissed) {
            controller = controller.presentingViewController;
        }
    }
    if (!controller) {
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) { window = candidate; break; }
                if (window) break;
            }
        }
        if (!window) for (UIWindow *candidate in UIApplication.sharedApplication.windows) if (candidate.isKeyWindow) { window = candidate; break; }
        controller = window.rootViewController;
    }
    while (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) controller = controller.presentedViewController;
    if ([controller isKindOfClass:UINavigationController.class]) controller = ((UINavigationController *)controller).visibleViewController;
    if ([controller isKindOfClass:UITabBarController.class]) controller = ((UITabBarController *)controller).selectedViewController;
    return controller;
}

static void SPShowUpdateWhenReady(NSString *version, NSURL *downloadURL, UIViewController *preferred, NSInteger attempt) {
    if (!version.length || !downloadURL || attempt > 20) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *base = preferred ?: SPUpdatePresenter(nil);
        UIViewController *presenter = SPUpdatePresenter(base);
        if (!presenter || SPHasBlockingPresentation(base) || SPHasBlockingPresentation(presenter)) {
            // Native setup is intentionally allowed to finish first.  Retry
            // for a bounded period so a slow first launch does not lose the
            // notification permanently, without creating an endless timer.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SPShowUpdateWhenReady(version, downloadURL, preferred, attempt + 1);
            });
            return;
        }
        // A modal that is already being dismissed is still attached for a
        // short UIKit transition.  Retry instead of dropping the update or
        // attempting a presentation into that transition.
        if (presenter.presentedViewController) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SPShowUpdateWhenReady(version, downloadURL, preferred, attempt + 1);
            });
            return;
        }
        if ([SPState.shared.lastPromptedUpdateVersion isEqualToString:version]) return;
        [SPState.shared setLastPromptedUpdateVersion:version];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Speedtest+ update available"
            message:[NSString stringWithFormat:@"Version %@ is ready. iOS updates open the signed download page.", version]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Open download" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [UIApplication.sharedApplication openURL:downloadURL options:@{} completionHandler:nil];
        }]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

@implementation SPUpdater

+ (instancetype)shared { static SPUpdater *value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }

- (void)checkSilentlyFromViewController:(UIViewController *)viewController {
    if (![SPState shared].updateChecksEnabled) return;
    NSURL *url = [NSURL URLWithString:SPManifestURL];
    if (!url) return;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        if (!data || error || http.statusCode != 200 || data.length > 256 * 1024) return;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:NSDictionary.class]) return;
        NSDictionary *root = json;
        NSDictionary *ios = [root[@"ios"] isKindOfClass:NSDictionary.class] ? root[@"ios"] : nil;
        NSString *version = [ios[@"version"] isKindOfClass:NSString.class] ? ios[@"version"] : nil;
        NSString *download = [ios[@"download_url"] isKindOfClass:NSString.class] ? ios[@"download_url"] : nil;
        NSString *sha256 = [ios[@"sha256"] isKindOfClass:NSString.class] ? [ios[@"sha256"] lowercaseString] : nil;
        NSNumber *size = [ios[@"size_bytes"] isKindOfClass:NSNumber.class] ? ios[@"size_bytes"] : nil;
        NSCharacterSet *nonHex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet;
        if (!version.length || !download.length || sha256.length != 64 || [sha256 rangeOfCharacterFromSet:nonHex].location != NSNotFound || size.longLongValue <= 0) return;
        if ([SPCurrentVersion compare:version options:NSNumericSearch] != NSOrderedAscending) return;
        if ([SPState.shared.lastPromptedUpdateVersion isEqualToString:version]) return;
        NSURL *downloadURL = [NSURL URLWithString:download];
        if (![downloadURL.scheme.lowercaseString isEqualToString:@"https"] || !downloadURL.host.length) return;
        SPShowUpdateWhenReady(version, downloadURL, viewController, 0);
    }];
    [task resume];
}

@end
