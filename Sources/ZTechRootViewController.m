#import "ZTechRootViewController.h"
#import "ZTechDeviceDatabase.h"
#import "ZTechLicenseManager.h"
#import "ZTechVaultManager.h"

typedef NS_ENUM(NSInteger, ZTechMainTab) {
    ZTechMainTabFeatures = 0,
    ZTechMainTabVault = 1,
    ZTechMainTabLicense = 2
};

@interface ZTechRootViewController ()

@property (nonatomic, strong) ZTechDeviceProfile *currentProfile;
@property (nonatomic, assign) ZTechModelTierFilter currentModelTier;
@property (nonatomic, assign) ZTechMainTab activeTab;

// Top Bar & Toast Banner
@property (nonatomic, strong) UIView *topHeaderBar;
@property (nonatomic, strong) UIView *headerLicenseBadge;
@property (nonatomic, strong) UIImageView *headerLicenseIcon;
@property (nonatomic, strong) UILabel *headerLicenseText;
@property (nonatomic, strong) UIView *toastBannerView;
@property (nonatomic, strong) UILabel *toastBannerLabel;

// ScrollView & 3 Tab Containers
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *tabFeaturesStack;
@property (nonatomic, strong) UIStackView *tabVaultStack;
@property (nonatomic, strong) UIStackView *tabLicenseStack;

// Bottom Custom Tab Bar
@property (nonatomic, strong) UIView *bottomTabBar;
@property (nonatomic, strong) NSArray<UIControl *> *tabButtons;
@property (nonatomic, strong) NSArray<UIImageView *> *tabIcons;
@property (nonatomic, strong) NSArray<UILabel *> *tabLabels;
@property (nonatomic, strong) NSArray<UIView *> *tabIndicators;

// TAB 1: Features UI
@property (nonatomic, strong) UILabel *modelHeroLabel;
@property (nonatomic, strong) UILabel *machineBadgeLabel;
@property (nonatomic, strong) UILabel *iosBadgeLabel;
@property (nonatomic, strong) UILabel *uuidMonoLabel;
@property (nonatomic, strong) UILabel *specChipValueLabel;
@property (nonatomic, strong) UILabel *specScreenValueLabel;
@property (nonatomic, strong) UILabel *specNetValueLabel;
@property (nonatomic, strong) UILabel *specBatValueLabel;
@property (nonatomic, strong) NSArray<UIButton *> *tierSegmentButtons;

@property (nonatomic, strong) UIButton *changeDeviceButton;
@property (nonatomic, strong) UIButton *cleanResetButton;
@property (nonatomic, strong) UIButton *syncIPButton;
@property (nonatomic, strong) UIButton *openZaloButton;
@property (nonatomic, strong) UIButton *btnCopyReport;

@property (nonatomic, strong) UISwitch *lockModelSwitch;
@property (nonatomic, strong) UILabel *lockModelSubLabel;
@property (nonatomic, strong) UISwitch *respringSwitch;
@property (nonatomic, strong) UILabel *respringSubLabel;
@property (nonatomic, strong) UISwitch *sameScreenSwitch;
@property (nonatomic, strong) UILabel *sameScreenSubLabel;
@property (nonatomic, strong) UISwitch *matchChipSwitch;
@property (nonatomic, strong) UILabel *matchChipSubLabel;
@property (nonatomic, strong) UILabel *checkDetailLabel;

// TAB 2: Vault & Proxy UI
@property (nonatomic, strong) UILabel *vaultCountBadgeLabel;
@property (nonatomic, strong) UILabel *activeProxyStatusLabel;
@property (nonatomic, strong) UIStackView *vaultItemsStack;
@property (nonatomic, strong) NSArray<ZTechVaultAccount *> *vaultAccounts;
@property (nonatomic, copy) NSString *pendingDeleteAccountId;

// TAB 3: License UI
@property (nonatomic, strong) UIImageView *licShieldIconView;
@property (nonatomic, strong) UILabel *licMainStateLabel;
@property (nonatomic, strong) UILabel *licHwidValueLabel;
@property (nonatomic, strong) UILabel *licKeyUsedValueLabel;
@property (nonatomic, strong) UILabel *licPlanDetailValueLabel;
@property (nonatomic, strong) UIButton *btnRefreshLicenseCloud;

// Lock Screen Overlay UI (When unlicensed)
@property (nonatomic, strong) UIView *lockOverlayView;
@property (nonatomic, strong) UILabel *keyDisplayLabel;
@property (nonatomic, copy) NSString *enteredKeyBuffer;
@property (nonatomic, strong) UIView *keypadContainerView;
@property (nonatomic, strong) UILabel *lockStatusMsgLabel;
@property (nonatomic, strong) UIButton *btnActivateKey;
@property (nonatomic, strong) UIButton *btnToggleKeypad;
@property (nonatomic, strong) UIButton *btnCloseKeyOverlay;

// Vault / Proxy Editor Modal Overlay
@property (nonatomic, strong) UIView *vaultModalOverlay;
@property (nonatomic, strong) UILabel *vaultModalTitleLabel;
@property (nonatomic, strong) UILabel *vaultNameDisplayLabel;
@property (nonatomic, strong) UILabel *vaultProxyDisplayLabel;
@property (nonatomic, strong) UIButton *btnVaultFieldSwitch;
@property (nonatomic, strong) UIButton *btnVaultSaveConfirm;
@property (nonatomic, assign) BOOL isEditingProxyField;
@property (nonatomic, assign) BOOL isSavingNewVaultAccount;
@property (nonatomic, copy) NSString *editingVaultAccountId;
@property (nonatomic, copy) NSString *modalNameBuffer;
@property (nonatomic, copy) NSString *modalProxyBuffer;

@end

@implementation ZTechRootViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.04 alpha:1.0];
    self.enteredKeyBuffer = [ZTechLicenseManager savedLicenseKey] ?: @"";

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if (![prefs boolForKey:@"ZTech_V46_IP16_Initialized"]) {
        [prefs setBool:YES forKey:@"ZTech_V46_IP16_Initialized"];
        [prefs setBool:YES forKey:@"ZTech_SwitchInitialized"];
        [prefs setBool:NO forKey:@"ZTech_LockModel"];
        [prefs setBool:NO forKey:@"ZTech_SameScreen"];
        [prefs setBool:NO forKey:@"ZTech_MatchChip"];
        [prefs setInteger:ZTechModelTierIPhone16 forKey:@"ZTech_ModelTier"];
        [prefs synchronize];
        self.currentModelTier = ZTechModelTierIPhone16;
        self.currentProfile = [ZTechDeviceDatabase generateProfileWithLockRealModel:NO
                                                                         sameScreen:NO
                                                                          matchChip:NO
                                                                          modelTier:ZTechModelTierIPhone16
                                                                        currentCity:nil];
    } else {
        self.currentModelTier = (ZTechModelTierFilter)[prefs integerForKey:@"ZTech_ModelTier"];
        self.currentProfile = [ZTechDeviceDatabase loadOrCreateDefaultProfile];
    }

    [self buildTopHeaderBar];
    [self buildBottomTabBar];
    [self buildMainScrollContainer];

    [self buildTab1FeaturesView];
    [self buildTab2VaultView];
    [self buildTab3LicenseView];

    [self buildToastBanner];
    [self buildVaultEditorModal];
    [self buildLockScreenOverlay];

    [self onSwitchChanged:nil];
    [self refreshModelTierSegments];
    [self refreshUIWithCurrentProfile];
    [self reloadVaultListUI];
    [self updateLicenseUIState];
    [self switchToTab:ZTechMainTabFeatures animated:NO];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppBecameActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [self onAppBecameActive];
}

- (void)onAppBecameActive {
    [ZTechLicenseManager refreshSavedLicenseInBackgroundWithCompletion:^(BOOL isValid, NSString * _Nonnull statusText) {
        [self updateLicenseUIState];
        if (!isValid && self.lockStatusMsgLabel) {
            self.lockStatusMsgLabel.text = statusText;
        }
    }];
}

#pragma mark - Theme Palette & SF Symbol Helpers

- (UIColor *)surfaceCardColor {
    return [UIColor colorWithRed:0.08 green:0.09 blue:0.08 alpha:1.0];
}

- (UIColor *)surfaceInsetColor {
    return [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
}

- (UIColor *)borderSubtleColor {
    return [UIColor colorWithRed:0.18 green:0.20 blue:0.16 alpha:1.0];
}

- (UIColor *)goldAccentColor {
    return [UIColor colorWithRed:0.88 green:0.78 blue:0.52 alpha:1.0];
}

- (UIColor *)creamPrimaryColor {
    return [UIColor colorWithRed:0.93 green:0.88 blue:0.73 alpha:1.0];
}

- (UIColor *)darkInkColor {
    return [UIColor colorWithRed:0.12 green:0.11 blue:0.08 alpha:1.0];
}

- (UIColor *)mutedTextColor {
    return [UIColor colorWithRed:0.60 green:0.63 blue:0.60 alpha:1.0];
}

- (UIColor *)emeraldColor {
    return [UIColor colorWithRed:0.30 green:0.85 blue:0.50 alpha:1.0];
}

- (UIColor *)dangerCoralColor {
    return [UIColor colorWithRed:0.95 green:0.42 blue:0.40 alpha:1.0];
}

- (UIImage *)sfSymbol:(NSString *)name size:(CGFloat)ptSize weight:(UIImageSymbolWeight)weight {
    if ([UIImage respondsToSelector:@selector(systemImageNamed:withConfiguration:)]) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:ptSize weight:weight];
        UIImage *img = [UIImage systemImageNamed:name withConfiguration:cfg];
        if (img) return img;
    }
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        return [UIImage systemImageNamed:name];
    }
    return nil;
}

- (void)styleButton:(UIButton *)btn
              title:(NSString *)title
             symbol:(NSString *)symbolName
          tintColor:(UIColor *)tintColor
               font:(UIFont *)font {
    [btn setTitleColor:tintColor forState:UIControlStateNormal];
    btn.titleLabel.font = font;
    btn.tintColor = tintColor;
    UIImage *img = (symbolName.length > 0) ? [self sfSymbol:symbolName size:(font.pointSize - 1.0) weight:UIFontWeightSemibold] : nil;
    if (img) {
        [btn setImage:img forState:UIControlStateNormal];
        [btn setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    } else {
        [btn setImage:nil forState:UIControlStateNormal];
        [btn setTitle:title forState:UIControlStateNormal];
    }
}

- (UIView *)createCardView {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self surfaceCardColor];
    card.layer.cornerRadius = 18.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self borderSubtleColor].CGColor;
    return card;
}

- (UIView *)createSectionHeaderWithSymbol:(NSString *)symbolName title:(NSString *)title rightView:(UIView *)rightView {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [UIColor colorWithRed:0.14 green:0.13 blue:0.09 alpha:1.0];
    iconBadge.layer.cornerRadius = 9.0;
    iconBadge.layer.borderWidth = 1.0;
    iconBadge.layer.borderColor = [UIColor colorWithRed:0.32 green:0.28 blue:0.18 alpha:1.0].CGColor;

    UIImageView *iv = [[UIImageView alloc] initWithImage:[self sfSymbol:symbolName size:14.0 weight:UIFontWeightBold]];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.tintColor = [self goldAccentColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:iv];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightHeavy];
    lbl.textColor = [self goldAccentColor];

    [header addSubview:iconBadge];
    [header addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
        [iconBadge.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [iconBadge.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [iconBadge.widthAnchor constraintEqualToConstant:30.0],
        [iconBadge.heightAnchor constraintEqualToConstant:30.0],
        [header.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],

        [iv.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],

        [lbl.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:10.0],
        [lbl.centerYAnchor constraintEqualToAnchor:header.centerYAnchor]
    ]];

    if (rightView) {
        rightView.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:rightView];
        [NSLayoutConstraint activateConstraints:@[
            [rightView.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
            [rightView.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
            [lbl.trailingAnchor constraintLessThanOrEqualToAnchor:rightView.leadingAnchor constant:-8.0]
        ]];
    } else {
        [lbl.trailingAnchor constraintEqualToAnchor:header.trailingAnchor].active = YES;
    }

    return header;
}

#pragma mark - Top Header Bar & Toast Banner

- (void)buildTopHeaderBar {
    self.topHeaderBar = [[UIView alloc] init];
    self.topHeaderBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.topHeaderBar.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
    [self.view addSubview:self.topHeaderBar];

    UIView *bottomLine = [[UIView alloc] init];
    bottomLine.translatesAutoresizingMaskIntoConstraints = NO;
    bottomLine.backgroundColor = [self borderSubtleColor];
    [self.topHeaderBar addSubview:bottomLine];

    UIView *logoBox = [[UIView alloc] init];
    logoBox.translatesAutoresizingMaskIntoConstraints = NO;
    logoBox.backgroundColor = [UIColor colorWithRed:0.12 green:0.13 blue:0.10 alpha:1.0];
    logoBox.layer.cornerRadius = 11.0;
    logoBox.layer.borderWidth = 1.4;
    logoBox.layer.borderColor = [self goldAccentColor].CGColor;

    UIImageView *shieldIv = [[UIImageView alloc] initWithImage:[self sfSymbol:@"shield.lefthalf.filled" size:18.0 weight:UIFontWeightBold]];
    shieldIv.translatesAutoresizingMaskIntoConstraints = NO;
    shieldIv.tintColor = [self goldAccentColor];
    [logoBox addSubview:shieldIv];

    UILabel *appTitle = [[UILabel alloc] init];
    appTitle.translatesAutoresizingMaskIntoConstraints = NO;
    appTitle.text = @"gaulmt -Tech";
    appTitle.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightHeavy];
    appTitle.textColor = [UIColor whiteColor];

    UILabel *appSub = [[UILabel alloc] init];
    appSub.translatesAutoresizingMaskIntoConstraints = NO;
    appSub.text = @"iOS Identity & Zalo Vault · v4.7";
    appSub.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    appSub.textColor = [self mutedTextColor];

    self.headerLicenseBadge = [[UIView alloc] init];
    self.headerLicenseBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLicenseBadge.backgroundColor = [UIColor colorWithRed:0.08 green:0.16 blue:0.10 alpha:1.0];
    self.headerLicenseBadge.layer.cornerRadius = 13.0;
    self.headerLicenseBadge.layer.borderWidth = 1.0;
    self.headerLicenseBadge.layer.borderColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.25 alpha:1.0].CGColor;

    self.headerLicenseIcon = [[UIImageView alloc] initWithImage:[self sfSymbol:@"checkmark.shield.fill" size:12.0 weight:UIFontWeightBold]];
    self.headerLicenseIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLicenseIcon.tintColor = [self emeraldColor];

    self.headerLicenseText = [[UILabel alloc] init];
    self.headerLicenseText.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLicenseText.text = @"PRO ACTIVE";
    self.headerLicenseText.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightHeavy];
    self.headerLicenseText.textColor = [self emeraldColor];

    [self.headerLicenseBadge addSubview:self.headerLicenseIcon];
    [self.headerLicenseBadge addSubview:self.headerLicenseText];

    [self.topHeaderBar addSubview:logoBox];
    [self.topHeaderBar addSubview:appTitle];
    [self.topHeaderBar addSubview:appSub];
    [self.topHeaderBar addSubview:self.headerLicenseBadge];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.topHeaderBar.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.topHeaderBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topHeaderBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topHeaderBar.heightAnchor constraintEqualToConstant:58.0],

        [bottomLine.leadingAnchor constraintEqualToAnchor:self.topHeaderBar.leadingAnchor],
        [bottomLine.trailingAnchor constraintEqualToAnchor:self.topHeaderBar.trailingAnchor],
        [bottomLine.bottomAnchor constraintEqualToAnchor:self.topHeaderBar.bottomAnchor],
        [bottomLine.heightAnchor constraintEqualToConstant:1.0],

        [logoBox.leadingAnchor constraintEqualToAnchor:self.topHeaderBar.leadingAnchor constant:16.0],
        [logoBox.centerYAnchor constraintEqualToAnchor:self.topHeaderBar.centerYAnchor],
        [logoBox.widthAnchor constraintEqualToConstant:38.0],
        [logoBox.heightAnchor constraintEqualToConstant:38.0],

        [shieldIv.centerXAnchor constraintEqualToAnchor:logoBox.centerXAnchor],
        [shieldIv.centerYAnchor constraintEqualToAnchor:logoBox.centerYAnchor],

        [appTitle.topAnchor constraintEqualToAnchor:logoBox.topAnchor constant:-1.0],
        [appTitle.leadingAnchor constraintEqualToAnchor:logoBox.trailingAnchor constant:11.0],

        [appSub.topAnchor constraintEqualToAnchor:appTitle.bottomAnchor constant:1.0],
        [appSub.leadingAnchor constraintEqualToAnchor:logoBox.trailingAnchor constant:11.0],

        [self.headerLicenseBadge.trailingAnchor constraintEqualToAnchor:self.topHeaderBar.trailingAnchor constant:-16.0],
        [self.headerLicenseBadge.centerYAnchor constraintEqualToAnchor:self.topHeaderBar.centerYAnchor],
        [self.headerLicenseBadge.heightAnchor constraintEqualToConstant:26.0],

        [self.headerLicenseIcon.leadingAnchor constraintEqualToAnchor:self.headerLicenseBadge.leadingAnchor constant:9.0],
        [self.headerLicenseIcon.centerYAnchor constraintEqualToAnchor:self.headerLicenseBadge.centerYAnchor],

        [self.headerLicenseText.leadingAnchor constraintEqualToAnchor:self.headerLicenseIcon.trailingAnchor constant:5.0],
        [self.headerLicenseText.trailingAnchor constraintEqualToAnchor:self.headerLicenseBadge.trailingAnchor constant:-10.0],
        [self.headerLicenseText.centerYAnchor constraintEqualToAnchor:self.headerLicenseBadge.centerYAnchor]
    ]];
}

