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
// Uses Liquid Glass when the running OS exposes it, while retaining a
// reduced-transparency/older-iOS fallback.  This is intentionally for the
// custom controls surface, not the native gauge/content layer.
+ (void)applyFunctionalMaterialToView:(UIView *)view theme:(SPTheme *)theme;
@end

NS_ASSUME_NONNULL_END
