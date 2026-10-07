#import "ZTechRootViewController.h"
#import "ZTechDeviceDatabase.h"

@interface ZTechRootViewController ()

@property (nonatomic, strong) ZTechDeviceProfile *currentProfile;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;

// Identifier Card UI
@property (nonatomic, strong) UILabel *uuidLabel;
@property (nonatomic, strong) UILabel *deviceLine1Label;
@property (nonatomic, strong) UILabel *deviceLine2Label;

// Switches & Dynamic Subtitles
@property (nonatomic, strong) UISwitch *lockModelSwitch;
@property (nonatomic, strong) UILabel *lockModelSubLabel;

@property (nonatomic, strong) UISwitch *respringSwitch;
@property (nonatomic, strong) UILabel *respringSubLabel;

@property (nonatomic, strong) UISwitch *sameScreenSwitch;
@property (nonatomic, strong) UILabel *sameScreenSubLabel;

@property (nonatomic, strong) UISwitch *matchChipSwitch;
@property (nonatomic, strong) UILabel *matchChipSubLabel;

// Buttons
@property (nonatomic, strong) UIButton *changeDeviceButton;
@property (nonatomic, strong) UIButton *syncIPButton;
@property (nonatomic, strong) UIButton *copyReportButton;

// Check Card UI
@property (nonatomic, strong) UILabel *checkDetailLabel;

@end

@implementation ZTechRootViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.04 alpha:1.0];
    self.currentProfile = [ZTechDeviceDatabase loadOrCreateDefaultProfile];

    [self setupScrollView];
    [self buildHeaderSection];
    [self buildIdentifierCard];
    [self buildSwitchesCard];
    [self buildActionButtons];
    [self buildCheckCard];
    [self refreshUIWithCurrentProfile];
}

#pragma mark - Color Helpers

- (UIColor *)cardBackgroundColor {
    return [UIColor colorWithRed:0.08 green:0.09 blue:0.08 alpha:1.0];
}

- (UIColor *)cardBorderColor {
    return [UIColor colorWithRed:0.20 green:0.21 blue:0.16 alpha:1.0];
}

- (UIColor *)goldAccentColor {
    return [UIColor colorWithRed:0.87 green:0.78 blue:0.53 alpha:1.0];
}

- (UIColor *)creamButtonColor {
    return [UIColor colorWithRed:0.92 green:0.88 blue:0.72 alpha:1.0];
}

- (UIColor *)darkButtonTextColor {
    return [UIColor colorWithRed:0.16 green:0.15 blue:0.11 alpha:1.0];
}

- (UIColor *)subtitleTextColor {
    return [UIColor colorWithRed:0.62 green:0.65 blue:0.62 alpha:1.0];
}

#pragma mark - Layout Construction

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.mainStack = [[UIStackView alloc] init];
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainStack.axis = UILayoutConstraintAxisVertical;
    self.mainStack.spacing = 14.0;
    self.mainStack.alignment = UIStackViewAlignmentFill;
    [self.scrollView addSubview:self.mainStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.mainStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:12.0],
        [self.mainStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16.0],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16.0],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-28.0],
        [self.mainStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32.0]
    ]];
}

- (UIView *)createStyledCardView {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self cardBackgroundColor];
    card.layer.cornerRadius = 18.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self cardBorderColor].CGColor;
    return card;
}

- (void)buildHeaderSection {
    UIView *headerContainer = [[UIView alloc] init];
    headerContainer.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"ZTech";
    titleLabel.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = @"Change identity · Đổi máy Zalo";
    subLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    subLabel.textColor = [UIColor colorWithRed:0.75 green:0.76 blue:0.72 alpha:1.0];

    [headerContainer addSubview:titleLabel];
    [headerContainer addSubview:subLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:2.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],

        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subLabel.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:2.0],
        [subLabel.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
        [subLabel.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor constant:-2.0]
    ]];

    [self.mainStack addArrangedSubview:headerContainer];
}