- (void)buildToastBanner {
    self.toastBannerView = [[UIView alloc] init];
    self.toastBannerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastBannerView.backgroundColor = [UIColor colorWithRed:0.10 green:0.16 blue:0.11 alpha:0.97];
    self.toastBannerView.layer.cornerRadius = 12.0;
    self.toastBannerView.layer.borderWidth = 1.2;
    self.toastBannerView.layer.borderColor = [self goldAccentColor].CGColor;
    self.toastBannerView.hidden = YES;
    self.toastBannerView.alpha = 0.0;
    [self.view addSubview:self.toastBannerView];

    self.toastBannerLabel = [[UILabel alloc] init];
    self.toastBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastBannerLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    self.toastBannerLabel.textColor = [UIColor whiteColor];
    self.toastBannerLabel.textAlignment = NSTextAlignmentCenter;
    self.toastBannerLabel.numberOfLines = 2;
    [self.toastBannerView addSubview:self.toastBannerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.toastBannerView.topAnchor constraintEqualToAnchor:self.topHeaderBar.bottomAnchor constant:8.0],
        [self.toastBannerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.toastBannerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],

        [self.toastBannerLabel.topAnchor constraintEqualToAnchor:self.toastBannerView.topAnchor constant:10.0],
        [self.toastBannerLabel.leadingAnchor constraintEqualToAnchor:self.toastBannerView.leadingAnchor constant:12.0],
        [self.toastBannerLabel.trailingAnchor constraintEqualToAnchor:self.toastBannerView.trailingAnchor constant:-12.0],
        [self.toastBannerLabel.bottomAnchor constraintEqualToAnchor:self.toastBannerView.bottomAnchor constant:-10.0]
    ]];
}

- (void)showToast:(NSString *)message isError:(BOOL)isError {
    self.toastBannerLabel.text = message;
    self.toastBannerView.backgroundColor = isError
        ? [UIColor colorWithRed:0.24 green:0.09 blue:0.09 alpha:0.97]
        : [UIColor colorWithRed:0.09 green:0.16 blue:0.11 alpha:0.97];
    self.toastBannerView.layer.borderColor = isError ? [self dangerCoralColor].CGColor : [self goldAccentColor].CGColor;
    self.toastBannerView.hidden = NO;

    [UIView animateWithDuration:0.2 animations:^{
        self.toastBannerView.alpha = 1.0;
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.toastBannerView.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (self.toastBannerView.alpha == 0.0) {
                self.toastBannerView.hidden = YES;
            }
        }];
    });
}

#pragma mark - Bottom 3-Tab Navigation Bar

- (void)buildBottomTabBar {
    self.bottomTabBar = [[UIView alloc] init];
    self.bottomTabBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomTabBar.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.06 alpha:1.0];
    [self.view addSubview:self.bottomTabBar];

    UIView *topLine = [[UIView alloc] init];
    topLine.translatesAutoresizingMaskIntoConstraints = NO;
    topLine.backgroundColor = [self borderSubtleColor];
    [self.bottomTabBar addSubview:topLine];

    UIStackView *tabsRow = [[UIStackView alloc] init];
    tabsRow.translatesAutoresizingMaskIntoConstraints = NO;
    tabsRow.axis = UILayoutConstraintAxisHorizontal;
    tabsRow.distribution = UIStackViewDistributionFillEqually;
    [self.bottomTabBar addSubview:tabsRow];

    NSArray<NSDictionary *> *tabDefs = @[
        @{@"title": @"Tính năng", @"symbol": @"cpu.fill"},
        @{@"title": @"Kho Acc & Proxy", @"symbol": @"archivebox.fill"},
        @{@"title": @"Bản quyền", @"symbol": @"key.fill"}
    ];

    NSMutableArray<UIControl *> *btns = [NSMutableArray array];
    NSMutableArray<UIImageView *> *icons = [NSMutableArray array];
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    NSMutableArray<UIView *> *indicators = [NSMutableArray array];

    for (NSInteger i = 0; i < tabDefs.count; i++) {
        NSDictionary *def = tabDefs[i];
        UIControl *tabCtrl = [[UIControl alloc] init];
        tabCtrl.translatesAutoresizingMaskIntoConstraints = NO;
        tabCtrl.tag = i;
        [tabCtrl addTarget:self action:@selector(onTapTabBarItem:) forControlEvents:UIControlEventTouchUpInside];

        UIView *pillIndicator = [[UIView alloc] init];
        pillIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        pillIndicator.backgroundColor = [self goldAccentColor];
        pillIndicator.layer.cornerRadius = 1.5;
        [tabCtrl addSubview:pillIndicator];

        UIImageView *iv = [[UIImageView alloc] initWithImage:[self sfSymbol:def[@"symbol"] size:19.0 weight:UIFontWeightSemibold]];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [tabCtrl addSubview:iv];

        UILabel *lbl = [[UILabel alloc] init];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        lbl.text = def[@"title"];
        lbl.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
        lbl.textAlignment = NSTextAlignmentCenter;
        [tabCtrl addSubview:lbl];

        [NSLayoutConstraint activateConstraints:@[
            [pillIndicator.topAnchor constraintEqualToAnchor:tabCtrl.topAnchor],
            [pillIndicator.centerXAnchor constraintEqualToAnchor:tabCtrl.centerXAnchor],
            [pillIndicator.widthAnchor constraintEqualToConstant:36.0],
            [pillIndicator.heightAnchor constraintEqualToConstant:3.0],

            [iv.topAnchor constraintEqualToAnchor:tabCtrl.topAnchor constant:9.0],
            [iv.centerXAnchor constraintEqualToAnchor:tabCtrl.centerXAnchor],
            [iv.widthAnchor constraintEqualToConstant:24.0],
            [iv.heightAnchor constraintEqualToConstant:22.0],

            [lbl.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:4.0],
            [lbl.leadingAnchor constraintEqualToAnchor:tabCtrl.leadingAnchor constant:4.0],
            [lbl.trailingAnchor constraintEqualToAnchor:tabCtrl.trailingAnchor constant:-4.0]
        ]];

        [tabsRow addArrangedSubview:tabCtrl];
        [btns addObject:tabCtrl];
        [icons addObject:iv];
        [labels addObject:lbl];
        [indicators addObject:pillIndicator];
    }

    self.tabButtons = btns;
    self.tabIcons = icons;
    self.tabLabels = labels;
    self.tabIndicators = indicators;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomTabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomTabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomTabBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomTabBar.topAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-58.0],

        [topLine.topAnchor constraintEqualToAnchor:self.bottomTabBar.topAnchor],
        [topLine.leadingAnchor constraintEqualToAnchor:self.bottomTabBar.leadingAnchor],
        [topLine.trailingAnchor constraintEqualToAnchor:self.bottomTabBar.trailingAnchor],
        [topLine.heightAnchor constraintEqualToConstant:1.0],

        [tabsRow.topAnchor constraintEqualToAnchor:self.bottomTabBar.topAnchor],
        [tabsRow.leadingAnchor constraintEqualToAnchor:self.bottomTabBar.leadingAnchor],
        [tabsRow.trailingAnchor constraintEqualToAnchor:self.bottomTabBar.trailingAnchor],
        [tabsRow.heightAnchor constraintEqualToConstant:58.0]
    ]];
}

- (void)onTapTabBarItem:(UIControl *)sender {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self switchToTab:(ZTechMainTab)sender.tag animated:YES];
}

- (void)switchToTab:(ZTechMainTab)tab animated:(BOOL)animated {
    self.activeTab = tab;
    for (NSInteger i = 0; i < self.tabIcons.count; i++) {
        BOOL selected = (i == tab);
        self.tabIcons[i].tintColor = selected ? [self goldAccentColor] : [self mutedTextColor];
        self.tabLabels[i].textColor = selected ? [self goldAccentColor] : [self mutedTextColor];
        self.tabIndicators[i].hidden = !selected;
    }

    self.tabFeaturesStack.hidden = (tab != ZTechMainTabFeatures);
    self.tabVaultStack.hidden = (tab != ZTechMainTabVault);
    self.tabLicenseStack.hidden = (tab != ZTechMainTabLicense);

    [self.scrollView setContentOffset:CGPointZero animated:NO];
    if (tab == ZTechMainTabVault) {
        [self reloadVaultListUI];
    } else if (tab == ZTechMainTabLicense) {
        [self updateLicenseUIState];
    }
}

#pragma mark - Main Scroll Container

- (void)buildMainScrollContainer {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 14.0;
    [self.scrollView addSubview:self.contentStack];

    self.tabFeaturesStack = [[UIStackView alloc] init];
    self.tabFeaturesStack.axis = UILayoutConstraintAxisVertical;
    self.tabFeaturesStack.spacing = 14.0;

    self.tabVaultStack = [[UIStackView alloc] init];
    self.tabVaultStack.axis = UILayoutConstraintAxisVertical;
    self.tabVaultStack.spacing = 14.0;

    self.tabLicenseStack = [[UIStackView alloc] init];
    self.tabLicenseStack.axis = UILayoutConstraintAxisVertical;
    self.tabLicenseStack.spacing = 14.0;

    [self.contentStack addArrangedSubview:self.tabFeaturesStack];
    [self.contentStack addArrangedSubview:self.tabVaultStack];
    [self.contentStack addArrangedSubview:self.tabLicenseStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.topHeaderBar.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomTabBar.topAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:14.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-24.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32.0]
    ]];
}

#pragma mark - TAB 1: Features (Device Identity, Actions, Switches, Status)

