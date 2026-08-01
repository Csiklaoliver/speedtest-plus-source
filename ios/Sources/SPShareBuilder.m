#import "SPShareBuilder.h"

@implementation SPShareBuilder

+ (NSString *)display:(id)value format:(NSString *)format {
    if (!value || value == NSNull.null) return @"-";
    if ([value isKindOfClass:NSNumber.class]) return [NSString stringWithFormat:format, [value doubleValue]];
    NSString *text = [value description];
    return text.length ? text : @"-";
}

+ (NSString *)plainTextFromResult:(NSDictionary<NSString *,id> *)result {
    return [NSString stringWithFormat:
        @"Speedtest+ Result\nDownload: %@ Mbps\nUpload: %@ Mbps\nPing: %@ ms\nJitter: %@ ms\nPacket loss: %@%%\nISP: %@\nServer: %@\nLocation: %@",
        [self display:result[@"download_mbps"] format:@"%.1f"],
        [self display:result[@"upload_mbps"] format:@"%.1f"],
        [self display:result[@"ping_ms"] format:@"%.0f"],
        [self display:result[@"jitter_ms"] format:@"%.0f"],
        [self display:result[@"packet_loss"] format:@"%.1f"],
        [self display:result[@"isp"] format:@"%@"],
        [self display:result[@"server_provider"] format:@"%@"],
        [self display:result[@"server_location"] format:@"%@"]];
}

+ (NSString *)escaped:(id)value {
    NSString *text = (!value || value == NSNull.null) ? @"" : [value description];
    return [NSString stringWithFormat:@"\"%@\"", [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

+ (NSString *)appendSpeedtestColumnsToCSV:(NSString *)csv results:(NSArray<NSDictionary<NSString *,id> *> *)results {
    if (!csv.length) return csv ?: @"";
    NSMutableArray<NSString *> *lines = [[csv componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] mutableCopy];
    if (!lines.count) return csv;
    lines[0] = [lines[0] stringByAppendingString:@",ISP,Server Provider,Jitter (ms),Packet Loss (%)"];
    for (NSInteger index = 1; index < (NSInteger)lines.count; index++) {
        if (!lines[index].length) continue;
        NSDictionary *result = index - 1 < (NSInteger)results.count ? results[index - 1] : @{};
        lines[index] = [lines[index] stringByAppendingFormat:@",%@,%@,%@,%@",
            [self escaped:result[@"isp"]], [self escaped:result[@"server_provider"]],
            [self escaped:result[@"jitter_ms"]], [self escaped:result[@"packet_loss"]]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

@end
