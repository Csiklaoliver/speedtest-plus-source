#import "SPControlsViewController.h"
#import "SPState.h"
#import "SPTheme.h"
#import "SPDiagnostics.h"
#import <math.h>
#import <limits.h>

@interface SPControlsViewController () <UITextFieldDelegate>
@property(nonatomic) UIScrollView *scrollView;
@property(nonatomic) UIStackView *stack;
@property(nonatomic) NSMutableDictionary<NSString *, UITextField *> *fields;
@property(nonatomic) UIButton *themeButton;
@property(nonatomic) UISwitch *offlineSwitch;
@property(nonatomic) UISwitch *dataSaverSwitch;
@end

@implementation SPControlsViewController

+ (void)presentFrom:(UIViewController *)presenter {
    if (!presenter) return;

    // The guide and validation messages are UIAlertControllers.  UIKit keeps
    // the alert attached to the presenting controller for a short transition
    // after an action is tapped.  Presenting the controls during that window
    // used to be silently ignored, which made the admin panel look broken.
    // Dismiss an alert/transition first, then retry from its original host.
    UIViewController *shown = presenter.presentedViewController;
    if (shown) {
        if ([shown isKindOfClass:UIAlertController.class] || shown.isBeingDismissed) {
            [presenter dismissViewControllerAnimated:YES completion:^{
                [self presentFrom:presenter];
            }];
            return;
        }
        // If another app-owned modal is visible, presenting from its top
        // controller is safe and avoids dismissing the user's current screen.
        UIViewController *top = shown;
        while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
            top = top.presentedViewController;
        }
        if (top.presentedViewController && top.presentedViewController.isBeingDismissed) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self presentFrom:presenter];
            });
            return;
        }
        presenter = top;
    }

    if (presenter.presentedViewController) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self presentFrom:presenter];
        });
        return;
    }

    SPControlsViewController *controller = [self new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [presenter presentViewController:navigation animated:YES completion:nil];
}