- (UIView *)createSpecTileWithSymbol:(NSString *)symbol title:(NSString *)title outValueLabel:(UILabel **)outVal {
    UIView *tile = [[UIView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.backgroundColor = [self surfaceInsetColor];
    tile.layer.cornerRadius = 12.0;
    tile.layer.borderWidth = 1.0;
    tile.layer.borderColor = [self borderSubtleColor].CGColor;

    UIImageView *iv = [[UIImageView alloc] initWithImage:[self sfSymbol:symbol size:13.0 weight:UIFontWeightSemibold]];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.tintColor = [self goldAccentColor];

    UILabel *tLbl = [[UILabel alloc] init];
    tLbl.translatesAutoresizingMaskIntoConstraints = NO;
    tLbl.text = title;
    tLbl.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    tLbl.textColor = [self mutedTextColor];

    UILabel *vLbl = [[UILabel alloc] init];
    vLbl.translatesAutoresizingMaskIntoConstraints = NO;
    vLbl.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    vLbl.textColor = [UIColor whiteColor];
    vLbl.adjustsFontSizeToFitWidth = YES;
    vLbl.minimumScaleFactor = 0.8;

    [tile addSubview:iv];
    [tile addSubview:tLbl];
    [tile addSubview:vLbl];

    [NSLayoutConstraint activateConstraints:@[
        [tile.heightAnchor constraintEqualToConstant:56.0],
        [iv.topAnchor constraintEqualToAnchor:tile.topAnchor constant:10.0],
        [iv.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:11.0],
        [iv.widthAnchor constraintEqualToConstant:15.0],
        [iv.heightAnchor constraintEqualToConstant:15.0],

        [tLbl.centerYAnchor constraintEqualToAnchor:iv.centerYAnchor],
        [tLbl.leadingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:6.0],
        [tLbl.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-8.0],

        [vLbl.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:5.0],
        [vLbl.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:11.0],
        [vLbl.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-8.0]
    ]];

    if (outVal) *outVal = vLbl;
    return tile;
}

- (void)buildTab1FeaturesView {
    // 1. Device Identity Card
    UIView *idCard = [self createCardView];
    UIStackView *idStack = [[UIStackView alloc] init];
    idStack.translatesAutoresizingMaskIntoConstraints = NO;
    idStack.axis = UILayoutConstraintAxisVertical;
    idStack.spacing = 12.0;
    [idCard addSubview:idStack];

    self.btnCopyReport = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnCopyReport.backgroundColor = [UIColor colorWithRed:0.14 green:0.15 blue:0.12 alpha:1.0];
    self.btnCopyReport.layer.cornerRadius = 8.0;
    self.btnCopyReport.layer.borderWidth = 1.0;
    self.btnCopyReport.layer.borderColor = [self borderSubtleColor].CGColor;
    self.btnCopyReport.contentEdgeInsets = UIEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
    [self styleButton:self.btnCopyReport
                title:@"Sao chép"
               symbol:@"doc.on.doc.fill"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
    [self.btnCopyReport addTarget:self action:@selector(onTapCopyReport) forControlEvents:UIControlEventTouchUpInside];

    UIView *idHeader = [self createSectionHeaderWithSymbol:@"iphone"
                                                     title:@"CẤU HÌNH MÁY ẢO ĐANG CHẠY"
                                                 rightView:self.btnCopyReport];
    [idStack addArrangedSubview:idHeader];

    // Hero Model Box
    UIView *heroBox = [[UIView alloc] init];
    heroBox.translatesAutoresizingMaskIntoConstraints = NO;
    heroBox.backgroundColor = [self surfaceInsetColor];
    heroBox.layer.cornerRadius = 14.0;
    heroBox.layer.borderWidth = 1.0;
    heroBox.layer.borderColor = [UIColor colorWithRed:0.25 green:0.23 blue:0.15 alpha:1.0].CGColor;

    self.modelHeroLabel = [[UILabel alloc] init];
    self.modelHeroLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.modelHeroLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightHeavy];
    self.modelHeroLabel.textColor = [UIColor whiteColor];
    self.modelHeroLabel.adjustsFontSizeToFitWidth = YES;

    self.machineBadgeLabel = [[UILabel alloc] init];
    self.machineBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.machineBadgeLabel.backgroundColor = [UIColor colorWithRed:0.16 green:0.15 blue:0.10 alpha:1.0];
    self.machineBadgeLabel.layer.cornerRadius = 6.0;
    self.machineBadgeLabel.layer.masksToBounds = YES;
    self.machineBadgeLabel.font = [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightBold];
    self.machineBadgeLabel.textColor = [self goldAccentColor];
    self.machineBadgeLabel.textAlignment = NSTextAlignmentCenter;

    self.iosBadgeLabel = [[UILabel alloc] init];
    self.iosBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.iosBadgeLabel.backgroundColor = [UIColor colorWithRed:0.10 green:0.18 blue:0.12 alpha:1.0];
    self.iosBadgeLabel.layer.cornerRadius = 6.0;
    self.iosBadgeLabel.layer.masksToBounds = YES;
    self.iosBadgeLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    self.iosBadgeLabel.textColor = [self emeraldColor];
    self.iosBadgeLabel.textAlignment = NSTextAlignmentCenter;

    self.uuidMonoLabel = [[UILabel alloc] init];
    self.uuidMonoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.uuidMonoLabel.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.uuidMonoLabel.textColor = [self mutedTextColor];
    self.uuidMonoLabel.adjustsFontSizeToFitWidth = YES;
    self.uuidMonoLabel.minimumScaleFactor = 0.7;

    [heroBox addSubview:self.modelHeroLabel];
    [heroBox addSubview:self.machineBadgeLabel];
    [heroBox addSubview:self.iosBadgeLabel];
    [heroBox addSubview:self.uuidMonoLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.modelHeroLabel.topAnchor constraintEqualToAnchor:heroBox.topAnchor constant:12.0],
        [self.modelHeroLabel.leadingAnchor constraintEqualToAnchor:heroBox.leadingAnchor constant:14.0],

        [self.iosBadgeLabel.centerYAnchor constraintEqualToAnchor:self.modelHeroLabel.centerYAnchor],
        [self.iosBadgeLabel.trailingAnchor constraintEqualToAnchor:heroBox.trailingAnchor constant:-12.0],
        [self.iosBadgeLabel.heightAnchor constraintEqualToConstant:22.0],

        [self.machineBadgeLabel.centerYAnchor constraintEqualToAnchor:self.modelHeroLabel.centerYAnchor],
        [self.machineBadgeLabel.trailingAnchor constraintEqualToAnchor:self.iosBadgeLabel.leadingAnchor constant:-6.0],
        [self.machineBadgeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.modelHeroLabel.trailingAnchor constant:8.0],
        [self.machineBadgeLabel.heightAnchor constraintEqualToConstant:22.0],

        [self.uuidMonoLabel.topAnchor constraintEqualToAnchor:self.modelHeroLabel.bottomAnchor constant:6.0],
        [self.uuidMonoLabel.leadingAnchor constraintEqualToAnchor:heroBox.leadingAnchor constant:14.0],
        [self.uuidMonoLabel.trailingAnchor constraintEqualToAnchor:heroBox.trailingAnchor constant:-14.0],
        [self.uuidMonoLabel.bottomAnchor constraintEqualToAnchor:heroBox.bottomAnchor constant:-12.0]
    ]];
    [idStack addArrangedSubview:heroBox];

    // 2x2 Spec Grid
    UILabel *cVal = nil; UILabel *sVal = nil; UILabel *nVal = nil; UILabel *bVal = nil;
    UIView *t1 = [self createSpecTileWithSymbol:@"cpu" title:@"CHIP & BỘ NHỚ RAM" outValueLabel:&cVal];
    UIView *t2 = [self createSpecTileWithSymbol:@"iphone" title:@"ĐỘ PHÂN GIẢI MÀN" outValueLabel:&sVal];
    UIView *t3 = [self createSpecTileWithSymbol:@"wifi" title:@"NHÀ MẠNG & VỊ TRÍ" outValueLabel:&nVal];
    UIView *t4 = [self createSpecTileWithSymbol:@"battery.100" title:@"PIN & DANH BẠ ẢO" outValueLabel:&bVal];
    self.specChipValueLabel = cVal;
    self.specScreenValueLabel = sVal;
    self.specNetValueLabel = nVal;
    self.specBatValueLabel = bVal;

    UIStackView *gridRow1 = [[UIStackView alloc] initWithArrangedSubviews:@[t1, t2]];
    gridRow1.axis = UILayoutConstraintAxisHorizontal;
    gridRow1.distribution = UIStackViewDistributionFillEqually;
    gridRow1.spacing = 8.0;

    UIStackView *gridRow2 = [[UIStackView alloc] initWithArrangedSubviews:@[t3, t4]];
    gridRow2.axis = UILayoutConstraintAxisHorizontal;
    gridRow2.distribution = UIStackViewDistributionFillEqually;
    gridRow2.spacing = 8.0;

    [idStack addArrangedSubview:gridRow1];
    [idStack addArrangedSubview:gridRow2];

    // 3-Button Model Tier Segmented Bar
    UILabel *tierCaption = [[UILabel alloc] init];
    tierCaption.text = @"CHỌN PHÂN KHÚC ĐỜI MÁY KHI RANDOM:";
    tierCaption.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    tierCaption.textColor = [self mutedTextColor];
    [idStack addArrangedSubview:tierCaption];

    UIStackView *segRow = [[UIStackView alloc] init];
    segRow.axis = UILayoutConstraintAxisHorizontal;
    segRow.distribution = UIStackViewDistributionFillEqually;
    segRow.spacing = 6.0;
    [segRow.heightAnchor constraintEqualToConstant:36.0].active = YES;

    NSArray<NSString *> *segTitles = @[@"Chỉ iPhone 16", @"Đời Cao 14–16", @"Tất cả 8–16"];
    NSArray<NSNumber *> *segTags = @[@(ZTechModelTierIPhone16), @(ZTechModelTierHighEnd), @(ZTechModelTierAll)];
    NSMutableArray<UIButton *> *segBtns = [NSMutableArray array];

    for (NSInteger i = 0; i < segTitles.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = [segTags[i] integerValue];
        b.layer.cornerRadius = 9.0;
        b.layer.borderWidth = 1.0;
        [b setTitle:segTitles[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        [b addTarget:self action:@selector(onTapSelectModelTierSegment:) forControlEvents:UIControlEventTouchUpInside];
        [segRow addArrangedSubview:b];
        [segBtns addObject:b];
    }
    self.tierSegmentButtons = segBtns;
    [idStack addArrangedSubview:segRow];

    [NSLayoutConstraint activateConstraints:@[
        [idStack.topAnchor constraintEqualToAnchor:idCard.topAnchor constant:16.0],
        [idStack.leadingAnchor constraintEqualToAnchor:idCard.leadingAnchor constant:16.0],
        [idStack.trailingAnchor constraintEqualToAnchor:idCard.trailingAnchor constant:-16.0],
        [idStack.bottomAnchor constraintEqualToAnchor:idCard.bottomAnchor constant:-16.0]
    ]];
    [self.tabFeaturesStack addArrangedSubview:idCard];

    // 2. Primary Action Card
    UIView *actCard = [self createCardView];
    UIStackView *actStack = [[UIStackView alloc] init];
    actStack.translatesAutoresizingMaskIntoConstraints = NO;
    actStack.axis = UILayoutConstraintAxisVertical;
    actStack.spacing = 10.0;
    [actCard addSubview:actStack];

    UIView *actHeader = [self createSectionHeaderWithSymbol:@"arrow.triangle.2.circlepath"
                                                      title:@"THAO TÁC NHANH"
                                                  rightView:nil];
    [actStack addArrangedSubview:actHeader];

    self.changeDeviceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeDeviceButton.backgroundColor = [self creamPrimaryColor];
    self.changeDeviceButton.layer.cornerRadius = 14.0;
    [self styleButton:self.changeDeviceButton
                title:@"Đổi cấu hình máy ảo mới (Change Device)"
               symbol:@"arrow.triangle.2.circlepath"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:15.5 weight:UIFontWeightHeavy]];
    [self.changeDeviceButton.heightAnchor constraintEqualToConstant:50.0].active = YES;
    [self.changeDeviceButton addTarget:self action:@selector(onTapChangeDevice) forControlEvents:UIControlEventTouchUpInside];

    self.cleanResetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cleanResetButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.13 blue:0.08 alpha:1.0];
    self.cleanResetButton.layer.cornerRadius = 14.0;
    self.cleanResetButton.layer.borderWidth = 1.2;
    self.cleanResetButton.layer.borderColor = [self goldAccentColor].CGColor;
    [self styleButton:self.cleanResetButton
                title:@"Làm mới dữ liệu Zalo & Tạo phiên mới"
               symbol:@"arrow.counterclockwise"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:15.0 weight:UIFontWeightBold]];
    [self.cleanResetButton.heightAnchor constraintEqualToConstant:48.0].active = YES;
    [self.cleanResetButton addTarget:self action:@selector(onTapCleanReset) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *subActRow = [[UIStackView alloc] init];
    subActRow.axis = UILayoutConstraintAxisHorizontal;
    subActRow.distribution = UIStackViewDistributionFillEqually;
    subActRow.spacing = 10.0;
    [subActRow.heightAnchor constraintEqualToConstant:44.0].active = YES;

    self.syncIPButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.syncIPButton.backgroundColor = [self surfaceInsetColor];
    self.syncIPButton.layer.cornerRadius = 12.0;
    self.syncIPButton.layer.borderWidth = 1.0;
    self.syncIPButton.layer.borderColor = [self borderSubtleColor].CGColor;
    [self styleButton:self.syncIPButton
                title:@"Đồng bộ vị trí IP"
               symbol:@"location.fill"
            tintColor:[UIColor whiteColor]
                 font:[UIFont systemFontOfSize:13.5 weight:UIFontWeightBold]];
    [self.syncIPButton addTarget:self action:@selector(onTapSyncIP) forControlEvents:UIControlEventTouchUpInside];

    self.openZaloButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openZaloButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.16 blue:0.11 alpha:1.0];
    self.openZaloButton.layer.cornerRadius = 12.0;
    self.openZaloButton.layer.borderWidth = 1.0;
    self.openZaloButton.layer.borderColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.25 alpha:1.0].CGColor;
    [self styleButton:self.openZaloButton
                title:@"Mở ứng dụng Zalo"
               symbol:@"play.fill"
            tintColor:[self emeraldColor]
                 font:[UIFont systemFontOfSize:13.5 weight:UIFontWeightBold]];
    [self.openZaloButton addTarget:self action:@selector(onTapQuickLaunchZalo) forControlEvents:UIControlEventTouchUpInside];

    [subActRow addArrangedSubview:self.syncIPButton];
    [subActRow addArrangedSubview:self.openZaloButton];

    [actStack addArrangedSubview:self.changeDeviceButton];
    [actStack addArrangedSubview:self.cleanResetButton];
    [actStack addArrangedSubview:subActRow];

    [NSLayoutConstraint activateConstraints:@[
        [actStack.topAnchor constraintEqualToAnchor:actCard.topAnchor constant:16.0],
        [actStack.leadingAnchor constraintEqualToAnchor:actCard.leadingAnchor constant:16.0],
        [actStack.trailingAnchor constraintEqualToAnchor:actCard.trailingAnchor constant:-16.0],
        [actStack.bottomAnchor constraintEqualToAnchor:actCard.bottomAnchor constant:-16.0]
    ]];
    [self.tabFeaturesStack addArrangedSubview:actCard];

    // 3. Switches Card
    UIView *swCard = [self createCardView];
    UIStackView *swStack = [[UIStackView alloc] init];
    swStack.translatesAutoresizingMaskIntoConstraints = NO;
    swStack.axis = UILayoutConstraintAxisVertical;
    swStack.spacing = 10.0;
    [swCard addSubview:swStack];

    UIView *swHeader = [self createSectionHeaderWithSymbol:@"slider.horizontal.3"
                                                     title:@"TUỲ CHỈNH CHẾ ĐỘ FAKE"
                                                 rightView:nil];
    [swStack addArrangedSubview:swHeader];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL defLock = [prefs boolForKey:@"ZTech_LockModel"];
    BOOL defRespring = [prefs boolForKey:@"ZTech_Respring"];
    BOOL defScreen = [prefs boolForKey:@"ZTech_SameScreen"];
    BOOL defChip = [prefs boolForKey:@"ZTech_MatchChip"];

    UISwitch *sw1 = nil; UILabel *sub1 = nil;
    UIView *row1 = [self createSwitchRowWithSymbol:@"lock.fill"
                                             title:@"Khoá đời máy · Giữ model thật"
                                          subtitle:@"OFF: Cho phép đổi sang iPhone 16 Series"
                                         isDefault:defLock
                                         outSwitch:&sw1
                                       outSubLabel:&sub1];
    self.lockModelSwitch = sw1; self.lockModelSubLabel = sub1;

    UISwitch *sw2 = nil; UILabel *sub2 = nil;
    UIView *row2 = [self createSwitchRowWithSymbol:@"arrow.clockwise"
                                             title:@"Respring sau khi đổi máy"
                                          subtitle:@"OFF: Áp dụng tức thì không cần khởi động lại màn hình"
                                         isDefault:defRespring
                                         outSwitch:&sw2
                                       outSubLabel:&sub2];
    self.respringSwitch = sw2; self.respringSubLabel = sub2;

    UISwitch *sw3 = nil; UILabel *sub3 = nil;
    UIView *row3 = [self createSwitchRowWithSymbol:@"iphone"
                                             title:@"Giới hạn cùng kích thước màn hình"
                                          subtitle:@"OFF: Cho phép giả lập màn hình lớn của Pro Max"
                                         isDefault:defScreen
                                         outSwitch:&sw3
                                       outSubLabel:&sub3];
    self.sameScreenSwitch = sw3; self.sameScreenSubLabel = sub3;

    UISwitch *sw4 = nil; UILabel *sub4 = nil;
    UIView *row4 = [self createSwitchRowWithSymbol:@"cpu"
                                             title:@"Giới hạn cùng dung lượng RAM máy thật"
                                          subtitle:@"OFF: Cho phép giả lập Chip A18 Pro & RAM 8GB"
                                         isDefault:defChip
                                         outSwitch:&sw4
                                       outSubLabel:&sub4];
    self.matchChipSwitch = sw4; self.matchChipSubLabel = sub4;

    [swStack addArrangedSubview:row1];
    [swStack addArrangedSubview:row2];
    [swStack addArrangedSubview:row3];
    [swStack addArrangedSubview:row4];

    [NSLayoutConstraint activateConstraints:@[
        [swStack.topAnchor constraintEqualToAnchor:swCard.topAnchor constant:16.0],
        [swStack.leadingAnchor constraintEqualToAnchor:swCard.leadingAnchor constant:16.0],
        [swStack.trailingAnchor constraintEqualToAnchor:swCard.trailingAnchor constant:-16.0],
        [swStack.bottomAnchor constraintEqualToAnchor:swCard.bottomAnchor constant:-16.0]
    ]];
    [self.tabFeaturesStack addArrangedSubview:swCard];

    // 4. System Hook Check Card
    UIView *chkCard = [self createCardView];
    UIStackView *chkStack = [[UIStackView alloc] init];
    chkStack.translatesAutoresizingMaskIntoConstraints = NO;
    chkStack.axis = UILayoutConstraintAxisVertical;
    chkStack.spacing = 8.0;
    [chkCard addSubview:chkStack];

    UIView *chkHeader = [self createSectionHeaderWithSymbol:@"checkmark.circle.fill"
                                                      title:@"TRẠNG THÁI GHI HỆ THỐNG (KERNEL / HOOK)"
                                                  rightView:nil];
    self.checkDetailLabel = [[UILabel alloc] init];
    self.checkDetailLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.checkDetailLabel.textColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    self.checkDetailLabel.numberOfLines = 0;

    [chkStack addArrangedSubview:chkHeader];
    [chkStack addArrangedSubview:self.checkDetailLabel];

    [NSLayoutConstraint activateConstraints:@[
        [chkStack.topAnchor constraintEqualToAnchor:chkCard.topAnchor constant:14.0],
        [chkStack.leadingAnchor constraintEqualToAnchor:chkCard.leadingAnchor constant:16.0],
        [chkStack.trailingAnchor constraintEqualToAnchor:chkCard.trailingAnchor constant:-16.0],
        [chkStack.bottomAnchor constraintEqualToAnchor:chkCard.bottomAnchor constant:-14.0]
    ]];
    [self.tabFeaturesStack addArrangedSubview:chkCard];
}

