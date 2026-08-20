#import "SPHarnessViewController.h"
#import "SPControlsViewController.h"
#import "SPShareBuilder.h"
#import "SPState.h"
#import "SPTheme.h"

@interface SPHarnessViewController ()
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *downloadLabel;
@property(nonatomic, strong) UILabel *uploadLabel;
@property(nonatomic, strong) UILabel *resultLabel;
@property(nonatomic, strong) UIButton *runButton;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) NSInteger frame;
@end

@implementation SPHarnessViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Speedtest+ Lab";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Controls"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(openControls)];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24]
    ]];

    UILabel *notice = [self label:@"Simulator validation host\nRuns the real Speedtest+ state, controls, themes, curves, profiles, offline flow, sharing, diagnostics, updater, and connection checks. It does not contain or imitate Ookla network services." style:UIFontTextStyleFootnote];
    notice.accessibilityIdentifier = @"harness.notice";
    notice.textColor = UIColor.whiteColor;
    [stack addArrangedSubview:notice];

    self.statusLabel = [self label:@"Ready" style:UIFontTextStyleHeadline];
    self.statusLabel.accessibilityIdentifier = @"harness.status";
    [stack addArrangedSubview:self.statusLabel];

    UIStackView *speeds = [UIStackView new];
    speeds.axis = UILayoutConstraintAxisHorizontal;
    speeds.distribution = UIStackViewDistributionFillEqually;
    speeds.spacing = 12;
    self.downloadLabel = [self metricLabel:@"Download\n-- Mbps" identifier:@"harness.download"];
    self.uploadLabel = [self metricLabel:@"Upload\n-- Mbps" identifier:@"harness.upload"];
    [speeds addArrangedSubview:self.downloadLabel];
    [speeds addArrangedSubview:self.uploadLabel];
    [stack addArrangedSubview:speeds];

    self.runButton = [self button:@"Run local validation" action:@selector(runValidation)];
    self.runButton.accessibilityIdentifier = @"harness.run";
    [stack addArrangedSubview:self.runButton];
    UIButton *controls = [self button:@"Open Speedtest+ Controls" action:@selector(openControls)];
    controls.accessibilityIdentifier = @"harness.controls";
    [stack addArrangedSubview:controls];
    UIButton *share = [self button:@"Copy last local result" action:@selector(copyLastResult)];
    share.accessibilityIdentifier = @"harness.share";
    [stack addArrangedSubview:share];

    self.resultLabel = [self label:@"No local validation result yet." style:UIFontTextStyleBody];
    self.resultLabel.accessibilityIdentifier = @"harness.result";
    [stack addArrangedSubview:self.resultLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshThemeAndState) name:SPStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshThemeAndState) name:SPThemeDidChangeNotification object:nil];
    [self refreshThemeAndState];
}

- (void)dealloc {
    [self.timer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:style];
    label.numberOfLines = 0;
    return label;
}

- (UILabel *)metricLabel:(NSString *)text identifier:(NSString *)identifier {
    UILabel *label = [self label:text style:UIFontTextStyleTitle2];
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 14;
    label.layer.masksToBounds = YES;
    label.accessibilityIdentifier = identifier;
    [label.heightAnchor constraintEqualToConstant:112].active = YES;
    return label;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    button.layer.cornerRadius = 12;
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 12, 14, 12);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)refreshThemeAndState {
    SPTheme *theme = [SPTheme themeAtIndex:SPState.shared.themeIndex];
    self.view.backgroundColor = theme.background;
    self.navigationController.navigationBar.tintColor = theme.primary;
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = theme.background;
    appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: UIColor.whiteColor };
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    for (UILabel *label in @[self.statusLabel, self.downloadLabel, self.uploadLabel, self.resultLabel]) {
        label.textColor = UIColor.whiteColor;
    }
    self.downloadLabel.backgroundColor = [theme.downloadStart colorWithAlphaComponent:0.28];
    self.uploadLabel.backgroundColor = [theme.uploadStart colorWithAlphaComponent:0.28];
    self.runButton.backgroundColor = [theme.primary colorWithAlphaComponent:0.22];
    if (!SPState.shared.testActive) {
        self.statusLabel.text = SPState.shared.active
            ? [NSString stringWithFormat:@"Ready • %ld active override groups", (long)SPState.shared.activeOverrideCount]
            : @"Ready • native measurements selected";
    }
}

- (void)openControls {
    [SPControlsViewController presentFrom:self];
}

- (void)runValidation {
    if (self.timer) return;
    [SPState.shared beginTest];
    [SPState.shared setStage:SPDirectionDownload];
    self.frame = 0;
    self.runButton.enabled = NO;
    self.statusLabel.text = [SPState.shared runBoolForKey:@"offline_mode"] ? @"Running offline demo…" : @"Running local presentation validation…";
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.12 repeats:YES block:^(__unused NSTimer *timer) {
        [weakSelf advanceValidation];
    }];
}

- (void)advanceValidation {
    self.frame += 1;
    BOOL downloading = self.frame <= 30;
    NSInteger phaseFrame = downloading ? self.frame : self.frame - 30;
    SPDirection direction = downloading ? SPDirectionDownload : SPDirectionUpload;
    [SPState.shared setStage:direction];
    double progress = MIN(1.0, (double)phaseFrame / 30.0);
    double measured = downloading ? 187.4 : 42.8;
    double shown = [SPState.shared displayMbpsForDirection:direction measuredMbps:measured progress:progress];
    if (downloading) self.downloadLabel.text = [NSString stringWithFormat:@"Download\n%.1f Mbps", shown];
    else self.uploadLabel.text = [NSString stringWithFormat:@"Upload\n%.1f Mbps", shown];
    if (self.frame < 60) return;

    if ([SPState.shared runBoolForKey:@"offline_mode"]) {
        [SPState.shared completeOfflineDemo];
    } else {
        [SPState.shared completeTestWithMeasuredDownload:187.4
                                                  upload:42.8
                                                    ping:@18
                                                  jitter:@3
                                              packetLoss:@0.0
                                                     isp:@"Measured ISP"
                                          serverProvider:@"Measured server"
                                          serverLocation:@"Vienna"];
    }
    [self.timer invalidate];
    self.timer = nil;
    self.runButton.enabled = YES;
    NSDictionary *result = SPState.shared.lastResult;
    self.downloadLabel.text = [NSString stringWithFormat:@"Download\n%.1f Mbps", [result[@"download_mbps"] doubleValue]];
    self.uploadLabel.text = [NSString stringWithFormat:@"Upload\n%.1f Mbps", [result[@"upload_mbps"] doubleValue]];
    self.statusLabel.text = [result[@"offline_demo"] boolValue] ? @"Offline demo completed locally" : @"Local presentation validation completed";
    self.resultLabel.text = [SPShareBuilder plainTextFromResult:result];
}

- (void)copyLastResult {
    NSDictionary *result = SPState.shared.lastResult;
    if (!result.count) {
        self.resultLabel.text = @"Run a local validation first.";
        return;
    }
    UIPasteboard.generalPasteboard.string = [SPShareBuilder plainTextFromResult:result];
    self.resultLabel.text = @"Last local result copied. Customized values remain clearly labelled.";
}

@end