- (void)buildIdentifierCard {
    UIView *card = [self createStyledCardView];

    UILabel *tagLabel = [[UILabel alloc] init];
    tagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tagLabel.text = @"I D E N T I F I E R";
    tagLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    tagLabel.textColor = [self goldAccentColor];

    self.uuidLabel = [[UILabel alloc] init];
    self.uuidLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.uuidLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    self.uuidLabel.textColor = [UIColor whiteColor];
    self.uuidLabel.numberOfLines = 1;
    self.uuidLabel.adjustsFontSizeToFitWidth = YES;
    self.uuidLabel.minimumScaleFactor = 0.75;

    self.deviceLine1Label = [[UILabel alloc] init];
    self.deviceLine1Label.translatesAutoresizingMaskIntoConstraints = NO;
    self.deviceLine1Label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.deviceLine1Label.textColor = [UIColor colorWithWhite:0.90 alpha:1.0];
    self.deviceLine1Label.numberOfLines = 1;

    self.deviceLine2Label = [[UILabel alloc] init];
    self.deviceLine2Label.translatesAutoresizingMaskIntoConstraints = NO;
    self.deviceLine2Label.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightRegular];
    self.deviceLine2Label.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    self.deviceLine2Label.numberOfLines = 0;

    [card addSubview:tagLabel];
    [card addSubview:self.uuidLabel];
    [card addSubview:self.deviceLine1Label];
    [card addSubview:self.deviceLine2Label];

    [NSLayoutConstraint activateConstraints:@[
        [tagLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [tagLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [tagLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.uuidLabel.topAnchor constraintEqualToAnchor:tagLabel.bottomAnchor constant:8.0],
        [self.uuidLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.uuidLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.deviceLine1Label.topAnchor constraintEqualToAnchor:self.uuidLabel.bottomAnchor constant:10.0],
        [self.deviceLine1Label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.deviceLine1Label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.deviceLine2Label.topAnchor constraintEqualToAnchor:self.deviceLine1Label.bottomAnchor constant:4.0],
        [self.deviceLine2Label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.deviceLine2Label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.deviceLine2Label.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

- (UIView *)createSwitchRowWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                           isDefault:(BOOL)defaultOn
                           outSwitch:(UISwitch **)outSwitch
                         outSubLabel:(UILabel **)outSubLabel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = subtitle;
    subLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    subLabel.textColor = [self subtitleTextColor];
    subLabel.numberOfLines = 0;

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.on = defaultOn;
    toggle.onTintColor = [self goldAccentColor];
    [toggle addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    [row addSubview:titleLabel];
    [row addSubview:subLabel];
    [row addSubview:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:6.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-12.0],

        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [subLabel.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-12.0],
        [subLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-6.0],

        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [toggle.widthAnchor constraintEqualToConstant:51.0]
    ]];

    if (outSwitch) *outSwitch = toggle;
    if (outSubLabel) *outSubLabel = subLabel;
    return row;
}

- (void)buildSwitchesCard {
    UIView *card = [self createStyledCardView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    [card addSubview:stack];

    UISwitch *sw1 = nil; UILabel *sub1 = nil;
    UIView *row1 = [self createSwitchRowWithTitle:@"Khoá đời máy · Giữ máy thật"
                                         subtitle:@"OFF: Fake Tất Cả — theo Fake màn / Khớp chip."
                                        isDefault:NO
                                        outSwitch:&sw1
                                      outSubLabel:&sub1];
    self.lockModelSwitch = sw1;
    self.lockModelSubLabel = sub1;

    UISwitch *sw2 = nil; UILabel *sub2 = nil;
    UIView *row2 = [self createSwitchRowWithTitle:@"Respring after Change · Làm mới SB"
                                         subtitle:@"OFF: xong là dùng luôn, không respring."
                                        isDefault:NO
                                        outSwitch:&sw2
                                      outSubLabel:&sub2];
    self.respringSwitch = sw2;
    self.respringSubLabel = sub2;

    UISwitch *sw3 = nil; UILabel *sub3 = nil;
    UIView *row3 = [self createSwitchRowWithTitle:@"Fake màn hình · Chỉ máy cùng màn"
                                         subtitle:@"ON: chỉ bốc máy CÙNG MÀN HÌNH máy thật — màn không lệch."
                                        isDefault:YES
                                        outSwitch:&sw3
                                      outSubLabel:&sub3];
    self.sameScreenSwitch = sw3;
    self.sameScreenSubLabel = sub3;

    UISwitch *sw4 = nil; UILabel *sub4 = nil;
    UIView *row4 = [self createSwitchRowWithTitle:@"Khớp chip · Sạch tuyệt đối"
                                         subtitle:@"ON: chỉ máy cùng CHIP+RAM+màn → sạch tuyệt đối (ít lựa chọn)."
                                        isDefault:YES
                                        outSwitch:&sw4
                                      outSubLabel:&sub4];
    self.matchChipSwitch = sw4;
    self.matchChipSubLabel = sub4;

    [stack addArrangedSubview:row1];
    [stack addArrangedSubview:row2];
    [stack addArrangedSubview:row3];
    [stack addArrangedSubview:row4];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

- (void)buildActionButtons {
    self.changeDeviceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeDeviceButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.changeDeviceButton.backgroundColor = [self creamButtonColor];
    self.changeDeviceButton.layer.cornerRadius = 16.0;
    [self.changeDeviceButton setTitle:@"Change device · Đổi máy" forState:UIControlStateNormal];
    [self.changeDeviceButton setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.changeDeviceButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [self.changeDeviceButton addTarget:self action:@selector(onTapChangeDevice) forControlEvents:UIControlEventTouchUpInside];

    self.syncIPButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.syncIPButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.syncIPButton.backgroundColor = [self cardBackgroundColor];
    self.syncIPButton.layer.cornerRadius = 16.0;
    self.syncIPButton.layer.borderWidth = 1.0;
    self.syncIPButton.layer.borderColor = [self cardBorderColor].CGColor;
    [self.syncIPButton setTitle:@"Đồng bộ vị trí theo IP" forState:UIControlStateNormal];
    [self.syncIPButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.syncIPButton.titleLabel.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightBold];
    [self.syncIPButton addTarget:self action:@selector(onTapSyncIP) forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [self.changeDeviceButton.heightAnchor constraintEqualToConstant:54.0],
        [self.syncIPButton.heightAnchor constraintEqualToConstant:52.0]
    ]];

    [self.mainStack addArrangedSubview:self.changeDeviceButton];
    [self.mainStack addArrangedSubview:self.syncIPButton];
}

- (void)buildCheckCard {
    UIView *card = [self createStyledCardView];

    UILabel *checkTitle = [[UILabel alloc] init];
    checkTitle.translatesAutoresizingMaskIntoConstraints = NO;
    checkTitle.text = @"C H E C K";
    checkTitle.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    checkTitle.textColor = [self goldAccentColor];

    self.copyReportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.copyReportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.copyReportButton.backgroundColor = [self creamButtonColor];
    self.copyReportButton.layer.cornerRadius = 12.0;
    [self.copyReportButton setTitle:@"Copy report · Sao chép" forState:UIControlStateNormal];
    [self.copyReportButton setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.copyReportButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.copyReportButton.contentEdgeInsets = UIEdgeInsetsMake(8.0, 14.0, 8.0, 14.0);
    [self.copyReportButton addTarget:self action:@selector(onTapCopyReport) forControlEvents:UIControlEventTouchUpInside];

    self.checkDetailLabel = [[UILabel alloc] init];
    self.checkDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkDetailLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
    self.checkDetailLabel.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    self.checkDetailLabel.numberOfLines = 0;

    [card addSubview:checkTitle];
    [card addSubview:self.copyReportButton];
    [card addSubview:self.checkDetailLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.copyReportButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [self.copyReportButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],

        [checkTitle.centerYAnchor constraintEqualToAnchor:self.copyReportButton.centerYAnchor],
        [checkTitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],

        [self.checkDetailLabel.topAnchor constraintEqualToAnchor:self.copyReportButton.bottomAnchor constant:10.0],
        [self.checkDetailLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.checkDetailLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.checkDetailLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

#pragma mark - Actions & Updates

- (void)onSwitchChanged:(UISwitch *)sender {
    self.lockModelSubLabel.text = self.lockModelSwitch.isOn
        ? @"ON: Giữ nguyên đời máy thật — chỉ đổi ID & thông số phụ."
        : @"OFF: Fake Tất Cả — theo Fake màn / Khớp chip.";

    self.respringSubLabel.text = self.respringSwitch.isOn
        ? @"ON: Tự động làm mới SpringBoard (Respring) sau khi đổi."
        : @"OFF: xong là dùng luôn, không respring.";

    self.sameScreenSubLabel.text = self.sameScreenSwitch.isOn
        ? @"ON: chỉ bốc máy CÙNG MÀN HÌNH máy thật — màn không lệch."
        : @"OFF: cho phép bốc mọi kích thước màn hình.";

    self.matchChipSubLabel.text = self.matchChipSwitch.isOn
        ? @"ON: chỉ máy cùng CHIP+RAM+màn → sạch tuyệt đối (ít lựa chọn)."
        : @"OFF: cho phép khác dòng chip và dung lượng RAM.";

    [self refreshCheckFooterText];
}

- (void)refreshUIWithCurrentProfile {
    self.uuidLabel.text = self.currentProfile.identifier;
    self.deviceLine1Label.text = [self.currentProfile summaryLine1];
    self.deviceLine2Label.text = [self.currentProfile summaryLine2];
    [self refreshCheckFooterText];
}

- (void)refreshCheckFooterText {
    NSString *modeStr = self.lockModelSwitch.isOn ? @"Đang Khoá Đời Máy" : @"Đang Fake Tất Cả";
    self.checkDetailLabel.text = [NSString stringWithFormat:
        @"Xanh = fake đã ghi vào Zalo. Đỏ = chưa ghi.\n"
        @"%ld mục thành công · 0 chưa ghi. Đã ghi %ld file vào Zalo. %@. Đóng Zalo rồi mở lại mới có hiệu lực.",
        (long)self.currentProfile.successItemsCount,
        (long)self.currentProfile.writtenFilesCount,
        modeStr];
}

- (void)onTapChangeDevice {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    self.currentProfile = [ZTechDeviceDatabase generateProfileWithLockRealModel:self.lockModelSwitch.isOn
                                                                     sameScreen:self.sameScreenSwitch.isOn
                                                                      matchChip:self.matchChipSwitch.isOn
                                                                    currentCity:self.currentProfile.city];
    [UIView transitionWithView:self.view
                      duration:0.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [self refreshUIWithCurrentProfile];
    } completion:^(BOOL finished) {
        if (self.respringSwitch.isOn) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [ZTechDeviceDatabase performRespringIfPossible];
            });
        }
    }];
}

- (void)onTapSyncIP {
    [self.syncIPButton setTitle:@"Đang đồng bộ vị trí IP..." forState:UIControlStateNormal];
    self.syncIPButton.enabled = NO;

    [ZTechDeviceDatabase syncLocationByIPWithCompletion:^(NSString *city, NSString *isp, NSError *error) {
        self.syncIPButton.enabled = YES;
        [self.syncIPButton setTitle:@"Đồng bộ vị trí theo IP" forState:UIControlStateNormal];

        if (city.length > 0) {
            self.currentProfile.city = city;
            if (isp.length > 0) {
                if ([isp rangeOfString:@"Viettel" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    self.currentProfile.carrier = @"Viettel";
                } else if ([isp rangeOfString:@"VNPT" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                           [isp rangeOfString:@"Vina" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    self.currentProfile.carrier = @"Vinaphone";
                } else if ([isp rangeOfString:@"Mobi" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    self.currentProfile.carrier = @"MobiFone";
                }
            }
            [ZTechDeviceDatabase writeProfileFiles:self.currentProfile error:nil];
            [[NSUserDefaults standardUserDefaults] setObject:[self.currentProfile toDictionary] forKey:@"ZTechCurrentProfile"];
            [self refreshUIWithCurrentProfile];
        }
    }];
}

- (void)onTapCopyReport {
    NSString *report = [self.currentProfile fullReportTextWithFlags:self.lockModelSwitch.isOn
                                                      respringAfter:self.respringSwitch.isOn
                                                         sameScreen:self.sameScreenSwitch.isOn
                                                          matchChip:self.matchChipSwitch.isOn];
    [UIPasteboard generalPasteboard].string = report;
    [self.copyReportButton setTitle:@"Đã sao chép ✓" forState:UIControlStateNormal];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.copyReportButton setTitle:@"Copy report · Sao chép" forState:UIControlStateNormal];
    });
}

@end