- (UIView *)createSwitchRowWithSymbol:(NSString *)symbol
                                title:(NSString *)title
                             subtitle:(NSString *)subtitle
                            isDefault:(BOOL)defaultOn
                            outSwitch:(UISwitch **)outSwitch
                          outSubLabel:(UILabel **)outSubLabel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [self surfaceInsetColor];
    row.layer.cornerRadius = 12.0;
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [self borderSubtleColor].CGColor;

    UIImageView *iv = [[UIImageView alloc] initWithImage:[self sfSymbol:symbol size:14.0 weight:UIFontWeightSemibold]];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.tintColor = [self goldAccentColor];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.adjustsFontSizeToFitWidth = YES;

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = subtitle;
    subLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular];
    subLabel.textColor = [self mutedTextColor];
    subLabel.numberOfLines = 0;

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.on = defaultOn;
    toggle.onTintColor = [self goldAccentColor];
    [toggle addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    [row addSubview:iv];
    [row addSubview:titleLabel];
    [row addSubview:subLabel];
    [row addSubview:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [iv.topAnchor constraintEqualToAnchor:row.topAnchor constant:12.0],
        [iv.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12.0],
        [iv.widthAnchor constraintEqualToConstant:16.0],
        [iv.heightAnchor constraintEqualToConstant:16.0],

        [titleLabel.centerYAnchor constraintEqualToAnchor:iv.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:8.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-10.0],

        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subLabel.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-10.0],
        [subLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10.0],

        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12.0],
        [toggle.widthAnchor constraintEqualToConstant:51.0]
    ]];

    if (outSwitch) *outSwitch = toggle;
    if (outSubLabel) *outSubLabel = subLabel;
    return row;
}

- (void)refreshModelTierSegments {
    for (UIButton *b in self.tierSegmentButtons) {
        BOOL active = (b.tag == self.currentModelTier);
        b.backgroundColor = active ? [self goldAccentColor] : [self surfaceInsetColor];
        b.layer.borderColor = active ? [self goldAccentColor].CGColor : [self borderSubtleColor].CGColor;
        [b setTitleColor:(active ? [self darkInkColor] : [UIColor colorWithWhite:0.82 alpha:1.0]) forState:UIControlStateNormal];
    }
}

- (void)onTapSelectModelTierSegment:(UIButton *)sender {
    self.currentModelTier = (ZTechModelTierFilter)sender.tag;
    [[NSUserDefaults standardUserDefaults] setInteger:self.currentModelTier forKey:@"ZTech_ModelTier"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self refreshModelTierSegments];
    [self onTapChangeDevice];
}

- (void)onTapQuickLaunchZalo {
    [ZTechVaultManager launchZaloApp];
}

#pragma mark - TAB 2: Vault & Proxy Manager (Kho Lưu Trữ Acc Zalo)

- (void)buildTab2VaultView {
    UIView *heroCard = [self createCardView];
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    hStack.axis = UILayoutConstraintAxisVertical;
    hStack.spacing = 12.0;
    [heroCard addSubview:hStack];

    self.vaultCountBadgeLabel = [[UILabel alloc] init];
    self.vaultCountBadgeLabel.backgroundColor = [UIColor colorWithRed:0.10 green:0.18 blue:0.12 alpha:1.0];
    self.vaultCountBadgeLabel.layer.cornerRadius = 8.0;
    self.vaultCountBadgeLabel.layer.masksToBounds = YES;
    self.vaultCountBadgeLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    self.vaultCountBadgeLabel.textColor = [self emeraldColor];
    self.vaultCountBadgeLabel.textAlignment = NSTextAlignmentCenter;

    UIView *vHeader = [self createSectionHeaderWithSymbol:@"archivebox.fill"
                                                    title:@"KHO LƯU TRỮ ACC ZALO & PROXY"
                                                rightView:self.vaultCountBadgeLabel];
    [hStack addArrangedSubview:vHeader];

    UILabel *guideLbl = [[UILabel alloc] init];
    guideLbl.text = @"Lưu trọn bộ dữ liệu phiên đăng nhập Zalo + Cấu hình máy ảo + Proxy riêng (HTTP/SOCKS5). Khi muốn vào lại Acc nào chỉ cần nhấn [Bơm & Mở Zalo].";
    guideLbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    guideLbl.textColor = [self mutedTextColor];
    guideLbl.numberOfLines = 0;
    [hStack addArrangedSubview:guideLbl];

    // Active Proxy Info Box
    UIView *proxyBanner = [[UIView alloc] init];
    proxyBanner.translatesAutoresizingMaskIntoConstraints = NO;
    proxyBanner.backgroundColor = [self surfaceInsetColor];
    proxyBanner.layer.cornerRadius = 11.0;
    proxyBanner.layer.borderWidth = 1.0;
    proxyBanner.layer.borderColor = [self borderSubtleColor].CGColor;

    UIImageView *netIv = [[UIImageView alloc] initWithImage:[self sfSymbol:@"network" size:14.0 weight:UIFontWeightBold]];
    netIv.translatesAutoresizingMaskIntoConstraints = NO;
    netIv.tintColor = [self goldAccentColor];

    self.activeProxyStatusLabel = [[UILabel alloc] init];
    self.activeProxyStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.activeProxyStatusLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    self.activeProxyStatusLabel.textColor = [UIColor whiteColor];
    self.activeProxyStatusLabel.adjustsFontSizeToFitWidth = YES;

    [proxyBanner addSubview:netIv];
    [proxyBanner addSubview:self.activeProxyStatusLabel];
    [NSLayoutConstraint activateConstraints:@[
        [proxyBanner.heightAnchor constraintEqualToConstant:38.0],
        [netIv.leadingAnchor constraintEqualToAnchor:proxyBanner.leadingAnchor constant:12.0],
        [netIv.centerYAnchor constraintEqualToAnchor:proxyBanner.centerYAnchor],
        [netIv.widthAnchor constraintEqualToConstant:16.0],
        [self.activeProxyStatusLabel.leadingAnchor constraintEqualToAnchor:netIv.trailingAnchor constant:8.0],
        [self.activeProxyStatusLabel.trailingAnchor constraintEqualToAnchor:proxyBanner.trailingAnchor constant:-12.0],
        [self.activeProxyStatusLabel.centerYAnchor constraintEqualToAnchor:proxyBanner.centerYAnchor]
    ]];
    [hStack addArrangedSubview:proxyBanner];

    // 2 Action Buttons
    UIStackView *btnRow = [[UIStackView alloc] init];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 8.0;
    btnRow.distribution = UIStackViewDistributionFillProportionally;
    [btnRow.heightAnchor constraintEqualToConstant:46.0].active = YES;

    UIButton *btnSaveAcc = [UIButton buttonWithType:UIButtonTypeSystem];
    btnSaveAcc.backgroundColor = [self creamPrimaryColor];
    btnSaveAcc.layer.cornerRadius = 12.0;
    [self styleButton:btnSaveAcc
                title:@"Lưu Acc hiện tại vào Kho"
               symbol:@"tray.and.arrow.down.fill"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:13.5 weight:UIFontWeightHeavy]];
    [btnSaveAcc addTarget:self action:@selector(onTapOpenSaveVaultModal) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnSetProxy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnSetProxy.backgroundColor = [UIColor colorWithRed:0.15 green:0.13 blue:0.08 alpha:1.0];
    btnSetProxy.layer.cornerRadius = 12.0;
    btnSetProxy.layer.borderWidth = 1.0;
    btnSetProxy.layer.borderColor = [self goldAccentColor].CGColor;
    [self styleButton:btnSetProxy
                title:@"Cài Proxy"
               symbol:@"network"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:13.0 weight:UIFontWeightBold]];
    [btnSetProxy.widthAnchor constraintEqualToConstant:114.0].active = YES;
    [btnSetProxy addTarget:self action:@selector(onTapEditCurrentSessionProxy) forControlEvents:UIControlEventTouchUpInside];

    [btnRow addArrangedSubview:btnSaveAcc];
    [btnRow addArrangedSubview:btnSetProxy];
    [hStack addArrangedSubview:btnRow];

    [NSLayoutConstraint activateConstraints:@[
        [hStack.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:16.0],
        [hStack.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:16.0],
        [hStack.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-16.0],
        [hStack.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-16.0]
    ]];
    [self.tabVaultStack addArrangedSubview:heroCard];

    // Accounts List Container
    self.vaultItemsStack = [[UIStackView alloc] init];
    self.vaultItemsStack.axis = UILayoutConstraintAxisVertical;
    self.vaultItemsStack.spacing = 12.0;
    [self.tabVaultStack addArrangedSubview:self.vaultItemsStack];
}

