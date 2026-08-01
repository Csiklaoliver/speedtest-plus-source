#import "SPUpdater.h"
#import "SPState.h"

static NSString * const SPManifestURL = @"https://speedtest.oliverprojects.tech/api/ota/manifest";
static NSString * const SPCurrentVersion = @"0.1.0";

@implementation SPUpdater

+ (instancetype)shared { static SPUpdater *value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }

- (void)checkSilentlyFromViewController:(UIViewController *)viewController {
    if (![SPState shared].updateChecksEnabled) return;
    NSURL *url = [NSURL URLWithString:SPManifestURL];
    if (!url) return;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        if (!data || error || http.statusCode != 200 || data.length > 256 * 1024) return;
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSDictionary *ios = [root[@"ios"] isKindOfClass:NSDictionary.class] ? root[@"ios"] : nil;
        NSString *version = [ios[@"version"] isKindOfClass:NSString.class] ? ios[@"version"] : nil;
        NSString *download = [ios[@"download_url"] isKindOfClass:NSString.class] ? ios[@"download_url"] : nil;
        if (!version.length || !download.length) return;
        if ([SPCurrentVersion compare:version options:NSNumericSearch] != NSOrderedAscending) return;
        if ([SPState.shared.lastPromptedUpdateVersion isEqualToString:version]) return;
        NSURL *downloadURL = [NSURL URLWithString:download];
        if (![downloadURL.scheme.lowercaseString isEqualToString:@"https"] || !downloadURL.host.length) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *presenter = viewController ?: UIApplication.sharedApplication.keyWindow.rootViewController;
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
