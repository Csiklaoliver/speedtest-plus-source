#import "SPDiagnostics.h"
#import "SPState.h"

static NSString *SPDiagnosticNumber(id value, NSString *suffix) {
    if (![value isKindOfClass:NSNumber.class]) return @"—";
    return [NSString stringWithFormat:@"%.1f%@", [value doubleValue], suffix ?: @""];
}

static NSString *SPDiagnosticInteger(id value, NSString *suffix) {
    if (![value isKindOfClass:NSNumber.class]) return @"—";
    return [NSString stringWithFormat:@"%ld%@", (long)[value integerValue], suffix ?: @""];
}

static NSString *SPDiagnosticPresence(NSDictionary<NSString *, id> *configuration, NSString *key) {
    id value = configuration[key];
    if ([value isKindOfClass:NSString.class]) return [(NSString *)value length] ? @"set" : @"blank";
    return value && value != NSNull.null ? @"set" : @"blank";
}

NSString *SPDiagnosticsText(SPState *state) {
    SPState *source = state ?: SPState.shared;
    NSDictionary<NSString *, id> *configuration = source.configuration ?: @{};
    NSDictionary<NSString *, id> *result = source.lastResult ?: @{};
    NSString *mode = source.testActive ? @"test running" : @"idle";
    if ([configuration[@"offline_mode"] boolValue]) mode = @"offline demo";
    else if ([configuration[@"data_saver_mode"] boolValue]) mode = @"data saver";
    NSString *os = NSProcessInfo.processInfo.operatingSystemVersionString ?: @"unknown";
    NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (![bundleVersion isKindOfClass:NSString.class] || !bundleVersion.length) bundleVersion = @"unknown";
    NSString *last = result.count ? [NSString stringWithFormat:
        @"Download: %@\nUpload: %@\nPing: %@\nJitter: %@\nPacket loss: %@",
        SPDiagnosticNumber(result[@"download_mbps"], @" Mbps"),
        SPDiagnosticNumber(result[@"upload_mbps"], @" Mbps"),
        SPDiagnosticInteger(result[@"ping_ms"], @" ms"),
        SPDiagnosticInteger(result[@"jitter_ms"], @" ms"),
        SPDiagnosticNumber(result[@"packet_loss"], @"%")]
        : @"No completed local result";
    return [NSString stringWithFormat:
        @"Speedtest+ Diagnostics\n"
         "Platform: iOS\n"
         "OS: %@\n"
         "App build: %@\n"
         "Mode: %@\n"
         "Theme index: %ld\n"
         "Active overrides: %ld\n"
         "Download override: %@\n"
         "Upload override: %@\n"
         "Ping override: %@\n"
         "Jitter override: %@\n"
         "Packet-loss override: %@\n"
         "ISP override: %@\n"
         "Server-provider override: %@\n"
         "Server-location override: %@\n\n"
         "Last local result\n%@\n\n"
         "Privacy: this snapshot contains no IP address, account, device ID, exact location, credentials, or identity text.",
        os, bundleVersion, mode, (long)source.themeIndex, (long)source.activeOverrideCount,
        SPDiagnosticPresence(configuration, @"download_min"),
        SPDiagnosticPresence(configuration, @"upload_min"),
        SPDiagnosticPresence(configuration, @"ping"),
        SPDiagnosticPresence(configuration, @"jitter"),
        SPDiagnosticPresence(configuration, @"packet_loss"),
        SPDiagnosticPresence(configuration, @"isp"),
        SPDiagnosticPresence(configuration, @"server_provider"),
        SPDiagnosticPresence(configuration, @"server_location"),
        last];
}
