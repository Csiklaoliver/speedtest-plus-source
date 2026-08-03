#import "SPUpdater.h"
#import "SPState.h"

static NSString * const SPManifestURL = @"https://speedtest.oliverprojects.tech/api/ota/manifest";
static NSString * const SPCurrentVersion = @"0.1.3";

static UIViewController *SPUpdatePresenter(UIViewController *preferred) {
    UIViewController *controller = preferred;
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
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *presenter = SPUpdatePresenter(viewController);
            if (!presenter || presenter.presentedViewController) return;
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
    }];
    [task resume];
}

@end
