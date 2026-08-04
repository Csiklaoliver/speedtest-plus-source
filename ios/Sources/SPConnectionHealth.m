#import "SPConnectionHealth.h"

// Use the same public manifest that the release documentation publishes.  The
// custom domain may serve the website/API but is not the canonical OTA path;
// probing it made a healthy connection look like an HTTP 404 failure.
static NSString * const SPConnectionHealthURLString = @"https://raw.githubusercontent.com/Csiklaoliver/speedtest-plus-docs/main/ota/manifest.json";

static BOOL SPNativeServerListReady = NO;

static NSString *SPServerListReadiness(void) {
    @synchronized (SPConnectionHealth.class) {
        return SPNativeServerListReady ? @"Native provider row ready" : @"Not observed yet";
    }
}

static NSString *SPFailureSummary(NSError *error) {
    switch (error.code) {
        case NSURLErrorCannotFindHost:
        case NSURLErrorDNSLookupFailed:
            return @"DNS lookup failed";
        case NSURLErrorSecureConnectionFailed:
        case NSURLErrorServerCertificateUntrusted:
        case NSURLErrorClientCertificateRejected:
        case NSURLErrorServerCertificateHasBadDate:
        case NSURLErrorServerCertificateHasUnknownRoot:
            return @"TLS handshake failed";
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorTimedOut:
        case NSURLErrorCannotConnectToHost:
            return @"Internet unavailable";
        default:
            return @"Network check failed";
    }
}

static NSString *SPHTTPTransportSummary(NSInteger statusCode) {
    if (statusCode >= 200 && statusCode <= 399) {
        return [NSString stringWithFormat:@"Passed (HTTP %ld)", (long)statusCode];
    }
    if (statusCode >= 400 && statusCode <= 599) {
        // A response proves DNS, TLS, and the network path worked, but the
        // request itself was rejected.  Do not label a 404/405 as "Passed".
        return [NSString stringWithFormat:@"Server reachable; request rejected (HTTP %ld)", (long)statusCode];
    }
    return @"Network check failed";
}

static NSString *SPSummary(NSString *transport, NSString *readiness) {
    return [NSString stringWithFormat:
        @"Connection Health\n"
         "Internet/DNS/TLS: %@\n"
         "Server-list readiness: %@\n"
         "No speed test was started.", transport, readiness];
}

static void SPComplete(void (^completion)(NSString *summary), NSString *summary) {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{ completion(summary); });
}

@implementation SPConnectionHealth

+ (void)noteNativeServerListReady:(BOOL)ready {
    @synchronized (self) {
        SPNativeServerListReady = ready;
    }
}

+ (void)runWithOfflineMode:(BOOL)offline completion:(void (^)(NSString *summary))completion {
    if (!completion) return;
    NSString *readiness = SPServerListReadiness();
    if (offline) {
        SPComplete(completion, SPSummary(@"Not checked (offline mode)", @"Not applicable"));
        return;
    }

    NSURL *url = [NSURL URLWithString:SPConnectionHealthURLString];
    if (!url) {
        SPComplete(completion, SPSummary(@"Network check failed", readiness));
        return;
    }

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 4.0;
    configuration.timeoutIntervalForResource = 5.0;
    configuration.HTTPShouldSetCookies = NO;
    configuration.URLCache = nil;
    configuration.HTTPCookieStorage = nil;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 4.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)data;
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSString *transport;
        if (error) {
            transport = SPFailureSummary(error);
        } else if (http) {
            transport = SPHTTPTransportSummary(http.statusCode);
        } else {
            transport = @"Network check failed";
        }
        SPComplete(completion, SPSummary(transport, SPServerListReadiness()));
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}

@end
