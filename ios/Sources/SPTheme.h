#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPTheme : NSObject
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) UIColor *background;
@property(nonatomic, readonly) UIColor *surface;
@property(nonatomic, readonly) UIColor *primary;
@property(nonatomic, readonly) UIColor *muted;
@property(nonatomic, readonly) UIColor *downloadStart;
@property(nonatomic, readonly) UIColor *downloadEnd;
@property(nonatomic, readonly) UIColor *uploadStart;
@property(nonatomic, readonly) UIColor *uploadEnd;
@property(nonatomic, readonly) UIColor *divider;
+ (NSArray<SPTheme *> *)allThemes;
+ (SPTheme *)themeAtIndex:(NSInteger)index;
+ (void)applyTheme:(SPTheme *)theme toView:(UIView *)view;
@end

NS_ASSUME_NONNULL_END

