#import "SPTheme.h"

static UIColor *SPColor(uint32_t rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0
                           green:((rgb >> 8) & 0xff) / 255.0
                            blue:(rgb & 0xff) / 255.0 alpha:1.0];
}

@interface SPTheme ()
@property(nonatomic) NSString *name;
@property(nonatomic) UIColor *background;
@property(nonatomic) UIColor *surface;
@property(nonatomic) UIColor *primary;
@property(nonatomic) UIColor *muted;
@property(nonatomic) UIColor *downloadStart;
@property(nonatomic) UIColor *downloadEnd;
@property(nonatomic) UIColor *uploadStart;
@property(nonatomic) UIColor *uploadEnd;
@property(nonatomic) UIColor *divider;
@end

@implementation SPTheme

+ (instancetype)named:(NSString *)name background:(uint32_t)background surface:(uint32_t)surface
          downloadFrom:(uint32_t)downloadFrom downloadTo:(uint32_t)downloadTo
            uploadFrom:(uint32_t)uploadFrom uploadTo:(uint32_t)uploadTo {
    SPTheme *theme = [SPTheme new];
    theme.name = name;
    theme.background = SPColor(background);
    theme.surface = SPColor(surface);
    theme.primary = UIColor.whiteColor;
    theme.muted = SPColor(0xA6A7B8);
    theme.downloadStart = SPColor(downloadFrom);
    theme.downloadEnd = SPColor(downloadTo);
    theme.uploadStart = SPColor(uploadFrom);
    theme.uploadEnd = SPColor(uploadTo);
    theme.divider = [UIColor colorWithWhite:1.0 alpha:0.20];
    return theme;
}

+ (NSArray<SPTheme *> *)allThemes {
    static NSArray<SPTheme *> *themes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        themes = @[
            [self named:@"Classic Cyan" background:0x0B0C1B surface:0x1A1B2E downloadFrom:0x01A3E5 downloadTo:0x19BF78 uploadFrom:0x6B3295 uploadTo:0xE97BCE],
            [self named:@"AMOLED High Contrast" background:0x000000 surface:0x151515 downloadFrom:0x00E5FF downloadTo:0x00FFC6 uploadFrom:0xFFD600 uploadTo:0xFF8A00],
            [self named:@"Midnight Violet" background:0x0D0A18 surface:0x1A142B downloadFrom:0xA78BFA downloadTo:0x60A5FA uploadFrom:0xF472B6 uploadTo:0xC084FC],
            [self named:@"Emerald" background:0x06130F surface:0x10231C downloadFrom:0x34D399 downloadTo:0x22D3EE uploadFrom:0x60A5FA uploadTo:0xA78BFA],
            [self named:@"Sunset" background:0x160B10 surface:0x26131B downloadFrom:0xFB7185 downloadTo:0xF59E0B uploadFrom:0xF59E0B uploadTo:0xFDE047],
            [self named:@"Arctic" background:0x07131E surface:0x102638 downloadFrom:0x7DD3FC downloadTo:0x67E8F9 uploadFrom:0x93C5FD uploadTo:0xC4B5FD],
            [self named:@"Rose Neon" background:0x160810 surface:0x2B1020 downloadFrom:0xFB7185 downloadTo:0xF0ABFC uploadFrom:0xC084FC uploadTo:0x818CF8],
            [self named:@"Copper" background:0x130D08 surface:0x291B12 downloadFrom:0xFDBA74 downloadTo:0xF97316 uploadFrom:0xFDE68A uploadTo:0xD97706],
            [self named:@"Deep Ocean" background:0x020B17 surface:0x071B31 downloadFrom:0x38BDF8 downloadTo:0x2DD4BF uploadFrom:0x818CF8 uploadTo:0x22D3EE],
            [self named:@"Monochrome" background:0x090909 surface:0x202020 downloadFrom:0xFAFAFA downloadTo:0xA3A3A3 uploadFrom:0xD4D4D4 uploadTo:0x737373]
        ];
    });
    return themes;
}

+ (SPTheme *)themeAtIndex:(NSInteger)index {
    NSArray *themes = [self allThemes];
    return themes[MAX(0, MIN(index, (NSInteger)themes.count - 1))];
}

+ (void)applyTheme:(SPTheme *)theme toView:(UIView *)view {
    if (!view) return;
    NSString *className = NSStringFromClass(view.class);
    BOOL isLabel = [view isKindOfClass:UILabel.class];
    BOOL isControl = [view isKindOfClass:UIControl.class];
    BOOL isSurface = [className containsString:@"Card"] || [className containsString:@"Container"] || [className containsString:@"Panel"];
    if (view.superview == nil) view.backgroundColor = theme.background;
    else if (isSurface && view.backgroundColor && CGColorGetAlpha(view.backgroundColor.CGColor) > 0.2) view.backgroundColor = theme.surface;
    if (isLabel) {
        UILabel *label = (UILabel *)view;
        if (label.textColor && CGColorGetAlpha(label.textColor.CGColor) > 0.2) {
            CGFloat white = 0;
            [label.textColor getWhite:&white alpha:nil];
            label.textColor = white > 0.68 ? theme.primary : theme.muted;
        }
    } else if (isControl) {
        view.tintColor = theme.downloadStart;
    }
    for (UIView *subview in view.subviews) [self applyTheme:theme toView:subview];
}

@end