+ (void)presentGuideFrom:(UIViewController *)presenter allowOpenControls:(BOOL)allowOpenControls {
    if (!presenter) return;
    UIViewController *shown = presenter.presentedViewController;
    if (shown) {
        if ([shown isKindOfClass:UIAlertController.class] || shown.isBeingDismissed) {
            [presenter dismissViewControllerAnimated:YES completion:^{
                [self presentGuideFrom:presenter allowOpenControls:allowOpenControls];
            }];
            return;
        }
        UIViewController *top = shown;
        while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
            top = top.presentedViewController;
        }
        if (top.presentedViewController && top.presentedViewController.isBeingDismissed) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self presentGuideFrom:presenter allowOpenControls:allowOpenControls];
            });
            return;
        }
        presenter = top;
    }
    if (presenter.presentedViewController) return;

    NSString *message = @"1. Open the provider drawer.\n2. Long-press the provider row or tap the Speedtest+ info button.\n3. Blank fields keep real values.\n4. Equal minimum and maximum gives an exact speed. A range gives a varied result.\n5. Tap Apply before GO.\n6. Local results, Compare Your Speed, sharing, and CSV use the final shown values.\n7. Disable All returns testing to normal.";
    UIAlertController *guide = [UIAlertController alertControllerWithTitle:@"Speedtest+ guide" message:message preferredStyle:UIAlertControllerStyleAlert];
    if (allowOpenControls) {
        [guide addAction:[UIAlertAction actionWithTitle:@"Open Controls" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[SPState shared] setIntroSeen:YES];
            dispatch_async(dispatch_get_main_queue(), ^{ [self presentFrom:presenter]; });
        }]];
    }
    [guide addAction:[UIAlertAction actionWithTitle:@"Got it" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        [[SPState shared] setIntroSeen:YES];
    }]];
    [presenter presentViewController:guide animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Speedtest+ Controls";
    self.fields = [NSMutableDictionary dictionary];
    SPTheme *theme = [SPTheme themeAtIndex:SPState.shared.themeIndex];
    self.view.backgroundColor = theme.background;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Apply" style:UIBarButtonItemStyleDone target:self action:@selector(apply)];
    self.scrollView = [UIScrollView new];
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    dismissTap.cancelsTouchesInView = NO;
    [self.scrollView addGestureRecognizer:dismissTap];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 12;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:18],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-18],
        [self.stack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:18],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-28],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-36]
    ]];

    [self addSection:@"Profiles"];
    UIStackView *profiles = [self horizontalStack];
    for (NSInteger index = 0; index < 3; index++) {
        UIButton *button = [self button:[NSString stringWithFormat:@"Slot %ld", (long)index + 1] action:@selector(profileTapped:)];
        button.tag = index;
        [profiles addArrangedSubview:button];
    }
    [self.stack addArrangedSubview:profiles];

    [self addSection:@"Download and upload ranges"];
    [self addPair:@"Download minimum" key:@"download_min" second:@"Download maximum" secondKey:@"download_max" keyboard:UIKeyboardTypeDecimalPad];
    [self addPair:@"Upload minimum" key:@"upload_min" second:@"Upload maximum" secondKey:@"upload_max" keyboard:UIKeyboardTypeDecimalPad];

    [self addSection:@"Latency and loss"];
    [self addPair:@"Ping (ms)" key:@"ping" second:@"Jitter (ms)" secondKey:@"jitter" keyboard:UIKeyboardTypeNumberPad];
    [self addField:@"Packet loss (0.0 to 100.0%)" key:@"packet_loss" keyboard:UIKeyboardTypeDecimalPad];

    [self addSection:@"Test modes"];
    UILabel *modeNote = [self label:@"Offline demo never opens a network connection and is saved as a local simulation. Data saver keeps a real test but bounds transfer time and bytes per connection."];
    modeNote.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    modeNote.textColor = [UIColor colorWithWhite:1 alpha:0.70];
    [self.stack addArrangedSubview:modeNote];
    self.offlineSwitch = [UISwitch new];
    self.dataSaverSwitch = [UISwitch new];
    self.offlineSwitch.on = [SPState.shared.configuration[@"offline_mode"] boolValue];
    self.dataSaverSwitch.on = [SPState.shared.configuration[@"data_saver_mode"] boolValue];
    [self.offlineSwitch addTarget:self action:@selector(offlineSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.dataSaverSwitch addTarget:self action:@selector(dataSaverSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSwitchRow:@"Offline demo (no network)" control:self.offlineSwitch];
    [self addSwitchRow:@"Data saver (bounded real test)" control:self.dataSaverSwitch];

    [self addSection:@"Provider and server"];
    [self addField:@"ISP name" key:@"isp" keyboard:UIKeyboardTypeDefault];
    [self addField:@"Server provider" key:@"server_provider" keyboard:UIKeyboardTypeDefault];
    [self addField:@"Server location" key:@"server_location" keyboard:UIKeyboardTypeDefault];

    [self addSection:@"Theme"];
    self.themeButton = [self button:[SPTheme themeAtIndex:SPState.shared.themeIndex].name action:@selector(chooseTheme)];
    [self.stack addArrangedSubview:self.themeButton];

    [self addSection:@"Panel and updates"];
    UIButton *diagnostics = [self button:@"Copy diagnostics" action:@selector(copyDiagnostics)];
    diagnostics.accessibilityLabel = @"Copy privacy-safe diagnostics";
    [self.stack addArrangedSubview:diagnostics];
    UIButton *lock = [self button:@"Hide or password protect controls" action:@selector(configureLock)];
    [self.stack addArrangedSubview:lock];
    UIStackView *links = [self horizontalStack];
    [links addArrangedSubview:[self button:@"Report a bug" action:@selector(openBugReport)]];
    [links addArrangedSubview:[self button:@"Source and docs" action:@selector(openSource)]];
    [self.stack addArrangedSubview:links];
    UISwitch *updates = [UISwitch new];
    updates.on = SPState.shared.updateChecksEnabled;
    [updates addTarget:self action:@selector(updateSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    UIStackView *updateRow = [self horizontalStack];
    UILabel *updateLabel = [self label:@"Check for Speedtest+ updates"];
    [updateRow addArrangedSubview:updateLabel];
    [updateRow addArrangedSubview:updates];
    [self.stack addArrangedSubview:updateRow];

    UIStackView *actions = [self horizontalStack];
    UIButton *disable = [self button:@"Disable All" action:@selector(disableAll)];
    UIButton *apply = [self button:@"Apply" action:@selector(apply)];
    apply.backgroundColor = theme.downloadStart;
    [actions addArrangedSubview:disable];
    [actions addArrangedSubview:apply];
    [self.stack addArrangedSubview:actions];

    [self fillFromConfiguration:SPState.shared.configuration];
    [SPTheme applyTheme:theme toView:self.view];
    [SPTheme applyFunctionalMaterialToView:self.view theme:theme];
}

- (void)copyDiagnostics {
    [self dismissKeyboard];
    UIPasteboard.generalPasteboard.string = SPDiagnosticsText(SPState.shared);
    [self showMessage:@"Diagnostics copied. It contains no IP address, account, device ID, exact location, credentials, or identity text."];
}

- (UILabel *)label:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 0;
    return label;
}

- (void)addSection:(NSString *)title {
    UILabel *label = [self label:title];
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    label.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.stack addArrangedSubview:label];
}

- (UIStackView *)horizontalStack {
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10;
    stack.distribution = UIStackViewDistributionFillEqually;
    return stack;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    button.layer.cornerRadius = 10;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 8, 12, 8);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITextField *)field:(NSString *)hint key:(NSString *)key keyboard:(UIKeyboardType)keyboard {
    UITextField *field = [UITextField new];
    field.placeholder = hint;
    field.keyboardType = keyboard;
    field.textColor = UIColor.whiteColor;
    field.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    field.layer.cornerRadius = 10;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;
    UIToolbar *keyboardBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    keyboardBar.items = @[space, done];
    [keyboardBar sizeToFit];
    field.inputAccessoryView = keyboardBar;
    UIView *padding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    field.leftView = padding;
    field.leftViewMode = UITextFieldViewModeAlways;
    [field.heightAnchor constraintEqualToConstant:46].active = YES;
    self.fields[key] = field;
    return field;
}

