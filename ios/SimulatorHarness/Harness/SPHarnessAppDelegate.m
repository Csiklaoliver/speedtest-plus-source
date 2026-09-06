#import "SPHarnessAppDelegate.h"
#import "SPHarnessViewController.h"

@implementation SPHarnessAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if ([NSProcessInfo.processInfo.environment[@"SPHARNESS_RESET_DEFAULTS"] boolValue]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"speedtest_plus_mod"];
    }
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    SPHarnessViewController *root = [SPHarnessViewController new];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