- (void)reloadVaultListUI {
    for (UIView *sub in self.vaultItemsStack.arrangedSubviews) {
        [self.vaultItemsStack removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }

    self.vaultAccounts = [ZTechVaultManager listSavedAccounts];
    NSString *activeId = [ZTechVaultManager activeAccountId];
    self.vaultCountBadgeLabel.text = [NSString stringWithFormat:@"  %lu Acc đã lưu  ", (unsigned long)self.vaultAccounts.count];

    if (self.currentProfile.activeProxy.length > 0) {
        self.activeProxyStatusLabel.text = [NSString stringWithFormat:@"Proxy đang chạy: %@", self.currentProfile.activeProxy];
        self.activeProxyStatusLabel.textColor = [self emeraldColor];
    } else {
        self.activeProxyStatusLabel.text = @"Mạng hiện tại: Trực tiếp (Không Proxy / 4G)";
        self.activeProxyStatusLabel.textColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    }

    if (self.vaultAccounts.count == 0) {
        UIView *emptyCard = [self createCardView];
        UIStackView *eStack = [[UIStackView alloc] init];
        eStack.translatesAutoresizingMaskIntoConstraints = NO;
        eStack.axis = UILayoutConstraintAxisVertical;
        eStack.alignment = UIStackViewAlignmentCenter;
        eStack.spacing = 8.0;
        [emptyCard addSubview:eStack];

        UIImageView *emptyIv = [[UIImageView alloc] initWithImage:[self sfSymbol:@"archivebox.fill" size:32.0 weight:UIFontWeightRegular]];
        emptyIv.tintColor = [self goldAccentColor];

        UILabel *eTitle = [[UILabel alloc] init];
        eTitle.text = @"Kho Lưu Trữ Đang Trống";
        eTitle.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightBold];
        eTitle.textColor = [UIColor whiteColor];

        UILabel *eSub = [[UILabel alloc] init];
        eSub.text = @"1. Đăng nhập tài khoản Zalo trên máy.\n2. Quay lại tab này bấm [Lưu Acc hiện tại vào Kho] và gắn Proxy (nếu cần).\n3. Từ lần sau chỉ cần bấm [Bơm & Mở Zalo] để vào lại ngay.";
        eSub.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
        eSub.textColor = [self mutedTextColor];
        eSub.textAlignment = NSTextAlignmentCenter;
        eSub.numberOfLines = 0;

        [eStack addArrangedSubview:emptyIv];
        [eStack addArrangedSubview:eTitle];
        [eStack addArrangedSubview:eSub];

        [NSLayoutConstraint activateConstraints:@[
            [eStack.topAnchor constraintEqualToAnchor:emptyCard.topAnchor constant:24.0],
            [eStack.leadingAnchor constraintEqualToAnchor:emptyCard.leadingAnchor constant:20.0],
            [eStack.trailingAnchor constraintEqualToAnchor:emptyCard.trailingAnchor constant:-20.0],
            [eStack.bottomAnchor constraintEqualToAnchor:emptyCard.bottomAnchor constant:-24.0]
        ]];
        [self.vaultItemsStack addArrangedSubview:emptyCard];
        return;
    }

    for (NSUInteger i = 0; i < self.vaultAccounts.count; i++) {
        ZTechVaultAccount *acc = self.vaultAccounts[i];
        BOOL isActive = (activeId && [activeId isEqualToString:acc.accountId]);

        UIView *itemCard = [self createCardView];
        if (isActive) {
            itemCard.layer.borderWidth = 1.4;
            itemCard.layer.borderColor = [self emeraldColor].CGColor;
        }

        UIStackView *cStack = [[UIStackView alloc] init];
        cStack.translatesAutoresizingMaskIntoConstraints = NO;
        cStack.axis = UILayoutConstraintAxisVertical;
        cStack.spacing = 10.0;
        [itemCard addSubview:cStack];

        // Top Title Row
        UIView *topRow = [[UIView alloc] init];
        topRow.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *nameLbl = [[UILabel alloc] init];
        nameLbl.translatesAutoresizingMaskIntoConstraints = NO;
        nameLbl.text = [NSString stringWithFormat:@"#%lu · %@", (unsigned long)(i + 1), acc.title];
        nameLbl.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightHeavy];
        nameLbl.textColor = [UIColor whiteColor];
        nameLbl.adjustsFontSizeToFitWidth = YES;

        UILabel *badgeLbl = [[UILabel alloc] init];
        badgeLbl.translatesAutoresizingMaskIntoConstraints = NO;
        badgeLbl.text = isActive ? @"  ĐANG DÙNG  " : [NSString stringWithFormat:@"  %@  ", acc.createdAt];
        badgeLbl.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
        badgeLbl.textColor = isActive ? [self emeraldColor] : [self mutedTextColor];
        badgeLbl.backgroundColor = isActive
            ? [UIColor colorWithRed:0.08 green:0.18 blue:0.11 alpha:1.0]
            : [self surfaceInsetColor];
        badgeLbl.layer.cornerRadius = 6.0;
        badgeLbl.layer.masksToBounds = YES;

        [topRow addSubview:nameLbl];
        [topRow addSubview:badgeLbl];
        [NSLayoutConstraint activateConstraints:@[
            [topRow.heightAnchor constraintEqualToConstant:22.0],
            [nameLbl.leadingAnchor constraintEqualToAnchor:topRow.leadingAnchor],
            [nameLbl.centerYAnchor constraintEqualToAnchor:topRow.centerYAnchor],
            [badgeLbl.trailingAnchor constraintEqualToAnchor:topRow.trailingAnchor],
            [badgeLbl.centerYAnchor constraintEqualToAnchor:topRow.centerYAnchor],
            [badgeLbl.heightAnchor constraintEqualToConstant:20.0],
            [nameLbl.trailingAnchor constraintLessThanOrEqualToAnchor:badgeLbl.leadingAnchor constant:-8.0]
        ]];
        [cStack addArrangedSubview:topRow];

        // Info Inset Box
        UIView *infoBox = [[UIView alloc] init];
        infoBox.translatesAutoresizingMaskIntoConstraints = NO;
        infoBox.backgroundColor = [self surfaceInsetColor];
        infoBox.layer.cornerRadius = 11.0;
        infoBox.layer.borderWidth = 1.0;
        infoBox.layer.borderColor = [self borderSubtleColor].CGColor;

        UIImageView *devIv = [[UIImageView alloc] initWithImage:[self sfSymbol:@"iphone" size:12.5 weight:UIFontWeightSemibold]];
        devIv.translatesAutoresizingMaskIntoConstraints = NO;
        devIv.tintColor = [self goldAccentColor];

        UILabel *devLbl = [[UILabel alloc] init];
        devLbl.translatesAutoresizingMaskIntoConstraints = NO;
        devLbl.text = [acc shortDeviceSummary];
        devLbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
        devLbl.textColor = [self goldAccentColor];
        devLbl.adjustsFontSizeToFitWidth = YES;

        UIImageView *prxIv = [[UIImageView alloc] initWithImage:[self sfSymbol:@"network" size:12.5 weight:UIFontWeightSemibold]];
        prxIv.translatesAutoresizingMaskIntoConstraints = NO;
        BOOL hasProxy = (acc.proxyString.length > 0);
        prxIv.tintColor = hasProxy ? [self emeraldColor] : [self mutedTextColor];

        UILabel *prxLbl = [[UILabel alloc] init];
        prxLbl.translatesAutoresizingMaskIntoConstraints = NO;
        prxLbl.text = hasProxy
            ? [NSString stringWithFormat:@"Proxy: %@", acc.proxyString]
            : @"Mạng trực tiếp (Không gắn Proxy / 4G)";
        prxLbl.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        prxLbl.textColor = hasProxy ? [self emeraldColor] : [self mutedTextColor];
        prxLbl.adjustsFontSizeToFitWidth = YES;

        [infoBox addSubview:devIv];
        [infoBox addSubview:devLbl];
        [infoBox addSubview:prxIv];
        [infoBox addSubview:prxLbl];

        [NSLayoutConstraint activateConstraints:@[
            [devIv.topAnchor constraintEqualToAnchor:infoBox.topAnchor constant:9.0],
            [devIv.leadingAnchor constraintEqualToAnchor:infoBox.leadingAnchor constant:10.0],
            [devIv.widthAnchor constraintEqualToConstant:15.0],
            [devLbl.centerYAnchor constraintEqualToAnchor:devIv.centerYAnchor],
            [devLbl.leadingAnchor constraintEqualToAnchor:devIv.trailingAnchor constant:7.0],
            [devLbl.trailingAnchor constraintEqualToAnchor:infoBox.trailingAnchor constant:-10.0],

            [prxIv.topAnchor constraintEqualToAnchor:devIv.bottomAnchor constant:7.0],
            [prxIv.leadingAnchor constraintEqualToAnchor:infoBox.leadingAnchor constant:10.0],
            [prxIv.widthAnchor constraintEqualToConstant:15.0],
            [prxIv.bottomAnchor constraintEqualToAnchor:infoBox.bottomAnchor constant:-9.0],
            [prxLbl.centerYAnchor constraintEqualToAnchor:prxIv.centerYAnchor],
            [prxLbl.leadingAnchor constraintEqualToAnchor:prxIv.trailingAnchor constant:7.0],
            [prxLbl.trailingAnchor constraintEqualToAnchor:infoBox.trailingAnchor constant:-10.0]
        ]];
        [cStack addArrangedSubview:infoBox];

        // Action Buttons Row
        UIStackView *actRow = [[UIStackView alloc] init];
        actRow.axis = UILayoutConstraintAxisHorizontal;
        actRow.spacing = 7.0;
        actRow.distribution = UIStackViewDistributionFillProportionally;
        [actRow.heightAnchor constraintEqualToConstant:38.0].active = YES;

        UIButton *btnOpen = [UIButton buttonWithType:UIButtonTypeSystem];
        btnOpen.tag = (NSInteger)i;
        btnOpen.backgroundColor = [self creamPrimaryColor];
        btnOpen.layer.cornerRadius = 10.0;
        [self styleButton:btnOpen
                    title:@"Bơm & Mở Zalo"
                   symbol:@"play.fill"
                tintColor:[self darkInkColor]
                     font:[UIFont systemFontOfSize:13.0 weight:UIFontWeightHeavy]];
        [btnOpen addTarget:self action:@selector(onTapRestoreAndOpenVaultAccount:) forControlEvents:UIControlEventTouchUpInside];

        UIButton *btnEdit = [UIButton buttonWithType:UIButtonTypeSystem];
        btnEdit.tag = (NSInteger)i;
        btnEdit.backgroundColor = [UIColor colorWithRed:0.15 green:0.14 blue:0.09 alpha:1.0];
        btnEdit.layer.cornerRadius = 10.0;
        btnEdit.layer.borderWidth = 1.0;
        btnEdit.layer.borderColor = [self goldAccentColor].CGColor;
        [self styleButton:btnEdit
                    title:@"Proxy / Tên"
                   symbol:@"slider.horizontal.3"
                tintColor:[self goldAccentColor]
                     font:[UIFont systemFontOfSize:12.0 weight:UIFontWeightBold]];
        [btnEdit.widthAnchor constraintEqualToConstant:106.0].active = YES;
        [btnEdit addTarget:self action:@selector(onTapEditVaultAccount:) forControlEvents:UIControlEventTouchUpInside];

        UIButton *btnDel = [UIButton buttonWithType:UIButtonTypeSystem];
        btnDel.tag = (NSInteger)i;
        BOOL isConfirmingDel = [self.pendingDeleteAccountId isEqualToString:acc.accountId];
        btnDel.backgroundColor = isConfirmingDel
            ? [UIColor colorWithRed:0.75 green:0.18 blue:0.18 alpha:1.0]
            : [UIColor colorWithRed:0.20 green:0.10 blue:0.10 alpha:1.0];
        btnDel.layer.cornerRadius = 10.0;
        [self styleButton:btnDel
                    title:(isConfirmingDel ? @"Xoá?" : @"Xoá")
                   symbol:@"trash.fill"
                tintColor:[UIColor colorWithRed:1.0 green:0.65 blue:0.65 alpha:1.0]
                     font:[UIFont systemFontOfSize:12.0 weight:UIFontWeightBold]];
        [btnDel.widthAnchor constraintEqualToConstant:68.0].active = YES;
        [btnDel addTarget:self action:@selector(onTapDeleteVaultAccount:) forControlEvents:UIControlEventTouchUpInside];

        [actRow addArrangedSubview:btnOpen];
        [actRow addArrangedSubview:btnEdit];
        [actRow addArrangedSubview:btnDel];
        [cStack addArrangedSubview:actRow];

        [NSLayoutConstraint activateConstraints:@[
            [cStack.topAnchor constraintEqualToAnchor:itemCard.topAnchor constant:14.0],
            [cStack.leadingAnchor constraintEqualToAnchor:itemCard.leadingAnchor constant:14.0],
            [cStack.trailingAnchor constraintEqualToAnchor:itemCard.trailingAnchor constant:-14.0],
            [cStack.bottomAnchor constraintEqualToAnchor:itemCard.bottomAnchor constant:-14.0]
        ]];
        [self.vaultItemsStack addArrangedSubview:itemCard];
    }
}

#pragma mark - TAB 3: User License Management (Quản Lý Bản Quyền)

- (UIView *)createLicenseDetailRowWithLabel:(NSString *)label outValue:(UILabel **)outVal {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [self surfaceInsetColor];
    row.layer.cornerRadius = 11.0;
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [self borderSubtleColor].CGColor;

    UILabel *kLbl = [[UILabel alloc] init];
    kLbl.translatesAutoresizingMaskIntoConstraints = NO;
    kLbl.text = label;
    kLbl.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    kLbl.textColor = [self mutedTextColor];

    UILabel *vLbl = [[UILabel alloc] init];
    vLbl.translatesAutoresizingMaskIntoConstraints = NO;
    vLbl.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    vLbl.textColor = [UIColor whiteColor];
    vLbl.adjustsFontSizeToFitWidth = YES;

    [row addSubview:kLbl];
    [row addSubview:vLbl];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:52.0],
        [kLbl.topAnchor constraintEqualToAnchor:row.topAnchor constant:8.0],
        [kLbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12.0],
        [kLbl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12.0],
        [vLbl.topAnchor constraintEqualToAnchor:kLbl.bottomAnchor constant:3.0],
        [vLbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12.0],
        [vLbl.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12.0]
    ]];

    if (outVal) *outVal = vLbl;
    return row;
}