- (void)addField:(NSString *)hint key:(NSString *)key keyboard:(UIKeyboardType)keyboard {
    [self.stack addArrangedSubview:[self field:hint key:key keyboard:keyboard]];
}

- (void)addPair:(NSString *)first key:(NSString *)firstKey second:(NSString *)second secondKey:(NSString *)secondKey keyboard:(UIKeyboardType)keyboard {
    UIStackView *row = [self horizontalStack];
    [row addArrangedSubview:[self field:first key:firstKey keyboard:keyboard]];
    [row addArrangedSubview:[self field:second key:secondKey keyboard:keyboard]];
    [self.stack addArrangedSubview:row];
}

- (void)addSwitchRow:(NSString *)title control:(UISwitch *)control {
    UIStackView *row = [self horizontalStack];
    row.distribution = UIStackViewDistributionFill;
    UILabel *label = [self label:title];
    [row addArrangedSubview:label];
    [row addArrangedSubview:control];
    [self.stack addArrangedSubview:row];
}

- (void)fillFromConfiguration:(NSDictionary<NSString *,id> *)configuration {
    [self.fields enumerateKeysAndObjectsUsingBlock:^(NSString *key, UITextField *field, BOOL *stop) {
        id value = configuration[key];
        field.text = value && value != NSNull.null ? [value description] : @"";
    }];
    self.offlineSwitch.on = [configuration[@"offline_mode"] boolValue];
    self.dataSaverSwitch.on = [configuration[@"data_saver_mode"] boolValue];
}

- (NSString *)trimmed:(NSString *)text { return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; }

