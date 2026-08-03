#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPControlsViewController : UIViewController
+ (void)presentFrom:(UIViewController *)presenter;
+ (void)presentGuideFrom:(UIViewController *)presenter allowOpenControls:(BOOL)allowOpenControls;
@end

NS_ASSUME_NONNULL_END