- (void)buildTab3LicenseView {
    UIView *licCard = [self createCardView];
    UIStackView *lStack = [[UIStackView alloc] init];
    lStack.translatesAutoresizingMaskIntoConstraints = NO;
    lStack.axis = UILayoutConstraintAxisVertical;
    lStack.spacing = 12.0;
    [licCard addSubview:lStack];

    UIView *lHeader = [self createSectionHeaderWithSymbol:@"checkmark.shield.fill"
                                                    title:@"THÔNG TIN BẢN QUYỀN THIẾT BỊ"
                                                rightView:nil];
    [lStack addArrangedSubview:lHeader];

    // Status Banner Box
    UIView *stateBox = [[UIView alloc] init];
    stateBox.translatesAutoresizingMaskIntoConstraints = NO;
    stateBox.backgroundColor = [self surfaceInsetColor];
    stateBox.layer.cornerRadius = 14.0;
    stateBox.layer.borderWidth = 1.2;
    stateBox.layer.borderColor = [self goldAccentColor].CGColor;

    self.licShieldIconView = [[UIImageView alloc] initWithImage:[self sfSymbol:@"checkmark.shield.fill" size:28.0 weight:UIFontWeightBold]];
    self.licShieldIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.licShieldIconView.tintColor = [self emeraldColor];

    self.licMainStateLabel = [[UILabel alloc] init];
    self.licMainStateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.licMainStateLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightHeavy];
    self.licMainStateLabel.textColor = [self emeraldColor];
    self.licMainStateLabel.numberOfLines = 2;

    [stateBox addSubview:self.licShieldIconView];
    [stateBox addSubview:self.licMainStateLabel];
    [NSLayoutConstraint activateConstraints:@[
        [stateBox.heightAnchor constraintEqualToConstant:64.0],
        [self.licShieldIconView.leadingAnchor constraintEqualToAnchor:stateBox.leadingAnchor constant:16.0],
        [self.licShieldIconView.centerYAnchor constraintEqualToAnchor:stateBox.centerYAnchor],
        [self.licShieldIconView.widthAnchor constraintEqualToConstant:32.0],
        [self.licShieldIconView.heightAnchor constraintEqualToConstant:32.0],
        [self.licMainStateLabel.leadingAnchor constraintEqualToAnchor:self.licShieldIconView.trailingAnchor constant:12.0],
        [self.licMainStateLabel.trailingAnchor constraintEqualToAnchor:stateBox.trailingAnchor constant:-14.0],
        [self.licMainStateLabel.centerYAnchor constraintEqualToAnchor:stateBox.centerYAnchor]
    ]];
    [lStack addArrangedSubview:stateBox];

    UILabel *vHwid = nil; UILabel *vKey = nil; UILabel *vPlan = nil;
    UIView *rHwid = [self createLicenseDetailRowWithLabel:@"MÃ ĐỊNH DANH PHẦN CỨNG (HWID — 1 KEY = 1 MÁY)" outValue:&vHwid];
    UIView *rKey = [self createLicenseDetailRowWithLabel:@"MÃ KEY ĐANG KÍCH HOẠT" outValue:&vKey];
    UIView *rPlan = [self createLicenseDetailRowWithLabel:@"CHỦ SỞ HỮU & THỜI HẠN SỬ DỤNG" outValue:&vPlan];
    self.licHwidValueLabel = vHwid;
    self.licKeyUsedValueLabel = vKey;
    self.licPlanDetailValueLabel = vPlan;
    self.licHwidValueLabel.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightHeavy];
    self.licHwidValueLabel.textColor = [self goldAccentColor];

    [lStack addArrangedSubview:rHwid];
    [lStack addArrangedSubview:rKey];
    [lStack addArrangedSubview:rPlan];

    // Action Buttons
    self.btnRefreshLicenseCloud = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnRefreshLicenseCloud.backgroundColor = [self creamPrimaryColor];
    self.btnRefreshLicenseCloud.layer.cornerRadius = 13.0;
    [self styleButton:self.btnRefreshLicenseCloud
                title:@"Kiểm tra & Đồng bộ Bản quyền Cloud"
               symbol:@"arrow.clockwise"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    [self.btnRefreshLicenseCloud.heightAnchor constraintEqualToConstant:48.0].active = YES;
    [self.btnRefreshLicenseCloud addTarget:self action:@selector(onTapRefreshLicenseCloud) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnChangeKey = [UIButton buttonWithType:UIButtonTypeSystem];
    btnChangeKey.backgroundColor = [UIColor colorWithRed:0.15 green:0.13 blue:0.08 alpha:1.0];
    btnChangeKey.layer.cornerRadius = 13.0;
    btnChangeKey.layer.borderWidth = 1.1;
    btnChangeKey.layer.borderColor = [self goldAccentColor].CGColor;
    [self styleButton:btnChangeKey
                title:@"Nhập / Đổi Mã Key Bản Quyền Khác"
               symbol:@"key.fill"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:14.0 weight:UIFontWeightBold]];
    [btnChangeKey.heightAnchor constraintEqualToConstant:46.0].active = YES;
    [btnChangeKey addTarget:self action:@selector(onTapShowKeyModal) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnCopyHWID = [UIButton buttonWithType:UIButtonTypeSystem];
    btnCopyHWID.backgroundColor = [self surfaceInsetColor];
    btnCopyHWID.layer.cornerRadius = 13.0;
    btnCopyHWID.layer.borderWidth = 1.0;
    btnCopyHWID.layer.borderColor = [self borderSubtleColor].CGColor;
    [self styleButton:btnCopyHWID
                title:@"Sao chép Mã máy (HWID) gửi Admin"
               symbol:@"doc.on.doc.fill"
            tintColor:[UIColor whiteColor]
                 font:[UIFont systemFontOfSize:13.5 weight:UIFontWeightBold]];
    [btnCopyHWID.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [btnCopyHWID addTarget:self action:@selector(onTapCopyHWID) forControlEvents:UIControlEventTouchUpInside];

    [lStack addArrangedSubview:self.btnRefreshLicenseCloud];
    [lStack addArrangedSubview:btnChangeKey];
    [lStack addArrangedSubview:btnCopyHWID];

    [NSLayoutConstraint activateConstraints:@[
        [lStack.topAnchor constraintEqualToAnchor:licCard.topAnchor constant:16.0],
        [lStack.leadingAnchor constraintEqualToAnchor:licCard.leadingAnchor constant:16.0],
        [lStack.trailingAnchor constraintEqualToAnchor:licCard.trailingAnchor constant:-16.0],
        [lStack.bottomAnchor constraintEqualToAnchor:licCard.bottomAnchor constant:-16.0]
    ]];
    [self.tabLicenseStack addArrangedSubview:licCard];
}

- (void)onTapCopyHWID {
    @try {
        [UIPasteboard generalPasteboard].string = [ZTechLicenseManager deviceHardwareID];
    } @catch (NSException *e) {}
    [self showToast:[NSString stringWithFormat:@"Đã sao chép Mã máy: %@", [ZTechLicenseManager deviceHardwareID]] isError:NO];
}

- (void)onTapRefreshLicenseCloud {
    [self styleButton:self.btnRefreshLicenseCloud
                title:@"Đang đồng bộ với Upstash Cloud..."
               symbol:@"arrow.clockwise"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    self.btnRefreshLicenseCloud.enabled = NO;

    [ZTechLicenseManager refreshSavedLicenseInBackgroundWithCompletion:^(BOOL isValid, NSString * _Nonnull statusText) {
        self.btnRefreshLicenseCloud.enabled = YES;
        [self styleButton:self.btnRefreshLicenseCloud
                    title:@"Kiểm tra & Đồng bộ Bản quyền Cloud"
                   symbol:@"arrow.clockwise"
                tintColor:[self darkInkColor]
                     font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
        [self updateLicenseUIState];
        [self showToast:statusText isError:!isValid];
    }];
}

#pragma mark - Vault & Proxy Editor Modal (Crash-Proof Keypad + 1-Tap Clipboard Paste)

- (void)buildVaultEditorModal {
    self.vaultModalOverlay = [[UIView alloc] init];
    self.vaultModalOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.vaultModalOverlay.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.02 alpha:0.96];
    self.vaultModalOverlay.hidden = YES;
    [self.view addSubview:self.vaultModalOverlay];

    UIScrollView *mScroll = [[UIScrollView alloc] init];
    mScroll.translatesAutoresizingMaskIntoConstraints = NO;
    mScroll.alwaysBounceVertical = YES;
    [self.vaultModalOverlay addSubview:mScroll];

    UIView *box = [self createCardView];
    box.layer.borderWidth = 1.5;
    box.layer.borderColor = [self goldAccentColor].CGColor;
    [mScroll addSubview:box];

    self.vaultModalTitleLabel = [[UILabel alloc] init];
    self.vaultModalTitleLabel.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightHeavy];
    self.vaultModalTitleLabel.textColor = [self goldAccentColor];
    self.vaultModalTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.vaultModalTitleLabel.numberOfLines = 0;

    UILabel *hintLbl = [[UILabel alloc] init];
    hintLbl.text = @"Hỗ trợ Proxy HTTP / SOCKS5 định dạng IP:Port hoặc IP:Port:User:Pass.\nBấm [Dán Proxy đã Copy] hoặc gõ trực tiếp bên dưới:";
    hintLbl.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    hintLbl.textColor = [self mutedTextColor];
    hintLbl.textAlignment = NSTextAlignmentCenter;
    hintLbl.numberOfLines = 0;

    self.vaultNameDisplayLabel = [[UILabel alloc] init];
    self.vaultNameDisplayLabel.backgroundColor = [self surfaceInsetColor];
    self.vaultNameDisplayLabel.layer.cornerRadius = 10.0;
    self.vaultNameDisplayLabel.layer.masksToBounds = YES;
    self.vaultNameDisplayLabel.layer.borderWidth = 1.0;
    self.vaultNameDisplayLabel.layer.borderColor = [self borderSubtleColor].CGColor;
    self.vaultNameDisplayLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    self.vaultNameDisplayLabel.textColor = [UIColor whiteColor];
    self.vaultNameDisplayLabel.textAlignment = NSTextAlignmentCenter;
    [self.vaultNameDisplayLabel.heightAnchor constraintEqualToConstant:40.0].active = YES;

    self.vaultProxyDisplayLabel = [[UILabel alloc] init];
    self.vaultProxyDisplayLabel.backgroundColor = [self surfaceInsetColor];
    self.vaultProxyDisplayLabel.layer.cornerRadius = 10.0;
    self.vaultProxyDisplayLabel.layer.masksToBounds = YES;
    self.vaultProxyDisplayLabel.layer.borderWidth = 1.2;
    self.vaultProxyDisplayLabel.layer.borderColor = [self goldAccentColor].CGColor;
    self.vaultProxyDisplayLabel.font = [UIFont monospacedSystemFontOfSize:13.0 weight:UIFontWeightBold];
    self.vaultProxyDisplayLabel.textColor = [self emeraldColor];
    self.vaultProxyDisplayLabel.textAlignment = NSTextAlignmentCenter;
    self.vaultProxyDisplayLabel.adjustsFontSizeToFitWidth = YES;
    [self.vaultProxyDisplayLabel.heightAnchor constraintEqualToConstant:42.0].active = YES;

    UIStackView *quickRow = [[UIStackView alloc] init];
    quickRow.axis = UILayoutConstraintAxisHorizontal;
    quickRow.spacing = 6.0;
    quickRow.distribution = UIStackViewDistributionFillEqually;
    [quickRow.heightAnchor constraintEqualToConstant:38.0].active = YES;

    self.btnVaultFieldSwitch = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnVaultFieldSwitch.backgroundColor = [UIColor colorWithRed:0.15 green:0.14 blue:0.09 alpha:1.0];
    self.btnVaultFieldSwitch.layer.cornerRadius = 9.0;
    self.btnVaultFieldSwitch.layer.borderWidth = 1.0;
    self.btnVaultFieldSwitch.layer.borderColor = [self goldAccentColor].CGColor;
    [self styleButton:self.btnVaultFieldSwitch
                title:@"Đổi ô gõ"
               symbol:@"keyboard"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
    [self.btnVaultFieldSwitch addTarget:self action:@selector(onTapToggleVaultField) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnPasteProxy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnPasteProxy.backgroundColor = [UIColor colorWithRed:0.10 green:0.20 blue:0.13 alpha:1.0];
    btnPasteProxy.layer.cornerRadius = 9.0;
    [self styleButton:btnPasteProxy
                title:@"Dán Proxy"
               symbol:@"doc.on.clipboard.fill"
            tintColor:[self emeraldColor]
                 font:[UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
    [btnPasteProxy addTarget:self action:@selector(onTapPasteProxyFromClipboard) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnClearProxy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnClearProxy.backgroundColor = [UIColor colorWithRed:0.20 green:0.10 blue:0.10 alpha:1.0];
    btnClearProxy.layer.cornerRadius = 9.0;
    [self styleButton:btnClearProxy
                title:@"Xoá Proxy"
               symbol:@"trash.fill"
            tintColor:[UIColor colorWithRed:1.0 green:0.65 blue:0.65 alpha:1.0]
                 font:[UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
    [btnClearProxy addTarget:self action:@selector(onTapClearModalProxy) forControlEvents:UIControlEventTouchUpInside];

    [quickRow addArrangedSubview:self.btnVaultFieldSwitch];
    [quickRow addArrangedSubview:btnPasteProxy];
    [quickRow addArrangedSubview:btnClearProxy];

    UIView *proxyKeypad = [self createVaultProxyKeypadView];

    UIStackView *bottomRow = [[UIStackView alloc] init];
    bottomRow.axis = UILayoutConstraintAxisHorizontal;
    bottomRow.spacing = 10.0;
    bottomRow.distribution = UIStackViewDistributionFillProportionally;
    [bottomRow.heightAnchor constraintEqualToConstant:46.0].active = YES;

    UIButton *btnCancel = [UIButton buttonWithType:UIButtonTypeSystem];
    btnCancel.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0];
    btnCancel.layer.cornerRadius = 12.0;
    [btnCancel setTitle:@"Đóng" forState:UIControlStateNormal];
    [btnCancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnCancel.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    [btnCancel.widthAnchor constraintEqualToConstant:88.0].active = YES;
    [btnCancel addTarget:self action:@selector(onTapCloseVaultModal) forControlEvents:UIControlEventTouchUpInside];

    self.btnVaultSaveConfirm = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnVaultSaveConfirm.backgroundColor = [self creamPrimaryColor];
    self.btnVaultSaveConfirm.layer.cornerRadius = 12.0;
    [self styleButton:self.btnVaultSaveConfirm
                title:@"Lưu Acc & Proxy vào Kho"
               symbol:@"checkmark.circle.fill"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    [self.btnVaultSaveConfirm addTarget:self action:@selector(onTapConfirmVaultModal) forControlEvents:UIControlEventTouchUpInside];

    [bottomRow addArrangedSubview:btnCancel];
    [bottomRow addArrangedSubview:self.btnVaultSaveConfirm];

    UIStackView *mStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.vaultModalTitleLabel,
        hintLbl,
        self.vaultNameDisplayLabel,
        self.vaultProxyDisplayLabel,
        quickRow,
        proxyKeypad,
        bottomRow
    ]];
    mStack.translatesAutoresizingMaskIntoConstraints = NO;
    mStack.axis = UILayoutConstraintAxisVertical;
    mStack.spacing = 9.0;
    [box addSubview:mStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.vaultModalOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.vaultModalOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.vaultModalOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.vaultModalOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [mScroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [mScroll.leadingAnchor constraintEqualToAnchor:self.vaultModalOverlay.leadingAnchor],
        [mScroll.trailingAnchor constraintEqualToAnchor:self.vaultModalOverlay.trailingAnchor],
        [mScroll.bottomAnchor constraintEqualToAnchor:self.vaultModalOverlay.bottomAnchor],

        [box.topAnchor constraintEqualToAnchor:mScroll.topAnchor constant:16.0],
        [box.leadingAnchor constraintEqualToAnchor:mScroll.leadingAnchor constant:14.0],
        [box.trailingAnchor constraintEqualToAnchor:mScroll.trailingAnchor constant:-14.0],
        [box.bottomAnchor constraintEqualToAnchor:mScroll.bottomAnchor constant:-20.0],
        [box.widthAnchor constraintEqualToAnchor:mScroll.widthAnchor constant:-28.0],

        [mStack.topAnchor constraintEqualToAnchor:box.topAnchor constant:14.0],
        [mStack.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:12.0],
        [mStack.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-12.0],
        [mStack.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-14.0]
    ]];
}

- (UIView *)createVaultProxyKeypadView {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *rowsStack = [[UIStackView alloc] init];
    rowsStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowsStack.axis = UILayoutConstraintAxisVertical;
    rowsStack.spacing = 5.0;
    [container addSubview:rowsStack];

    NSArray<NSArray<NSString *> *> *keyRows = @[
        @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"],
        @[@".", @":", @"@", @"-", @"_", @"socks5://", @"http://", @"⌫", @"XOÁ"],
        @[@"q", @"w", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p"],
        @[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l", @" "],
        @[@"z", @"x", @"c", @"v", @"b", @"n", @"m", @"Acc ", @"VIP ", @"Zalo "]
    ];

    for (NSArray<NSString *> *rowKeys in keyRows) {
        UIStackView *rStack = [[UIStackView alloc] init];
        rStack.axis = UILayoutConstraintAxisHorizontal;
        rStack.distribution = UIStackViewDistributionFillEqually;
        rStack.spacing = 4.0;
        [rStack.heightAnchor constraintEqualToConstant:34.0].active = YES;

        for (NSString *kTitle in rowKeys) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.backgroundColor = [UIColor colorWithRed:0.13 green:0.15 blue:0.13 alpha:1.0];
            b.layer.cornerRadius = 6.0;
            b.layer.borderWidth = 1.0;
            b.layer.borderColor = [self borderSubtleColor].CGColor;
            [b setTitle:([kTitle isEqualToString:@" "] ? @"Cách" : kTitle) forState:UIControlStateNormal];
            b.accessibilityLabel = kTitle;
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
            b.titleLabel.adjustsFontSizeToFitWidth = YES;
            [b addTarget:self action:@selector(onTapVaultKeypadButton:) forControlEvents:UIControlEventTouchUpInside];
            [rStack addArrangedSubview:b];
        }
        [rowsStack addArrangedSubview:rStack];
    }

    [NSLayoutConstraint activateConstraints:@[
        [rowsStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [rowsStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [rowsStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [rowsStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (void)refreshVaultModalLabels {
    self.vaultNameDisplayLabel.text = [NSString stringWithFormat:@"Tên Acc: %@",
        (self.modalNameBuffer.length > 0 ? self.modalNameBuffer : @"(Tự động đặt tên)")];
    self.vaultProxyDisplayLabel.text = [NSString stringWithFormat:@"Proxy: %@",
        (self.modalProxyBuffer.length > 0 ? self.modalProxyBuffer : @"Không dùng Proxy (Mạng gốc / 4G)")];

    if (self.isEditingProxyField) {
        self.vaultProxyDisplayLabel.layer.borderColor = [self goldAccentColor].CGColor;
        self.vaultNameDisplayLabel.layer.borderColor = [self borderSubtleColor].CGColor;
        [self styleButton:self.btnVaultFieldSwitch
                    title:@"Gõ: PROXY"
                   symbol:@"keyboard"
                tintColor:[self goldAccentColor]
                     font:[UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
    } else {
        self.vaultNameDisplayLabel.layer.borderColor = [self goldAccentColor].CGColor;
        self.vaultProxyDisplayLabel.layer.borderColor = [self borderSubtleColor].CGColor;
        [self styleButton:self.btnVaultFieldSwitch
                    title:@"Gõ: TÊN ACC"
                   symbol:@"keyboard"
                tintColor:[self goldAccentColor]
                     font:[UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
    }
}

- (void)onTapToggleVaultField {
    self.isEditingProxyField = !self.isEditingProxyField;
    [self refreshVaultModalLabels];
}

- (void)onTapPasteProxyFromClipboard {
    @try {
        NSString *clip = [UIPasteboard generalPasteboard].string;
        if (clip && clip.length > 0) {
            NSString *trimmed = [clip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length > 0) {
                self.modalProxyBuffer = trimmed;
                self.isEditingProxyField = YES;
                [self refreshVaultModalLabels];
            }
        }
    } @catch (NSException *e) {}
}

- (void)onTapClearModalProxy {
    self.modalProxyBuffer = @"";
    [self refreshVaultModalLabels];
}

- (void)onTapVaultKeypadButton:(UIButton *)sender {
    NSString *key = sender.accessibilityLabel ?: [sender titleForState:UIControlStateNormal] ?: @"";
    NSString *current = self.isEditingProxyField ? (self.modalProxyBuffer ?: @"") : (self.modalNameBuffer ?: @"");

    if ([key isEqualToString:@"XOÁ"]) {
        current = @"";
    } else if ([key isEqualToString:@"⌫"]) {
        if (current.length > 0) {
            current = [current substringToIndex:current.length - 1];
        }
    } else {
        current = [current stringByAppendingString:key];
    }

    if (self.isEditingProxyField) {
        self.modalProxyBuffer = current;
    } else {
        self.modalNameBuffer = current;
    }
    [self refreshVaultModalLabels];
}

- (void)onTapOpenSaveVaultModal {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }
    NSUInteger nextNum = [ZTechVaultManager listSavedAccounts].count + 1;
    self.isSavingNewVaultAccount = YES;
    self.editingVaultAccountId = nil;
    self.isEditingProxyField = YES;
    self.modalNameBuffer = [NSString stringWithFormat:@"Acc Zalo #%lu (%@)", (unsigned long)nextNum, self.currentProfile.modelName ?: @"iPhone 16"];
    self.modalProxyBuffer = self.currentProfile.activeProxy ?: @"";
    self.vaultModalTitleLabel.text = @"LƯU ACC ZALO HIỆN TẠI VÀO KHO";
    [self styleButton:self.btnVaultSaveConfirm
                title:@"Lưu Acc & Proxy vào Kho"
               symbol:@"checkmark.circle.fill"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    [self refreshVaultModalLabels];
    self.vaultModalOverlay.hidden = NO;
}

- (void)onTapEditCurrentSessionProxy {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }
    self.isSavingNewVaultAccount = NO;
    self.editingVaultAccountId = @"__CURRENT_SESSION__";
    self.isEditingProxyField = YES;
    self.modalNameBuffer = @"Phiên Zalo hiện tại";
    self.modalProxyBuffer = self.currentProfile.activeProxy ?: @"";
    self.vaultModalTitleLabel.text = @"CÀI ĐẶT PROXY CHO PHIÊN HIỆN TẠI";
    [self styleButton:self.btnVaultSaveConfirm
                title:@"Áp dụng Proxy ngay"
               symbol:@"checkmark.circle.fill"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    [self refreshVaultModalLabels];
    self.vaultModalOverlay.hidden = NO;
}

- (void)onTapEditVaultAccount:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.vaultAccounts.count) return;
    ZTechVaultAccount *acc = self.vaultAccounts[idx];
    self.isSavingNewVaultAccount = NO;
    self.editingVaultAccountId = acc.accountId;
    self.isEditingProxyField = YES;
    self.modalNameBuffer = acc.title ?: @"";
    self.modalProxyBuffer = acc.proxyString ?: @"";
    self.vaultModalTitleLabel.text = [NSString stringWithFormat:@"SỬA PROXY & TÊN: %@", acc.title];
    [self styleButton:self.btnVaultSaveConfirm
                title:@"Lưu thay đổi Proxy & Tên"
               symbol:@"checkmark.circle.fill"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    [self refreshVaultModalLabels];
    self.vaultModalOverlay.hidden = NO;
}

- (void)onTapCloseVaultModal {
    self.vaultModalOverlay.hidden = YES;
}

- (void)onTapConfirmVaultModal {
    self.vaultModalOverlay.hidden = YES;

    if (self.isSavingNewVaultAccount) {
        NSError *err = nil;
        ZTechVaultAccount *saved = [ZTechVaultManager saveCurrentZaloSessionWithTitle:self.modalNameBuffer
                                                                                proxy:self.modalProxyBuffer
                                                                              profile:self.currentProfile
                                                                                error:&err];
        if (saved) {
            [self refreshUIWithCurrentProfile];
            [self reloadVaultListUI];
            [self showToast:[NSString stringWithFormat:@"Đã lưu [%@] vào Kho thành công!", saved.title] isError:NO];
        } else {
            [self showToast:(err.localizedDescription ?: @"Lỗi khi lưu Acc vào Kho.") isError:YES];
        }
    } else if ([self.editingVaultAccountId isEqualToString:@"__CURRENT_SESSION__"]) {
        self.currentProfile.activeProxy = [self.modalProxyBuffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        [ZTechDeviceDatabase writeProfileFiles:self.currentProfile error:nil];
        [[NSUserDefaults standardUserDefaults] setObject:[self.currentProfile toDictionary] forKey:@"ZTechCurrentProfile"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self refreshUIWithCurrentProfile];
        [self reloadVaultListUI];
        [self showToast:(self.currentProfile.activeProxy.length > 0
            ? [NSString stringWithFormat:@"Đã gắn Proxy [%@] cho phiên hiện tại!", self.currentProfile.activeProxy]
            : @"Đã tắt Proxy — Đang dùng mạng gốc / 4G.") isError:NO];
    } else if (self.editingVaultAccountId.length > 0) {
        [ZTechVaultManager updateAccount:self.editingVaultAccountId
                                   title:self.modalNameBuffer
                             proxyString:self.modalProxyBuffer];
        self.currentProfile = [ZTechDeviceDatabase loadOrCreateDefaultProfile];
        [self refreshUIWithCurrentProfile];
        [self reloadVaultListUI];
        [self showToast:@"Đã cập nhật Proxy & Tên Acc trong Kho!" isError:NO];
    }
}

- (void)onTapRestoreAndOpenVaultAccount:(UIButton *)sender {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.vaultAccounts.count) return;
    ZTechVaultAccount *acc = self.vaultAccounts[idx];

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [gen impactOccurred];

    NSError *err = nil;
    ZTechDeviceProfile *restoredProf = nil;
    BOOL ok = [ZTechVaultManager restoreAndLaunchAccount:acc outProfile:&restoredProf error:&err];
    if (ok && restoredProf) {
        self.currentProfile = restoredProf;
        [self refreshUIWithCurrentProfile];
        [self reloadVaultListUI];
        [self showToast:[NSString stringWithFormat:@"Đã bơm [%@] + Proxy & Đang mở Zalo...", acc.title] isError:NO];
    } else {
        [self showToast:(err.localizedDescription ?: @"Không thể khôi phục Acc.") isError:YES];
    }
}

- (void)onTapDeleteVaultAccount:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.vaultAccounts.count) return;
    ZTechVaultAccount *acc = self.vaultAccounts[idx];

    if ([self.pendingDeleteAccountId isEqualToString:acc.accountId]) {
        self.pendingDeleteAccountId = nil;
        [ZTechVaultManager deleteAccountWithId:acc.accountId];
        [self reloadVaultListUI];
        [self showToast:[NSString stringWithFormat:@"Đã xoá [%@] khỏi Kho.", acc.title] isError:NO];
    } else {
        self.pendingDeleteAccountId = acc.accountId;
        [self reloadVaultListUI];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.pendingDeleteAccountId isEqualToString:acc.accountId]) {
                self.pendingDeleteAccountId = nil;
                [self reloadVaultListUI];
            }
        });
    }
}

#pragma mark - Lock Screen Overlay (Key Activation Modal)

- (void)buildLockScreenOverlay {
    self.lockOverlayView = [[UIView alloc] init];
    self.lockOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockOverlayView.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.03 alpha:0.98];
    [self.view addSubview:self.lockOverlayView];

    UIScrollView *lockScroll = [[UIScrollView alloc] init];
    lockScroll.translatesAutoresizingMaskIntoConstraints = NO;
    lockScroll.alwaysBounceVertical = YES;
    [self.lockOverlayView addSubview:lockScroll];

    UIView *box = [self createCardView];
    box.layer.borderWidth = 1.5;
    box.layer.borderColor = [self goldAccentColor].CGColor;
    [lockScroll addSubview:box];

    UILabel *lockTitle = [[UILabel alloc] init];
    lockTitle.text = @"XÁC THỰC BẢN QUYỀN THIẾT BỊ";
    lockTitle.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightHeavy];
    lockTitle.textColor = [self goldAccentColor];
    lockTitle.textAlignment = NSTextAlignmentCenter;

    UILabel *lockSub = [[UILabel alloc] init];
    lockSub.text = @"Cách 1: Gửi Mã máy dưới đây cho Admin duyệt trên Web rồi bấm nút Kích hoạt.\nCách 2: Bấm mở bàn phím Key bên dưới để gõ mã Key.";
    lockSub.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    lockSub.textColor = [self mutedTextColor];
    lockSub.textAlignment = NSTextAlignmentCenter;
    lockSub.numberOfLines = 0;

    UIView *hwidBox = [[UIView alloc] init];
    hwidBox.translatesAutoresizingMaskIntoConstraints = NO;
    hwidBox.backgroundColor = [self surfaceInsetColor];
    hwidBox.layer.cornerRadius = 12.0;
    hwidBox.layer.borderWidth = 1.0;
    hwidBox.layer.borderColor = [self borderSubtleColor].CGColor;

    UILabel *hwidBigLabel = [[UILabel alloc] init];
    hwidBigLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hwidBigLabel.text = [NSString stringWithFormat:@"Mã máy: %@", [ZTechLicenseManager deviceHardwareID]];
    hwidBigLabel.font = [UIFont monospacedSystemFontOfSize:18.0 weight:UIFontWeightHeavy];
    hwidBigLabel.textColor = [UIColor whiteColor];
    hwidBigLabel.textAlignment = NSTextAlignmentCenter;
    [hwidBox addSubview:hwidBigLabel];

    UIView *keyDisplayBox = [[UIView alloc] init];
    keyDisplayBox.translatesAutoresizingMaskIntoConstraints = NO;
    keyDisplayBox.backgroundColor = [self surfaceInsetColor];
    keyDisplayBox.layer.cornerRadius = 12.0;
    keyDisplayBox.layer.borderWidth = 1.0;
    keyDisplayBox.layer.borderColor = [self goldAccentColor].CGColor;

    self.keyDisplayLabel = [[UILabel alloc] init];
    self.keyDisplayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyDisplayLabel.font = [UIFont monospacedSystemFontOfSize:14.5 weight:UIFontWeightBold];
    self.keyDisplayLabel.textAlignment = NSTextAlignmentCenter;
    self.keyDisplayLabel.adjustsFontSizeToFitWidth = YES;
    self.keyDisplayLabel.minimumScaleFactor = 0.7;
    [keyDisplayBox addSubview:self.keyDisplayLabel];
    [self refreshKeyDisplayLabel];

    self.btnToggleKeypad = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnToggleKeypad.backgroundColor = [UIColor colorWithRed:0.15 green:0.14 blue:0.09 alpha:1.0];
    self.btnToggleKeypad.layer.cornerRadius = 10.0;
    self.btnToggleKeypad.layer.borderWidth = 1.0;
    self.btnToggleKeypad.layer.borderColor = [self goldAccentColor].CGColor;
    [self styleButton:self.btnToggleKeypad
                title:@"Gõ mã Key bằng bàn phím trong App"
               symbol:@"keyboard"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:13.0 weight:UIFontWeightBold]];
    [self.btnToggleKeypad addTarget:self action:@selector(onTapToggleKeypad) forControlEvents:UIControlEventTouchUpInside];

    self.keypadContainerView = [self createInAppKeypadView];
    self.keypadContainerView.hidden = YES;

    self.lockStatusMsgLabel = [[UILabel alloc] init];
    self.lockStatusMsgLabel.text = @"Đang kiểm tra trạng thái bản quyền trên Upstash...";
    self.lockStatusMsgLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.lockStatusMsgLabel.textColor = [self goldAccentColor];
    self.lockStatusMsgLabel.textAlignment = NSTextAlignmentCenter;
    self.lockStatusMsgLabel.numberOfLines = 0;

    self.btnActivateKey = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnActivateKey.backgroundColor = [self creamPrimaryColor];
    self.btnActivateKey.layer.cornerRadius = 13.0;
    [self styleButton:self.btnActivateKey
                title:@"Kích hoạt Bản quyền (Tự nhận Mã máy / Key)"
               symbol:@"checkmark.shield.fill"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    [self.btnActivateKey addTarget:self action:@selector(onTapActivateKey) forControlEvents:UIControlEventTouchUpInside];

    self.btnCloseKeyOverlay = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnCloseKeyOverlay.backgroundColor = [UIColor colorWithRed:0.15 green:0.16 blue:0.15 alpha:1.0];
    self.btnCloseKeyOverlay.layer.cornerRadius = 11.0;
    [self.btnCloseKeyOverlay setTitle:@"Quay lại ứng dụng" forState:UIControlStateNormal];
    [self.btnCloseKeyOverlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnCloseKeyOverlay.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [self.btnCloseKeyOverlay.heightAnchor constraintEqualToConstant:42.0].active = YES;
    [self.btnCloseKeyOverlay addTarget:self action:@selector(onTapCloseKeyOverlay) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *boxStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        lockTitle,
        lockSub,
        hwidBox,
        keyDisplayBox,
        self.btnToggleKeypad,
        self.keypadContainerView,
        self.lockStatusMsgLabel,
        self.btnActivateKey,
        self.btnCloseKeyOverlay
    ]];
    boxStack.translatesAutoresizingMaskIntoConstraints = NO;
    boxStack.axis = UILayoutConstraintAxisVertical;
    boxStack.spacing = 11.0;
    [box addSubview:boxStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.lockOverlayView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.lockOverlayView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.lockOverlayView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.lockOverlayView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [lockScroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [lockScroll.leadingAnchor constraintEqualToAnchor:self.lockOverlayView.leadingAnchor],
        [lockScroll.trailingAnchor constraintEqualToAnchor:self.lockOverlayView.trailingAnchor],
        [lockScroll.bottomAnchor constraintEqualToAnchor:self.lockOverlayView.bottomAnchor],

        [box.topAnchor constraintEqualToAnchor:lockScroll.topAnchor constant:24.0],
        [box.leadingAnchor constraintEqualToAnchor:lockScroll.leadingAnchor constant:16.0],
        [box.trailingAnchor constraintEqualToAnchor:lockScroll.trailingAnchor constant:-16.0],
        [box.bottomAnchor constraintEqualToAnchor:lockScroll.bottomAnchor constant:-24.0],
        [box.widthAnchor constraintEqualToAnchor:lockScroll.widthAnchor constant:-32.0],

        [boxStack.topAnchor constraintEqualToAnchor:box.topAnchor constant:18.0],
        [boxStack.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:14.0],
        [boxStack.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-14.0],
        [boxStack.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-18.0],

        [hwidBox.heightAnchor constraintEqualToConstant:46.0],
        [hwidBigLabel.centerXAnchor constraintEqualToAnchor:hwidBox.centerXAnchor],
        [hwidBigLabel.centerYAnchor constraintEqualToAnchor:hwidBox.centerYAnchor],

        [keyDisplayBox.heightAnchor constraintEqualToConstant:46.0],
        [self.keyDisplayLabel.leadingAnchor constraintEqualToAnchor:keyDisplayBox.leadingAnchor constant:10.0],
        [self.keyDisplayLabel.trailingAnchor constraintEqualToAnchor:keyDisplayBox.trailingAnchor constant:-10.0],
        [self.keyDisplayLabel.centerYAnchor constraintEqualToAnchor:keyDisplayBox.centerYAnchor],

        [self.btnToggleKeypad.heightAnchor constraintEqualToConstant:40.0],
        [self.btnActivateKey.heightAnchor constraintEqualToConstant:48.0]
    ]];
}

- (UIView *)createInAppKeypadView {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *rowsStack = [[UIStackView alloc] init];
    rowsStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowsStack.axis = UILayoutConstraintAxisVertical;
    rowsStack.spacing = 6.0;
    [container addSubview:rowsStack];

    NSArray<NSArray<NSString *> *> *keyRows = @[
        @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"],
        @[@"Q", @"W", @"E", @"R", @"T", @"Y", @"U", @"I", @"O", @"P"],
        @[@"A", @"S", @"D", @"F", @"G", @"H", @"J", @"K", @"L", @"-"],
        @[@"GT-", @"Z", @"X", @"C", @"V", @"B", @"N", @"M", @"⌫", @"XOÁ"]
    ];

    for (NSArray<NSString *> *rowKeys in keyRows) {
        UIStackView *rStack = [[UIStackView alloc] init];
        rStack.axis = UILayoutConstraintAxisHorizontal;
        rStack.distribution = UIStackViewDistributionFillEqually;
        rStack.spacing = 4.0;
        [rStack.heightAnchor constraintEqualToConstant:36.0].active = YES;

        for (NSString *kTitle in rowKeys) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.backgroundColor = [UIColor colorWithRed:0.14 green:0.16 blue:0.14 alpha:1.0];
            b.layer.cornerRadius = 7.0;
            b.layer.borderWidth = 1.0;
            b.layer.borderColor = [self borderSubtleColor].CGColor;
            [b setTitle:kTitle forState:UIControlStateNormal];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
            b.titleLabel.adjustsFontSizeToFitWidth = YES;
            [b addTarget:self action:@selector(onTapKeypadButton:) forControlEvents:UIControlEventTouchUpInside];
            [rStack addArrangedSubview:b];
        }
        [rowsStack addArrangedSubview:rStack];
    }

    [NSLayoutConstraint activateConstraints:@[
        [rowsStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [rowsStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [rowsStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [rowsStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (void)refreshKeyDisplayLabel {
    if (self.enteredKeyBuffer.length > 0) {
        self.keyDisplayLabel.text = [NSString stringWithFormat:@"Key: %@", self.enteredKeyBuffer];
        self.keyDisplayLabel.textColor = [self goldAccentColor];
    } else {
        self.keyDisplayLabel.text = @"Tự động theo Mã máy (Hoặc bấm bàn phím để gõ Key)";
        self.keyDisplayLabel.textColor = [self mutedTextColor];
    }
}

- (void)onTapToggleKeypad {
    self.keypadContainerView.hidden = !self.keypadContainerView.hidden;
    [self styleButton:self.btnToggleKeypad
                title:(self.keypadContainerView.hidden ? @"Gõ mã Key bằng bàn phím trong App" : @"Ẩn bàn phím gõ Key")
               symbol:@"keyboard"
            tintColor:[self goldAccentColor]
                 font:[UIFont systemFontOfSize:13.0 weight:UIFontWeightBold]];
}

- (void)onTapKeypadButton:(UIButton *)sender {
    NSString *key = [sender titleForState:UIControlStateNormal] ?: @"";
    if ([key isEqualToString:@"XOÁ"]) {
        self.enteredKeyBuffer = @"";
    } else if ([key isEqualToString:@"⌫"]) {
        if (self.enteredKeyBuffer.length > 0) {
            self.enteredKeyBuffer = [self.enteredKeyBuffer substringToIndex:self.enteredKeyBuffer.length - 1];
        }
    } else {
        if (!self.enteredKeyBuffer) self.enteredKeyBuffer = @"";
        self.enteredKeyBuffer = [self.enteredKeyBuffer stringByAppendingString:key];
    }
    [self refreshKeyDisplayLabel];
}

#pragma mark - License State Updates

- (void)updateLicenseUIState {
    BOOL valid = [ZTechLicenseManager isLicenseCurrentlyValid];
    self.lockOverlayView.hidden = valid;
    self.btnCloseKeyOverlay.hidden = !valid;

    self.licHwidValueLabel.text = [ZTechLicenseManager deviceHardwareID];
    NSString *savedKey = [ZTechLicenseManager savedLicenseKey];
    self.licKeyUsedValueLabel.text = (savedKey.length > 0) ? savedKey : @"Kích hoạt tự động theo Mã máy (HWID)";
    self.licPlanDetailValueLabel.text = [ZTechLicenseManager licenseStatusSummary];

    if (valid) {
        self.headerLicenseText.text = @"ĐÃ KÍCH HOẠT";
        self.headerLicenseText.textColor = [self emeraldColor];
        self.headerLicenseIcon.tintColor = [self emeraldColor];
        self.headerLicenseBadge.backgroundColor = [UIColor colorWithRed:0.08 green:0.16 blue:0.10 alpha:1.0];

        self.licShieldIconView.image = [self sfSymbol:@"checkmark.shield.fill" size:28.0 weight:UIFontWeightBold];
        self.licShieldIconView.tintColor = [self emeraldColor];
        self.licMainStateLabel.text = @"BẢN QUYỀN ĐANG HOẠT ĐỘNG\nToàn bộ tính năng đã được mở khoá";
        self.licMainStateLabel.textColor = [self emeraldColor];
    } else {
        self.headerLicenseText.text = @"CHƯA KÍCH HOẠT";
        self.headerLicenseText.textColor = [self dangerCoralColor];
        self.headerLicenseIcon.tintColor = [self dangerCoralColor];
        self.headerLicenseBadge.backgroundColor = [UIColor colorWithRed:0.20 green:0.08 blue:0.08 alpha:1.0];

        self.licShieldIconView.image = [self sfSymbol:@"lock.shield.fill" size:28.0 weight:UIFontWeightBold];
        self.licShieldIconView.tintColor = [self dangerCoralColor];
        self.licMainStateLabel.text = @"CHƯA KÍCH HOẠT BẢN QUYỀN\nVui lòng kích hoạt Key để sử dụng";
        self.licMainStateLabel.textColor = [self dangerCoralColor];
    }
}

- (void)onTapShowKeyModal {
    self.lockOverlayView.hidden = NO;
    self.btnCloseKeyOverlay.hidden = ![ZTechLicenseManager isLicenseCurrentlyValid];
    NSString *savedKey = [ZTechLicenseManager savedLicenseKey];
    if (savedKey.length > 0) {
        self.enteredKeyBuffer = savedKey;
        [self refreshKeyDisplayLabel];
    }
    self.lockStatusMsgLabel.text = [ZTechLicenseManager isLicenseCurrentlyValid]
        ? [NSString stringWithFormat:@"Đang dùng: %@", [ZTechLicenseManager licenseStatusSummary]]
        : @"Bấm Kích hoạt để tự nhận quyền theo Mã máy hoặc gõ Key.";
}

- (void)onTapCloseKeyOverlay {
    if ([ZTechLicenseManager isLicenseCurrentlyValid]) {
        self.lockOverlayView.hidden = YES;
    }
}

- (void)onTapActivateKey {
    NSString *inputKey = self.enteredKeyBuffer ?: @"";
    self.btnActivateKey.enabled = NO;
    [self styleButton:self.btnActivateKey
                title:@"Đang kiểm tra trên Upstash..."
               symbol:@"arrow.clockwise"
            tintColor:[self darkInkColor]
                 font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
    self.lockStatusMsgLabel.text = @"Đang đối chiếu Mã máy & Key với Upstash Redis...";
    self.lockStatusMsgLabel.textColor = [self goldAccentColor];

    [ZTechLicenseManager verifyAndActivateKey:inputKey completion:^(BOOL isValid, NSString * _Nonnull message, NSString * _Nullable ownerName, NSString * _Nullable expiryText) {
        self.btnActivateKey.enabled = YES;
        [self styleButton:self.btnActivateKey
                    title:@"Kích hoạt Bản quyền (Tự nhận Mã máy / Key)"
                   symbol:@"checkmark.shield.fill"
                tintColor:[self darkInkColor]
                     font:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy]];
        self.lockStatusMsgLabel.text = message;
        if (isValid) {
            self.enteredKeyBuffer = [ZTechLicenseManager savedLicenseKey] ?: @"";
            [self refreshKeyDisplayLabel];
            self.lockStatusMsgLabel.textColor = [self emeraldColor];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self updateLicenseUIState];
                [self showToast:@"Kích hoạt bản quyền thành công!" isError:NO];
            });
        } else {
            self.lockStatusMsgLabel.textColor = [self dangerCoralColor];
            [self updateLicenseUIState];
        }
    }];
}

#pragma mark - Feature Actions & Profile Refresh

- (void)onSwitchChanged:(UISwitch *)sender {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:YES forKey:@"ZTech_SwitchInitialized"];
    [prefs setBool:self.lockModelSwitch.isOn forKey:@"ZTech_LockModel"];
    [prefs setBool:self.respringSwitch.isOn forKey:@"ZTech_Respring"];
    [prefs setBool:self.sameScreenSwitch.isOn forKey:@"ZTech_SameScreen"];
    [prefs setBool:self.matchChipSwitch.isOn forKey:@"ZTech_MatchChip"];
    [prefs synchronize];

    self.lockModelSubLabel.text = self.lockModelSwitch.isOn
        ? @"ON: Giữ nguyên đời máy thật — chỉ đổi ID & thông số phụ"
        : @"OFF: Fake Tất Cả — đổi sang iPhone 16 Series / đời mới";

    self.respringSubLabel.text = self.respringSwitch.isOn
        ? @"ON: Tự động làm mới SpringBoard sau khi đổi máy"
        : @"OFF: Áp dụng tức thì không cần khởi động lại màn hình";

    self.sameScreenSubLabel.text = self.sameScreenSwitch.isOn
        ? @"ON: Chỉ bốc các máy có cùng kích thước màn hình thật"
        : @"OFF: Cho phép bốc mọi màn hình (kể cả iPhone 16 Pro Max)";

    self.matchChipSubLabel.text = self.matchChipSwitch.isOn
        ? @"ON: Chỉ bốc các máy cùng dung lượng RAM máy thật"
        : @"OFF: Cho phép giả lập Chip A18 Pro & RAM 8GB đời mới";

    [self refreshCheckFooterText];
}

- (void)refreshUIWithCurrentProfile {
    self.modelHeroLabel.text = self.currentProfile.modelName ?: @"iPhone 16 Pro Max";
    self.machineBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", self.currentProfile.machineId ?: @"iPhone17,2"];
    self.iosBadgeLabel.text = [NSString stringWithFormat:@"  iOS %@  ", self.currentProfile.iosVersion ?: @"18.2.1"];
    self.uuidMonoLabel.text = [NSString stringWithFormat:@"UUID: %@", self.currentProfile.identifier ?: @""];

    self.specChipValueLabel.text = [NSString stringWithFormat:@"%@ · %ldGB", self.currentProfile.chipName ?: @"A18 Pro", (long)self.currentProfile.ramGB];
    self.specScreenValueLabel.text = [NSString stringWithFormat:@"%@ px (@3x)", self.currentProfile.screenKey ?: @"440x956"];
    self.specNetValueLabel.text = [NSString stringWithFormat:@"%@ · %@", self.currentProfile.carrier ?: @"Viettel", self.currentProfile.city ?: @"Hà Nội"];
    self.specBatValueLabel.text = [NSString stringWithFormat:@"%ld%% · %ld danh bạ", (long)self.currentProfile.batteryPercent, (long)self.currentProfile.contactsCount];

    [self refreshCheckFooterText];
}

- (void)refreshCheckFooterText {
    NSString *modeStr = self.lockModelSwitch.isOn ? @"Chế độ: Khoá Đời Máy" : @"Chế độ: Fake Tất Cả";
    NSString *proxyInfo = (self.currentProfile.activeProxy.length > 0)
        ? [NSString stringWithFormat:@" · Proxy: %@", self.currentProfile.activeProxy]
        : @" · Mạng: Trực tiếp (4G/WiFi)";
    self.checkDetailLabel.text = [NSString stringWithFormat:
        @"Đã ghi thành công %ld/7 file cấu hình hệ thống · %ld/10 mục Hook đang hoạt động.\n%@%@",
        (long)self.currentProfile.writtenFilesCount,
        (long)self.currentProfile.successItemsCount,
        modeStr,
        proxyInfo];
}

- (void)onTapChangeDevice {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }
    [self onAppBecameActive];

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    self.currentProfile = [ZTechDeviceDatabase generateProfileWithLockRealModel:self.lockModelSwitch.isOn
                                                                     sameScreen:self.sameScreenSwitch.isOn
                                                                      matchChip:self.matchChipSwitch.isOn
                                                                      modelTier:self.currentModelTier
                                                                    currentCity:self.currentProfile.city];
    [UIView transitionWithView:self.tabFeaturesStack
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [self refreshUIWithCurrentProfile];
    } completion:^(BOOL finished) {
        [self showToast:[NSString stringWithFormat:@"Đã đổi sang: %@ (iOS %@)", self.currentProfile.modelName, self.currentProfile.iosVersion] isError:NO];
        if (self.respringSwitch.isOn) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [ZTechDeviceDatabase performRespringIfPossible];
            });
        }
    }];
}

- (void)onTapCleanReset {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }
    [self onAppBecameActive];

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [gen impactOccurred];

    NSInteger cleaned = [ZTechDeviceDatabase cleanResetAllProfileDataAndCache];
    self.currentProfile = [ZTechDeviceDatabase generateProfileWithLockRealModel:self.lockModelSwitch.isOn
                                                                     sameScreen:self.sameScreenSwitch.isOn
                                                                      matchChip:self.matchChipSwitch.isOn
                                                                      modelTier:self.currentModelTier
                                                                    currentCity:nil];
    [self refreshUIWithCurrentProfile];
    [self reloadVaultListUI];
    [self showToast:[NSString stringWithFormat:@"Đã làm mới Zalo (%ld mục) & Tạo máy %@!", (long)cleaned, self.currentProfile.modelName] isError:NO];
}

- (void)onTapSyncIP {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }

    self.syncIPButton.enabled = NO;
    [ZTechDeviceDatabase syncLocationByIPWithCompletion:^(NSString *city, NSString *isp, NSError *error) {
        self.syncIPButton.enabled = YES;
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
            [self showToast:[NSString stringWithFormat:@"Đã đồng bộ IP: %@ · %@", self.currentProfile.carrier, city] isError:NO];
        } else {
            [self showToast:@"Không thể lấy vị trí IP hiện tại." isError:YES];
        }
    }];
}

- (void)onTapCopyReport {
    @try {
        NSString *report = [self.currentProfile fullReportTextWithFlags:self.lockModelSwitch.isOn
                                                          respringAfter:self.respringSwitch.isOn
                                                             sameScreen:self.sameScreenSwitch.isOn
                                                              matchChip:self.matchChipSwitch.isOn];
        [UIPasteboard generalPasteboard].string = report;
    } @catch (NSException *e) {}
    [self showToast:@"Đã sao chép báo cáo cấu hình vào bộ nhớ tạm!" isError:NO];
}

@end