- (NSNumber *)localizedNumberFromText:(NSString *)text {
    for (NSLocale *locale in @[NSLocale.currentLocale, [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]) {
        NSNumberFormatter *formatter = [NSNumberFormatter new];
        formatter.locale = locale;
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.lenient = NO;
        NSNumber *number = [formatter numberFromString:text];
        if (number) return number;
    }
    return nil;
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (NSNumber *)decimalForKey:(NSString *)key maximum:(double)maximum error:(NSString **)error {
    NSString *text = [self trimmed:self.fields[key].text ?: @""];
    if (!text.length) return nil;
    NSNumber *parsed = [self localizedNumberFromText:text];
    double value = parsed.doubleValue;
    if (!parsed || !isfinite(value) || value < 0 || value > maximum) {
        *error = [NSString stringWithFormat:@"%@ must be between 0 and %@.", self.fields[key].placeholder, @(maximum)];
        return nil;
    }
    return @(value);
}

- (NSDictionary<NSString *, id> *)validatedConfigurationWithError:(NSString **)error {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    double maxMbps = ((double)LLONG_MAX - 1000.0) / 1000.0;
    for (NSString *key in @[@"download_min", @"download_max", @"upload_min", @"upload_max"]) {
        NSNumber *value = [self decimalForKey:key maximum:maxMbps error:error];
        if (*error) return nil;
        if (value) config[key] = value;
    }
    for (NSString *prefix in @[@"download", @"upload"]) {
        NSNumber *minimum = config[[prefix stringByAppendingString:@"_min"]];
        NSNumber *maximum = config[[prefix stringByAppendingString:@"_max"]];
        if ((minimum == nil) != (maximum == nil)) {
            *error = [NSString stringWithFormat:@"Enter both the %@ minimum and maximum, or leave both blank to use the measured speed.", prefix];
            return nil;
        }
        if (minimum && maximum && minimum.doubleValue > maximum.doubleValue) {
            *error = [NSString stringWithFormat:@"%@ minimum cannot be greater than its maximum.", prefix.capitalizedString];
            return nil;
        }
    }
    for (NSString *key in @[@"ping", @"jitter"]) {
        NSNumber *value = [self decimalForKey:key maximum:9999 error:error];
        if (*error) return nil;
        if (value && floor(value.doubleValue) != value.doubleValue) {
            *error = [NSString stringWithFormat:@"%@ must be a whole number.", self.fields[key].placeholder];
            return nil;
        }
        if (value) config[key] = value;
    }
    NSNumber *loss = [self decimalForKey:@"packet_loss" maximum:100 error:error];
    if (*error) return nil;
    if (loss) config[@"packet_loss"] = @(round(loss.doubleValue * 10.0) / 10.0);
    for (NSString *key in @[@"isp", @"server_provider", @"server_location"]) {
        NSString *value = [self trimmed:self.fields[key].text ?: @""];
        if (value.length > 64) {
            *error = [NSString stringWithFormat:@"%@ is limited to 64 characters.", self.fields[key].placeholder];
            return nil;
        }
        if (value.length) config[key] = value;
    }
    if (self.offlineSwitch.isOn) config[@"offline_mode"] = @YES;
    else if (self.dataSaverSwitch.isOn) config[@"data_saver_mode"] = @YES;
    return config;
}

- (void)showMessage:(NSString *)message {
    if (self.presentedViewController) {
        // Action sheets and alerts dismiss asynchronously.  Queue our result
        // message instead of attempting a second presentation on top of one.
        [self dismissViewControllerAnimated:YES completion:^{
            [self showMessage:message];
        }];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Speedtest+" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentAfterCurrentAlertDismisses:(UIViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedViewController) {
            [self dismissViewControllerAnimated:YES completion:^{
                [self presentViewController:controller animated:YES completion:nil];
            }];
        } else {
            [self presentViewController:controller animated:YES completion:nil];
        }
    });
}

