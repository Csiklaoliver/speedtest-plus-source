#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPShareBuilder : NSObject
+ (NSString *)plainTextFromResult:(NSDictionary<NSString *, id> *)result;
+ (NSString *)appendSpeedtestColumnsToCSV:(NSString *)csv results:(NSArray<NSDictionary<NSString *, id> *> *)results;
@end

NS_ASSUME_NONNULL_END