- (void)apply {
    [self dismissKeyboard];
    NSString *error = nil;
    NSDictionary *configuration = [self validatedConfigurationWithError:&error];
    if (!configuration) { [self showMessage:error ?: @"The settings could not be applied."]; return; }
    [SPState.shared applyConfiguration:configuration];
    [self showMessage:@"Settings applied. Start a new test to use them."];
}

- (void)disableAll { [self dismissKeyboard]; [SPState.shared disableAll]; [self showMessage:@"All overrides are disabled."]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)offlineSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) self.dataSaverSwitch.on = NO;
}

- (void)dataSaverSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) self.offlineSwitch.on = NO;
}

- (void)chooseTheme {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Choose theme" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [[SPTheme allThemes] enumerateObjectsUsingBlock:^(SPTheme *theme, NSUInteger index, BOOL *stop) {
        [sheet addAction:[UIAlertAction actionWithTitle:theme.name style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [SPState.shared setThemeIndex:index];
            [self.themeButton setTitle:theme.name forState:UIControlStateNormal];
            if (SPState.shared.testActive) {
                [self showMessage:@"Theme saved; applies when Speedtest+ is reopened."];
            } else {
                [SPTheme applyTheme:theme toView:self.view];
                [SPTheme applyFunctionalMaterialToView:self.view theme:theme];
            }
        }]];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.themeButton;
    sheet.popoverPresentationController.sourceRect = self.themeButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)profileTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSDictionary *profile = [SPState.shared profileAtIndex:index];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Profile %ld", (long)index + 1] message:profile[@"name"] preferredStyle:UIAlertControllerStyleActionSheet];
    if (profile) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Load" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self fillFromConfiguration:profile[@"configuration"] ?: @{}]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [self confirmDeleteProfile:index]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:profile ? @"Overwrite" : @"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self nameAndSaveProfile:index replacing:(profile != nil)]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)nameAndSaveProfile:(NSInteger)index replacing:(BOOL)replacing {
    void (^prompt)(void) = ^{
        UIAlertController *name = [UIAlertController alertControllerWithTitle:@"Profile name" message:@"Enter 1 to 24 characters." preferredStyle:UIAlertControllerStyleAlert];
        [name addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Profile name"; }];
        [name addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [name addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSString *profileName = [self trimmed:name.textFields.firstObject.text ?: @""];
            NSString *error = nil;
            NSDictionary *configuration = [self validatedConfigurationWithError:&error];
            if (profileName.length < 1 || profileName.length > 24) { [self showMessage:@"Profile names must contain 1 to 24 characters."]; return; }
            if (!configuration) { [self showMessage:error]; return; }
            [SPState.shared saveProfile:@{ @"name": profileName, @"configuration": configuration } atIndex:index];
        }]];
        [self presentAfterCurrentAlertDismisses:name];
    };
    if (!replacing) { prompt(); return; }
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Overwrite profile?" message:@"The saved settings in this slot will be replaced." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Overwrite" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), prompt);
    }]];
    [self presentAfterCurrentAlertDismisses:confirm];
}

- (void)confirmDeleteProfile:(NSInteger)index {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete profile?" message:@"This cannot be undone." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { [SPState.shared deleteProfileAtIndex:index]; }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)configureLock {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Protect controls" message:@"Leave the password blank to keep the panel visible. If hidden, tap the Speedtest+ info button or long-press the provider area to unlock it." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Optional password"; field.secureTextEntry = YES; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Keep visible" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [SPState.shared setPanelHidden:NO password:nil]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hide" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [SPState.shared setPanelHidden:YES password:alert.textFields.firstObject.text]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateSwitchChanged:(UISwitch *)sender { [SPState.shared setUpdateChecksEnabled:sender.isOn]; }

- (void)openBugReport {
    NSURL *url = [NSURL URLWithString:@"https://speedtest.oliverprojects.tech/report"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)openSource {
    NSURL *url = [NSURL URLWithString:@"https://github.com/Csiklaoliver/speedtest-plus-source"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

@end
