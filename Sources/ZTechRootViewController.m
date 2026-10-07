#import "ZTechRootViewController.h"
#import "ZTechDeviceDatabase.h"
#import "ZTechLicenseManager.h"
#import "ZTechVaultManager.h"

@interface ZTechRootViewController ()

@property (nonatomic, strong) ZTechDeviceProfile *currentProfile;
@property (nonatomic, assign) ZTechModelTierFilter currentModelTier;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;

// License Card UI
@property (nonatomic, strong) UILabel *hwidValueLabel;
@property (nonatomic, strong) UILabel *licenseStatusLabel;
@property (nonatomic, strong) UIButton *btnManageKey;

// Lock Screen Overlay UI (Crash-proof: No UITextField / System Keyboard needed)
@property (nonatomic, strong) UIView *lockOverlayView;
@property (nonatomic, strong) UILabel *keyDisplayLabel;
@property (nonatomic, copy) NSString *enteredKeyBuffer;
@property (nonatomic, strong) UIView *keypadContainerView;
@property (nonatomic, strong) UILabel *lockStatusMsgLabel;
@property (nonatomic, strong) UIButton *btnActivateKey;
@property (nonatomic, strong) UIButton *btnToggleKeypad;

// Identifier Card UI
@property (nonatomic, strong) UILabel *uuidLabel;
@property (nonatomic, strong) UILabel *deviceLine1Label;
@property (nonatomic, strong) UILabel *deviceLine2Label;
@property (nonatomic, strong) UIButton *btnModelTierFilter;

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
@property (nonatomic, strong) UIButton *cleanResetButton;
@property (nonatomic, strong) UIButton *syncIPButton;
@property (nonatomic, strong) UIButton *btnCopyReport;

// Vault Card UI (Kho Lưu Trữ Acc Zalo & Proxy)
@property (nonatomic, strong) UILabel *vaultCountLabel;
@property (nonatomic, strong) UILabel *vaultStatusBannerLabel;
@property (nonatomic, strong) UIStackView *vaultItemsStack;
@property (nonatomic, strong) NSArray<ZTechVaultAccount *> *vaultAccounts;
@property (nonatomic, copy) NSString *pendingDeleteAccountId;

// Vault / Proxy Editor Modal Overlay (Crash-proof Keypad + 1-Tap Clipboard Paste)
@property (nonatomic, strong) UIView *vaultModalOverlay;
@property (nonatomic, strong) UILabel *vaultModalTitleLabel;
@property (nonatomic, strong) UILabel *vaultNameDisplayLabel;
@property (nonatomic, strong) UILabel *vaultProxyDisplayLabel;
@property (nonatomic, strong) UIButton *btnVaultFieldSwitch;
@property (nonatomic, strong) UIButton *btnVaultSaveConfirm;
@property (nonatomic, assign) BOOL isEditingProxyField; // NO = editing Name, YES = editing Proxy
@property (nonatomic, assign) BOOL isSavingNewVaultAccount;
@property (nonatomic, copy) NSString *editingVaultAccountId;
@property (nonatomic, copy) NSString *modalNameBuffer;
@property (nonatomic, copy) NSString *modalProxyBuffer;

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
    self.enteredKeyBuffer = [ZTechLicenseManager savedLicenseKey] ?: @"";

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    // Migrate v4.6: default to iPhone 16 Series tier and turn off SameScreen/MatchChip lock so iPhone 16 models appear immediately
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

    [self setupScrollView];
    [self buildHeaderSection];
    [self buildLicenseCard];
    [self buildIdentifierCard];
    [self buildActionButtons];
    [self buildVaultCard];
    [self buildSwitchesCard];
    [self buildCheckCard];
    [self buildVaultEditorModal];
    [self buildLockScreenOverlay];

    [self onSwitchChanged:nil];
    [self refreshModelTierButtonTitle];
    [self refreshUIWithCurrentProfile];
    [self reloadVaultListUI];
    [self updateLicenseUIState];

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

    UIView *logoBadge = [[UIView alloc] init];
    logoBadge.translatesAutoresizingMaskIntoConstraints = NO;
    logoBadge.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.10 alpha:1.0];
    logoBadge.layer.cornerRadius = 12.0;
    logoBadge.layer.borderWidth = 1.5;
    logoBadge.layer.borderColor = [self goldAccentColor].CGColor;

    UILabel *logoLabel = [[UILabel alloc] init];
    logoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    logoLabel.text = @"GT";
    logoLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightHeavy];
    logoLabel.textColor = [self goldAccentColor];
    logoLabel.textAlignment = NSTextAlignmentCenter;
    [logoBadge addSubview:logoLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"gaulmt -Tech";
    titleLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = @"iPhone 16 Series · Kho Acc Zalo & Proxy (v4.6)";
    subLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    subLabel.textColor = [UIColor colorWithRed:0.75 green:0.76 blue:0.72 alpha:1.0];

    [headerContainer addSubview:logoBadge];
    [headerContainer addSubview:titleLabel];
    [headerContainer addSubview:subLabel];

    [NSLayoutConstraint activateConstraints:@[
        [logoBadge.topAnchor constraintEqualToAnchor:headerContainer.topAnchor constant:2.0],
        [logoBadge.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:2.0],
        [logoBadge.widthAnchor constraintEqualToConstant:44.0],
        [logoBadge.heightAnchor constraintEqualToConstant:44.0],

        [logoLabel.centerXAnchor constraintEqualToAnchor:logoBadge.centerXAnchor],
        [logoLabel.centerYAnchor constraintEqualToAnchor:logoBadge.centerYAnchor],

        [titleLabel.centerYAnchor constraintEqualToAnchor:logoBadge.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:logoBadge.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],

        [subLabel.topAnchor constraintEqualToAnchor:logoBadge.bottomAnchor constant:8.0],
        [subLabel.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:2.0],
        [subLabel.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
        [subLabel.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor constant:-2.0]
    ]];

    [self.mainStack addArrangedSubview:headerContainer];
}

- (void)buildLicenseCard {
    UIView *card = [self createStyledCardView];

    UILabel *tagLabel = [[UILabel alloc] init];
    tagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tagLabel.text = @"B Ả N   Q U Y Ề N   ·   1   K E Y   =   1   M Á Y";
    tagLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    tagLabel.textColor = [self goldAccentColor];

    self.hwidValueLabel = [[UILabel alloc] init];
    self.hwidValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hwidValueLabel.text = [NSString stringWithFormat:@"Mã máy: %@", [ZTechLicenseManager deviceHardwareID]];
    self.hwidValueLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    self.hwidValueLabel.textColor = [UIColor whiteColor];

    self.licenseStatusLabel = [[UILabel alloc] init];
    self.licenseStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.licenseStatusLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    self.licenseStatusLabel.textColor = [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
    self.licenseStatusLabel.numberOfLines = 0;

    self.btnManageKey = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnManageKey.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnManageKey.backgroundColor = [self creamButtonColor];
    self.btnManageKey.layer.cornerRadius = 10.0;
    [self.btnManageKey setTitle:@"Kiểm tra / Đổi Key" forState:UIControlStateNormal];
    [self.btnManageKey setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.btnManageKey.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    self.btnManageKey.contentEdgeInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    [self.btnManageKey addTarget:self action:@selector(onTapShowKeyModal) forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:tagLabel];
    [card addSubview:self.hwidValueLabel];
    [card addSubview:self.licenseStatusLabel];
    [card addSubview:self.btnManageKey];

    [NSLayoutConstraint activateConstraints:@[
        [tagLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [tagLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],

        [self.hwidValueLabel.topAnchor constraintEqualToAnchor:tagLabel.bottomAnchor constant:6.0],
        [self.hwidValueLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],

        [self.btnManageKey.centerYAnchor constraintEqualToAnchor:self.hwidValueLabel.centerYAnchor],
        [self.btnManageKey.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],

        [self.licenseStatusLabel.topAnchor constraintEqualToAnchor:self.hwidValueLabel.bottomAnchor constant:6.0],
        [self.licenseStatusLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.licenseStatusLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.licenseStatusLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

#pragma mark - Identifier Card (with iPhone 16 Series Selector)

- (void)buildIdentifierCard {
    UIView *card = [self createStyledCardView];

    UILabel *tagLabel = [[UILabel alloc] init];
    tagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tagLabel.text = @"I D E N T I F I E R   ·   C Ấ U   H Ì N H   M Á Y   Ả O";
    tagLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
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
    self.deviceLine1Label.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightBold];
    self.deviceLine1Label.textColor = [self goldAccentColor];
    self.deviceLine1Label.numberOfLines = 1;
    self.deviceLine1Label.adjustsFontSizeToFitWidth = YES;

    self.deviceLine2Label = [[UILabel alloc] init];
    self.deviceLine2Label.translatesAutoresizingMaskIntoConstraints = NO;
    self.deviceLine2Label.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
    self.deviceLine2Label.textColor = [UIColor colorWithWhite:0.84 alpha:1.0];
    self.deviceLine2Label.numberOfLines = 0;

    self.btnModelTierFilter = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnModelTierFilter.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnModelTierFilter.backgroundColor = [UIColor colorWithRed:0.14 green:0.13 blue:0.08 alpha:1.0];
    self.btnModelTierFilter.layer.cornerRadius = 11.0;
    self.btnModelTierFilter.layer.borderWidth = 1.0;
    self.btnModelTierFilter.layer.borderColor = [self goldAccentColor].CGColor;
    [self.btnModelTierFilter setTitleColor:[self goldAccentColor] forState:UIControlStateNormal];
    self.btnModelTierFilter.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    self.btnModelTierFilter.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.btnModelTierFilter.contentEdgeInsets = UIEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
    [self.btnModelTierFilter addTarget:self action:@selector(onTapCycleModelTier) forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:tagLabel];
    [card addSubview:self.uuidLabel];
    [card addSubview:self.deviceLine1Label];
    [card addSubview:self.deviceLine2Label];
    [card addSubview:self.btnModelTierFilter];

    [NSLayoutConstraint activateConstraints:@[
        [tagLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:15.0],
        [tagLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [tagLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.uuidLabel.topAnchor constraintEqualToAnchor:tagLabel.bottomAnchor constant:7.0],
        [self.uuidLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.uuidLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.deviceLine1Label.topAnchor constraintEqualToAnchor:self.uuidLabel.bottomAnchor constant:8.0],
        [self.deviceLine1Label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.deviceLine1Label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.deviceLine2Label.topAnchor constraintEqualToAnchor:self.deviceLine1Label.bottomAnchor constant:4.0],
        [self.deviceLine2Label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.deviceLine2Label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],

        [self.btnModelTierFilter.topAnchor constraintEqualToAnchor:self.deviceLine2Label.bottomAnchor constant:10.0],
        [self.btnModelTierFilter.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.btnModelTierFilter.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.btnModelTierFilter.heightAnchor constraintEqualToConstant:38.0],
        [self.btnModelTierFilter.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

- (void)refreshModelTierButtonTitle {
    NSString *title = @"";
    if (self.currentModelTier == ZTechModelTierIPhone16) {
        title = @"👑 Dòng máy: Chỉ iPhone 16 Series (16 / 16 Pro / 16 Pro Max / 16e) ▾";
    } else if (self.currentModelTier == ZTechModelTierHighEnd) {
        title = @"🔥 Dòng máy: Đời Cao (iPhone 14 → iPhone 16 Pro Max) ▾";
    } else {
        title = @"📱 Dòng máy: Tất cả (iPhone 8 → iPhone 16 Pro Max) ▾";
    }
    [self.btnModelTierFilter setTitle:title forState:UIControlStateNormal];
}

- (void)onTapCycleModelTier {
    if (self.currentModelTier == ZTechModelTierIPhone16) {
        self.currentModelTier = ZTechModelTierHighEnd;
    } else if (self.currentModelTier == ZTechModelTierHighEnd) {
        self.currentModelTier = ZTechModelTierAll;
    } else {
        self.currentModelTier = ZTechModelTierIPhone16;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:self.currentModelTier forKey:@"ZTech_ModelTier"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self refreshModelTierButtonTitle];
    [self onTapChangeDevice];
}

#pragma mark - Action Buttons

- (void)buildActionButtons {
    self.changeDeviceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeDeviceButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.changeDeviceButton.backgroundColor = [self creamButtonColor];
    self.changeDeviceButton.layer.cornerRadius = 16.0;
    [self.changeDeviceButton setTitle:@"Change device · Đổi máy mới" forState:UIControlStateNormal];
    [self.changeDeviceButton setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.changeDeviceButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [self.changeDeviceButton addTarget:self action:@selector(onTapChangeDevice) forControlEvents:UIControlEventTouchUpInside];

    self.cleanResetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cleanResetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cleanResetButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.13 blue:0.09 alpha:1.0];
    self.cleanResetButton.layer.cornerRadius = 16.0;
    self.cleanResetButton.layer.borderWidth = 1.2;
    self.cleanResetButton.layer.borderColor = [self goldAccentColor].CGColor;
    [self.cleanResetButton setTitle:@"Làm mới dữ liệu Zalo & Tạo phiên mới" forState:UIControlStateNormal];
    [self.cleanResetButton setTitleColor:[self goldAccentColor] forState:UIControlStateNormal];
    self.cleanResetButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    [self.cleanResetButton addTarget:self action:@selector(onTapCleanReset) forControlEvents:UIControlEventTouchUpInside];

    self.syncIPButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.syncIPButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.syncIPButton.backgroundColor = [self cardBackgroundColor];
    self.syncIPButton.layer.cornerRadius = 16.0;
    self.syncIPButton.layer.borderWidth = 1.0;
    self.syncIPButton.layer.borderColor = [self cardBorderColor].CGColor;
    [self.syncIPButton setTitle:@"Đồng bộ vị trí theo IP" forState:UIControlStateNormal];
    [self.syncIPButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.syncIPButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    [self.syncIPButton addTarget:self action:@selector(onTapSyncIP) forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [self.changeDeviceButton.heightAnchor constraintEqualToConstant:52.0],
        [self.cleanResetButton.heightAnchor constraintEqualToConstant:50.0],
        [self.syncIPButton.heightAnchor constraintEqualToConstant:48.0]
    ]];

    [self.mainStack addArrangedSubview:self.changeDeviceButton];
    [self.mainStack addArrangedSubview:self.cleanResetButton];
    [self.mainStack addArrangedSubview:self.syncIPButton];
}

#pragma mark - Zalo Account Vault & Proxy Card (Kho Lưu Trữ Acc Zalo + Proxy)

- (void)buildVaultCard {
    UIView *card = [self createStyledCardView];
    card.layer.borderWidth = 1.3;
    card.layer.borderColor = [self goldAccentColor].CGColor;

    UIStackView *vStack = [[UIStackView alloc] init];
    vStack.translatesAutoresizingMaskIntoConstraints = NO;
    vStack.axis = UILayoutConstraintAxisVertical;
    vStack.spacing = 10.0;
    [card addSubview:vStack];

    // Header Row
    UIView *headerRow = [[UIView alloc] init];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *tagLabel = [[UILabel alloc] init];
    tagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tagLabel.text = @"📦 KHO LƯU TRỮ ACC ZALO & PROXY";
    tagLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightHeavy];
    tagLabel.textColor = [self goldAccentColor];

    self.vaultCountLabel = [[UILabel alloc] init];
    self.vaultCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.vaultCountLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    self.vaultCountLabel.textColor = [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
    self.vaultCountLabel.textAlignment = NSTextAlignmentRight;

    [headerRow addSubview:tagLabel];
    [headerRow addSubview:self.vaultCountLabel];
    [NSLayoutConstraint activateConstraints:@[
        [tagLabel.topAnchor constraintEqualToAnchor:headerRow.topAnchor],
        [tagLabel.leadingAnchor constraintEqualToAnchor:headerRow.leadingAnchor],
        [tagLabel.bottomAnchor constraintEqualToAnchor:headerRow.bottomAnchor],
        [self.vaultCountLabel.centerYAnchor constraintEqualToAnchor:tagLabel.centerYAnchor],
        [self.vaultCountLabel.trailingAnchor constraintEqualToAnchor:headerRow.trailingAnchor]
    ]];
    [vStack addArrangedSubview:headerRow];

    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"Lưu trọn bộ phiên đăng nhập Zalo + Thông số máy ảo + Proxy riêng. Khi cần vào lại Acc nào chỉ cần bấm [🚀 Mở] để bơm thẳng vào Zalo và tự mở.";
    descLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    descLabel.textColor = [self subtitleTextColor];
    descLabel.numberOfLines = 0;
    [vStack addArrangedSubview:descLabel];

    // Top Buttons: Save Current Acc + Set Active Proxy
    UIStackView *topBtnsRow = [[UIStackView alloc] init];
    topBtnsRow.axis = UILayoutConstraintAxisHorizontal;
    topBtnsRow.spacing = 8.0;
    topBtnsRow.distribution = UIStackViewDistributionFillProportionally;
    [topBtnsRow.heightAnchor constraintEqualToConstant:44.0].active = YES;

    UIButton *btnSaveCurrent = [UIButton buttonWithType:UIButtonTypeSystem];
    btnSaveCurrent.backgroundColor = [self creamButtonColor];
    btnSaveCurrent.layer.cornerRadius = 12.0;
    [btnSaveCurrent setTitle:@"📥 Lưu Acc hiện tại vào Kho" forState:UIControlStateNormal];
    [btnSaveCurrent setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    btnSaveCurrent.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightHeavy];
    btnSaveCurrent.titleLabel.adjustsFontSizeToFitWidth = YES;
    [btnSaveCurrent addTarget:self action:@selector(onTapOpenSaveVaultModal) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnQuickProxy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnQuickProxy.backgroundColor = [UIColor colorWithRed:0.15 green:0.14 blue:0.09 alpha:1.0];
    btnQuickProxy.layer.cornerRadius = 12.0;
    btnQuickProxy.layer.borderWidth = 1.0;
    btnQuickProxy.layer.borderColor = [self goldAccentColor].CGColor;
    [btnQuickProxy setTitle:@"🛡 Gắn Proxy" forState:UIControlStateNormal];
    [btnQuickProxy setTitleColor:[self goldAccentColor] forState:UIControlStateNormal];
    btnQuickProxy.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [btnQuickProxy.widthAnchor constraintEqualToConstant:110.0].active = YES;
    [btnQuickProxy addTarget:self action:@selector(onTapEditCurrentSessionProxy) forControlEvents:UIControlEventTouchUpInside];

    [topBtnsRow addArrangedSubview:btnSaveCurrent];
    [topBtnsRow addArrangedSubview:btnQuickProxy];
    [vStack addArrangedSubview:topBtnsRow];

    self.vaultStatusBannerLabel = [[UILabel alloc] init];
    self.vaultStatusBannerLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    self.vaultStatusBannerLabel.textColor = [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
    self.vaultStatusBannerLabel.numberOfLines = 0;
    self.vaultStatusBannerLabel.hidden = YES;
    [vStack addArrangedSubview:self.vaultStatusBannerLabel];

    self.vaultItemsStack = [[UIStackView alloc] init];
    self.vaultItemsStack.axis = UILayoutConstraintAxisVertical;
    self.vaultItemsStack.spacing = 10.0;
    [vStack addArrangedSubview:self.vaultItemsStack];

    [NSLayoutConstraint activateConstraints:@[
        [vStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:15.0],
        [vStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:15.0],
        [vStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-15.0],
        [vStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-15.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

- (void)showVaultBannerMessage:(NSString *)msg isError:(BOOL)isError {
    self.vaultStatusBannerLabel.text = msg;
    self.vaultStatusBannerLabel.textColor = isError
        ? [UIColor colorWithRed:0.95 green:0.50 blue:0.45 alpha:1.0]
        : [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
    self.vaultStatusBannerLabel.hidden = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.vaultStatusBannerLabel.hidden = YES;
    });
}

- (void)reloadVaultListUI {
    for (UIView *sub in self.vaultItemsStack.arrangedSubviews) {
        [self.vaultItemsStack removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }

    self.vaultAccounts = [ZTechVaultManager listSavedAccounts];
    NSString *activeId = [ZTechVaultManager activeAccountId];
    self.vaultCountLabel.text = [NSString stringWithFormat:@"Đang lưu: %lu Acc", (unsigned long)self.vaultAccounts.count];

    if (self.vaultAccounts.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"Chưa có Acc nào trong Kho. Sau khi đăng nhập Zalo xong, hãy bấm [📥 Lưu Acc hiện tại vào Kho] để lưu lại dùng lâu dài.";
        emptyLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
        emptyLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        emptyLabel.numberOfLines = 0;
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        [self.vaultItemsStack addArrangedSubview:emptyLabel];
        return;
    }

    for (NSUInteger i = 0; i < self.vaultAccounts.count; i++) {
        ZTechVaultAccount *acc = self.vaultAccounts[i];
        BOOL isActive = (activeId && [activeId isEqualToString:acc.accountId]);

        UIView *itemBox = [[UIView alloc] init];
        itemBox.translatesAutoresizingMaskIntoConstraints = NO;
        itemBox.backgroundColor = isActive
            ? [UIColor colorWithRed:0.10 green:0.14 blue:0.10 alpha:1.0]
            : [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
        itemBox.layer.cornerRadius = 13.0;
        itemBox.layer.borderWidth = isActive ? 1.3 : 1.0;
        itemBox.layer.borderColor = isActive ? [UIColor colorWithRed:0.40 green:0.82 blue:0.48 alpha:1.0].CGColor : [self cardBorderColor].CGColor;

        UIStackView *boxStack = [[UIStackView alloc] init];
        boxStack.translatesAutoresizingMaskIntoConstraints = NO;
        boxStack.axis = UILayoutConstraintAxisVertical;
        boxStack.spacing = 4.0;
        [itemBox addSubview:boxStack];

        UILabel *titleLbl = [[UILabel alloc] init];
        NSString *activeBadge = isActive ? @" 🟢 [ĐANG MỞ]" : @"";
        titleLbl.text = [NSString stringWithFormat:@"%lu. %@ · %@%@", (unsigned long)(i + 1), acc.title, acc.createdAt, activeBadge];
        titleLbl.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightHeavy];
        titleLbl.textColor = [UIColor whiteColor];
        titleLbl.numberOfLines = 1;
        titleLbl.adjustsFontSizeToFitWidth = YES;

        UILabel *devLbl = [[UILabel alloc] init];
        devLbl.text = [NSString stringWithFormat:@"📱 %@", [acc shortDeviceSummary]];
        devLbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
        devLbl.textColor = [self goldAccentColor];
        devLbl.numberOfLines = 1;
        devLbl.adjustsFontSizeToFitWidth = YES;

        UILabel *proxyLbl = [[UILabel alloc] init];
        proxyLbl.text = [acc proxyDisplayText];
        proxyLbl.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        proxyLbl.textColor = (acc.proxyString.length > 0)
            ? [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0]
            : [UIColor colorWithWhite:0.62 alpha:1.0];
        proxyLbl.numberOfLines = 1;
        proxyLbl.adjustsFontSizeToFitWidth = YES;

        UIStackView *actRow = [[UIStackView alloc] init];
        actRow.axis = UILayoutConstraintAxisHorizontal;
        actRow.spacing = 6.0;
        actRow.distribution = UIStackViewDistributionFillProportionally;
        [actRow.heightAnchor constraintEqualToConstant:36.0].active = YES;

        UIButton *btnOpen = [UIButton buttonWithType:UIButtonTypeSystem];
        btnOpen.tag = (NSInteger)i;
        btnOpen.backgroundColor = [self creamButtonColor];
        btnOpen.layer.cornerRadius = 9.0;
        [btnOpen setTitle:@"🚀 Bơm & Mở Zalo" forState:UIControlStateNormal];
        [btnOpen setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
        btnOpen.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightHeavy];
        [btnOpen addTarget:self action:@selector(onTapRestoreAndOpenVaultAccount:) forControlEvents:UIControlEventTouchUpInside];

        UIButton *btnEditProxy = [UIButton buttonWithType:UIButtonTypeSystem];
        btnEditProxy.tag = (NSInteger)i;
        btnEditProxy.backgroundColor = [UIColor colorWithRed:0.15 green:0.14 blue:0.09 alpha:1.0];
        btnEditProxy.layer.cornerRadius = 9.0;
        btnEditProxy.layer.borderWidth = 1.0;
        btnEditProxy.layer.borderColor = [self goldAccentColor].CGColor;
        [btnEditProxy setTitle:@"🛡 Proxy / Tên" forState:UIControlStateNormal];
        [btnEditProxy setTitleColor:[self goldAccentColor] forState:UIControlStateNormal];
        btnEditProxy.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        [btnEditProxy.widthAnchor constraintEqualToConstant:100.0].active = YES;
        [btnEditProxy addTarget:self action:@selector(onTapEditVaultAccount:) forControlEvents:UIControlEventTouchUpInside];

        UIButton *btnDel = [UIButton buttonWithType:UIButtonTypeSystem];
        btnDel.tag = (NSInteger)i;
        BOOL isConfirmingDel = [self.pendingDeleteAccountId isEqualToString:acc.accountId];
        btnDel.backgroundColor = isConfirmingDel
            ? [UIColor colorWithRed:0.75 green:0.18 blue:0.18 alpha:1.0]
            : [UIColor colorWithRed:0.20 green:0.10 blue:0.10 alpha:1.0];
        btnDel.layer.cornerRadius = 9.0;
        [btnDel setTitle:(isConfirmingDel ? @"Xác nhận?" : @"🗑 Xoá") forState:UIControlStateNormal];
        [btnDel setTitleColor:[UIColor colorWithRed:1.0 green:0.65 blue:0.65 alpha:1.0] forState:UIControlStateNormal];
        btnDel.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        [btnDel.widthAnchor constraintEqualToConstant:72.0].active = YES;
        [btnDel addTarget:self action:@selector(onTapDeleteVaultAccount:) forControlEvents:UIControlEventTouchUpInside];

        [actRow addArrangedSubview:btnOpen];
        [actRow addArrangedSubview:btnEditProxy];
        [actRow addArrangedSubview:btnDel];

        [boxStack addArrangedSubview:titleLbl];
        [boxStack addArrangedSubview:devLbl];
        [boxStack addArrangedSubview:proxyLbl];
        [boxStack addArrangedSubview:actRow];

        [NSLayoutConstraint activateConstraints:@[
            [boxStack.topAnchor constraintEqualToAnchor:itemBox.topAnchor constant:10.0],
            [boxStack.leadingAnchor constraintEqualToAnchor:itemBox.leadingAnchor constant:12.0],
            [boxStack.trailingAnchor constraintEqualToAnchor:itemBox.trailingAnchor constant:-12.0],
            [boxStack.bottomAnchor constraintEqualToAnchor:itemBox.bottomAnchor constant:-10.0]
        ]];

        [self.vaultItemsStack addArrangedSubview:itemBox];
    }
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

    UIView *box = [self createStyledCardView];
    box.layer.borderWidth = 1.5;
    box.layer.borderColor = [self goldAccentColor].CGColor;
    [mScroll addSubview:box];

    self.vaultModalTitleLabel = [[UILabel alloc] init];
    self.vaultModalTitleLabel.font = [UIFont systemFontOfSize:17.5 weight:UIFontWeightHeavy];
    self.vaultModalTitleLabel.textColor = [self goldAccentColor];
    self.vaultModalTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.vaultModalTitleLabel.numberOfLines = 0;

    UILabel *hintLbl = [[UILabel alloc] init];
    hintLbl.text = @"Hỗ trợ Proxy HTTP / SOCKS5 định dạng IP:Port hoặc IP:Port:User:Pass.\nBạn có thể bấm [📋 Dán nhanh Proxy đã Copy] hoặc gõ trực tiếp bên dưới:";
    hintLbl.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    hintLbl.textColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    hintLbl.textAlignment = NSTextAlignmentCenter;
    hintLbl.numberOfLines = 0;

    self.vaultNameDisplayLabel = [[UILabel alloc] init];
    self.vaultNameDisplayLabel.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
    self.vaultNameDisplayLabel.layer.cornerRadius = 10.0;
    self.vaultNameDisplayLabel.layer.masksToBounds = YES;
    self.vaultNameDisplayLabel.layer.borderWidth = 1.0;
    self.vaultNameDisplayLabel.layer.borderColor = [self cardBorderColor].CGColor;
    self.vaultNameDisplayLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    self.vaultNameDisplayLabel.textColor = [UIColor whiteColor];
    self.vaultNameDisplayLabel.textAlignment = NSTextAlignmentCenter;
    [self.vaultNameDisplayLabel.heightAnchor constraintEqualToConstant:40.0].active = YES;

    self.vaultProxyDisplayLabel = [[UILabel alloc] init];
    self.vaultProxyDisplayLabel.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
    self.vaultProxyDisplayLabel.layer.cornerRadius = 10.0;
    self.vaultProxyDisplayLabel.layer.masksToBounds = YES;
    self.vaultProxyDisplayLabel.layer.borderWidth = 1.2;
    self.vaultProxyDisplayLabel.layer.borderColor = [self goldAccentColor].CGColor;
    self.vaultProxyDisplayLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    self.vaultProxyDisplayLabel.textColor = [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
    self.vaultProxyDisplayLabel.textAlignment = NSTextAlignmentCenter;
    self.vaultProxyDisplayLabel.adjustsFontSizeToFitWidth = YES;
    [self.vaultProxyDisplayLabel.heightAnchor constraintEqualToConstant:42.0].active = YES;

    // Quick Action Row: Switch Field + Paste Proxy + Clear Proxy
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
    [self.btnVaultFieldSwitch setTitle:@"✍️ Đang gõ: PROXY" forState:UIControlStateNormal];
    [self.btnVaultFieldSwitch setTitleColor:[self goldAccentColor] forState:UIControlStateNormal];
    self.btnVaultFieldSwitch.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    self.btnVaultFieldSwitch.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self.btnVaultFieldSwitch addTarget:self action:@selector(onTapToggleVaultField) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnPasteProxy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnPasteProxy.backgroundColor = [UIColor colorWithRed:0.12 green:0.22 blue:0.14 alpha:1.0];
    btnPasteProxy.layer.cornerRadius = 9.0;
    [btnPasteProxy setTitle:@"📋 Dán Proxy đã Copy" forState:UIControlStateNormal];
    [btnPasteProxy setTitleColor:[UIColor colorWithRed:0.55 green:0.95 blue:0.65 alpha:1.0] forState:UIControlStateNormal];
    btnPasteProxy.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    btnPasteProxy.titleLabel.adjustsFontSizeToFitWidth = YES;
    [btnPasteProxy addTarget:self action:@selector(onTapPasteProxyFromClipboard) forControlEvents:UIControlEventTouchUpInside];

    UIButton *btnClearProxy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnClearProxy.backgroundColor = [UIColor colorWithRed:0.20 green:0.11 blue:0.11 alpha:1.0];
    btnClearProxy.layer.cornerRadius = 9.0;
    [btnClearProxy setTitle:@"🌐 Xoá Proxy (4G)" forState:UIControlStateNormal];
    [btnClearProxy setTitleColor:[UIColor colorWithRed:1.0 green:0.65 blue:0.65 alpha:1.0] forState:UIControlStateNormal];
    btnClearProxy.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    btnClearProxy.titleLabel.adjustsFontSizeToFitWidth = YES;
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
    btnCancel.titleLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightBold];
    [btnCancel.widthAnchor constraintEqualToConstant:90.0].active = YES;
    [btnCancel addTarget:self action:@selector(onTapCloseVaultModal) forControlEvents:UIControlEventTouchUpInside];

    self.btnVaultSaveConfirm = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnVaultSaveConfirm.backgroundColor = [self creamButtonColor];
    self.btnVaultSaveConfirm.layer.cornerRadius = 12.0;
    [self.btnVaultSaveConfirm setTitle:@"💾 Lưu Acc & Proxy vào Kho" forState:UIControlStateNormal];
    [self.btnVaultSaveConfirm setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.btnVaultSaveConfirm.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightHeavy];
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
            b.backgroundColor = [UIColor colorWithRed:0.14 green:0.16 blue:0.14 alpha:1.0];
            b.layer.cornerRadius = 6.0;
            b.layer.borderWidth = 1.0;
            b.layer.borderColor = [self cardBorderColor].CGColor;
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
    self.vaultNameDisplayLabel.text = [NSString stringWithFormat:@"🏷 Tên Acc: %@",
        (self.modalNameBuffer.length > 0 ? self.modalNameBuffer : @"(Tự động đặt tên)")];
    self.vaultProxyDisplayLabel.text = [NSString stringWithFormat:@"🛡 Proxy: %@",
        (self.modalProxyBuffer.length > 0 ? self.modalProxyBuffer : @"Không dùng Proxy (Mạng gốc / 4G)")];

    if (self.isEditingProxyField) {
        self.vaultProxyDisplayLabel.layer.borderColor = [self goldAccentColor].CGColor;
        self.vaultNameDisplayLabel.layer.borderColor = [self cardBorderColor].CGColor;
        [self.btnVaultFieldSwitch setTitle:@"✍️ Đang gõ: PROXY (Bấm để gõ Tên)" forState:UIControlStateNormal];
    } else {
        self.vaultNameDisplayLabel.layer.borderColor = [self goldAccentColor].CGColor;
        self.vaultProxyDisplayLabel.layer.borderColor = [self cardBorderColor].CGColor;
        [self.btnVaultFieldSwitch setTitle:@"✍️ Đang gõ: TÊN ACC (Bấm để gõ Proxy)" forState:UIControlStateNormal];
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
    self.vaultModalTitleLabel.text = @"📥 LƯU ACC ZALO HIỆN TẠI VÀO KHO";
    [self.btnVaultSaveConfirm setTitle:@"💾 Lưu Acc & Proxy vào Kho" forState:UIControlStateNormal];
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
    self.vaultModalTitleLabel.text = @"🛡 CÀI ĐẶT PROXY CHO PHIÊN HIỆN TẠI";
    [self.btnVaultSaveConfirm setTitle:@"✓ Áp dụng Proxy ngay" forState:UIControlStateNormal];
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
    self.vaultModalTitleLabel.text = [NSString stringWithFormat:@"🛡 SỬA PROXY & TÊN: %@", acc.title];
    [self.btnVaultSaveConfirm setTitle:@"💾 Lưu thay đổi Proxy & Tên" forState:UIControlStateNormal];
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
            [self showVaultBannerMessage:[NSString stringWithFormat:@"✅ Đã lưu [%@] vào Kho thành công!", saved.title] isError:NO];
        } else {
            [self showVaultBannerMessage:(err.localizedDescription ?: @"❌ Lỗi khi lưu Acc vào Kho.") isError:YES];
        }
    } else if ([self.editingVaultAccountId isEqualToString:@"__CURRENT_SESSION__"]) {
        self.currentProfile.activeProxy = [self.modalProxyBuffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        [ZTechDeviceDatabase writeProfileFiles:self.currentProfile error:nil];
        [[NSUserDefaults standardUserDefaults] setObject:[self.currentProfile toDictionary] forKey:@"ZTechCurrentProfile"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self refreshUIWithCurrentProfile];
        [self showVaultBannerMessage:(self.currentProfile.activeProxy.length > 0
            ? [NSString stringWithFormat:@"✅ Đã gắn Proxy [%@] cho phiên Zalo hiện tại!", self.currentProfile.activeProxy]
            : @"🌐 Đã tắt Proxy — Đang dùng mạng gốc / 4G.") isError:NO];
    } else if (self.editingVaultAccountId.length > 0) {
        [ZTechVaultManager updateAccount:self.editingVaultAccountId
                                   title:self.modalNameBuffer
                             proxyString:self.modalProxyBuffer];
        self.currentProfile = [ZTechDeviceDatabase loadOrCreateDefaultProfile];
        [self refreshUIWithCurrentProfile];
        [self reloadVaultListUI];
        [self showVaultBannerMessage:@"✅ Đã cập nhật Proxy & Tên Acc trong Kho!" isError:NO];
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
        [self showVaultBannerMessage:[NSString stringWithFormat:@"🚀 Đã bơm [%@] + Proxy & Đang mở Zalo...", acc.title] isError:NO];
    } else {
        [self showVaultBannerMessage:(err.localizedDescription ?: @"❌ Không thể khôi phục Acc.") isError:YES];
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
        [self showVaultBannerMessage:[NSString stringWithFormat:@"🗑 Đã xoá [%@] khỏi Kho.", acc.title] isError:NO];
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

#pragma mark - Lock Screen Overlay

- (void)buildLockScreenOverlay {
    self.lockOverlayView = [[UIView alloc] init];
    self.lockOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockOverlayView.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.03 alpha:0.98];
    [self.view addSubview:self.lockOverlayView];

    UIScrollView *lockScroll = [[UIScrollView alloc] init];
    lockScroll.translatesAutoresizingMaskIntoConstraints = NO;
    lockScroll.alwaysBounceVertical = YES;
    [self.lockOverlayView addSubview:lockScroll];

    UIView *box = [self createStyledCardView];
    box.layer.borderWidth = 1.5;
    box.layer.borderColor = [self goldAccentColor].CGColor;
    [lockScroll addSubview:box];

    UILabel *lockTitle = [[UILabel alloc] init];
    lockTitle.translatesAutoresizingMaskIntoConstraints = NO;
    lockTitle.text = @"🔐 KÍCH HOẠT BẢN QUYỀN";
    lockTitle.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightHeavy];
    lockTitle.textColor = [self goldAccentColor];
    lockTitle.textAlignment = NSTextAlignmentCenter;

    UILabel *lockSub = [[UILabel alloc] init];
    lockSub.translatesAutoresizingMaskIntoConstraints = NO;
    lockSub.text = @"Cách 1 (Không cần nhập Key): Gửi Mã máy dưới đây cho Admin duyệt trên Web rồi bấm nút Kích hoạt.\nCách 2: Bấm mở Bàn phím Key bên dưới để gõ mã Key.";
    lockSub.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    lockSub.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    lockSub.textAlignment = NSTextAlignmentCenter;
    lockSub.numberOfLines = 0;

    UIView *hwidBox = [[UIView alloc] init];
    hwidBox.translatesAutoresizingMaskIntoConstraints = NO;
    hwidBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
    hwidBox.layer.cornerRadius = 12.0;
    hwidBox.layer.borderWidth = 1.0;
    hwidBox.layer.borderColor = [self cardBorderColor].CGColor;

    UILabel *hwidBigLabel = [[UILabel alloc] init];
    hwidBigLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hwidBigLabel.text = [NSString stringWithFormat:@"Mã máy: %@", [ZTechLicenseManager deviceHardwareID]];
    hwidBigLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightHeavy];
    hwidBigLabel.textColor = [UIColor whiteColor];
    hwidBigLabel.textAlignment = NSTextAlignmentCenter;
    [hwidBox addSubview:hwidBigLabel];

    UIView *keyDisplayBox = [[UIView alloc] init];
    keyDisplayBox.translatesAutoresizingMaskIntoConstraints = NO;
    keyDisplayBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.06 blue:0.05 alpha:1.0];
    keyDisplayBox.layer.cornerRadius = 12.0;
    keyDisplayBox.layer.borderWidth = 1.0;
    keyDisplayBox.layer.borderColor = [self goldAccentColor].CGColor;

    self.keyDisplayLabel = [[UILabel alloc] init];
    self.keyDisplayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyDisplayLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightBold];
    self.keyDisplayLabel.textAlignment = NSTextAlignmentCenter;
    self.keyDisplayLabel.adjustsFontSizeToFitWidth = YES;
    self.keyDisplayLabel.minimumScaleFactor = 0.7;
    [keyDisplayBox addSubview:self.keyDisplayLabel];
    [self refreshKeyDisplayLabel];

    self.btnToggleKeypad = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnToggleKeypad.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnToggleKeypad.backgroundColor = [UIColor colorWithRed:0.16 green:0.15 blue:0.10 alpha:1.0];
    self.btnToggleKeypad.layer.cornerRadius = 10.0;
    self.btnToggleKeypad.layer.borderWidth = 1.0;
    self.btnToggleKeypad.layer.borderColor = [self goldAccentColor].CGColor;
    [self.btnToggleKeypad setTitle:@"⌨️ Gõ mã Key bằng bàn phím trong App" forState:UIControlStateNormal];
    [self.btnToggleKeypad setTitleColor:[self goldAccentColor] forState:UIControlStateNormal];
    self.btnToggleKeypad.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [self.btnToggleKeypad addTarget:self action:@selector(onTapToggleKeypad) forControlEvents:UIControlEventTouchUpInside];

    self.keypadContainerView = [self createInAppKeypadView];
    self.keypadContainerView.hidden = YES;

    self.lockStatusMsgLabel = [[UILabel alloc] init];
    self.lockStatusMsgLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockStatusMsgLabel.text = @"Đang kiểm tra trạng thái bản quyền trên Upstash...";
    self.lockStatusMsgLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    self.lockStatusMsgLabel.textColor = [self goldAccentColor];
    self.lockStatusMsgLabel.textAlignment = NSTextAlignmentCenter;
    self.lockStatusMsgLabel.numberOfLines = 0;

    self.btnActivateKey = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnActivateKey.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnActivateKey.backgroundColor = [self creamButtonColor];
    self.btnActivateKey.layer.cornerRadius = 14.0;
    [self.btnActivateKey setTitle:@"🔓 Kích hoạt Bản quyền (Tự nhận Mã máy / Key)" forState:UIControlStateNormal];
    [self.btnActivateKey setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.btnActivateKey.titleLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightHeavy];
    self.btnActivateKey.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self.btnActivateKey addTarget:self action:@selector(onTapActivateKey) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *boxStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        lockTitle,
        lockSub,
        hwidBox,
        keyDisplayBox,
        self.btnToggleKeypad,
        self.keypadContainerView,
        self.lockStatusMsgLabel,
        self.btnActivateKey
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
        [self.btnActivateKey.heightAnchor constraintEqualToConstant:50.0]
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
            b.layer.borderColor = [self cardBorderColor].CGColor;
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
        self.keyDisplayLabel.text = @"Tự động kích hoạt theo Mã máy (Hoặc bấm bàn phím để nhập Key)";
        self.keyDisplayLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    }
}

- (void)onTapToggleKeypad {
    self.keypadContainerView.hidden = !self.keypadContainerView.hidden;
    [self.btnToggleKeypad setTitle:self.keypadContainerView.hidden
        ? @"⌨️ Gõ mã Key bằng bàn phím trong App"
        : @"🔼 Ẩn bàn phím gõ Key"
                          forState:UIControlStateNormal];
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

#pragma mark - Switches Card

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
    titleLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = subtitle;
    subLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
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

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL defLock = [prefs boolForKey:@"ZTech_LockModel"];
    BOOL defRespring = [prefs boolForKey:@"ZTech_Respring"];
    BOOL defScreen = [prefs boolForKey:@"ZTech_SameScreen"];
    BOOL defChip = [prefs boolForKey:@"ZTech_MatchChip"];

    UISwitch *sw1 = nil; UILabel *sub1 = nil;
    UIView *row1 = [self createSwitchRowWithTitle:@"Khoá đời máy · Giữ máy thật"
                                         subtitle:@"OFF: Fake Tất Cả (Ưu tiên iPhone 16 Series)."
                                        isDefault:defLock
                                        outSwitch:&sw1
                                      outSubLabel:&sub1];
    self.lockModelSwitch = sw1;
    self.lockModelSubLabel = sub1;

    UISwitch *sw2 = nil; UILabel *sub2 = nil;
    UIView *row2 = [self createSwitchRowWithTitle:@"Respring after Change · Làm mới SB"
                                         subtitle:@"OFF: xong là dùng luôn, không respring."
                                        isDefault:defRespring
                                        outSwitch:&sw2
                                      outSubLabel:&sub2];
    self.respringSwitch = sw2;
    self.respringSubLabel = sub2;

    UISwitch *sw3 = nil; UILabel *sub3 = nil;
    UIView *row3 = [self createSwitchRowWithTitle:@"Fake màn hình · Chỉ máy cùng màn"
                                         subtitle:@"OFF: cho phép bốc màn hình lớn của iPhone 15 / 16 Pro Max."
                                        isDefault:defScreen
                                        outSwitch:&sw3
                                      outSubLabel:&sub3];
    self.sameScreenSwitch = sw3;
    self.sameScreenSubLabel = sub3;

    UISwitch *sw4 = nil; UILabel *sub4 = nil;
    UIView *row4 = [self createSwitchRowWithTitle:@"Khớp chip · Sạch tuyệt đối"
                                         subtitle:@"OFF: cho phép giả lập Chip A18 Pro & RAM 8GB đời mới."
                                        isDefault:defChip
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

- (void)buildCheckCard {
    UIView *card = [self createStyledCardView];

    UILabel *checkTitle = [[UILabel alloc] init];
    checkTitle.translatesAutoresizingMaskIntoConstraints = NO;
    checkTitle.text = @"C H E C K";
    checkTitle.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    checkTitle.textColor = [self goldAccentColor];

    self.btnCopyReport = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnCopyReport.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnCopyReport.backgroundColor = [self creamButtonColor];
    self.btnCopyReport.layer.cornerRadius = 12.0;
    [self.btnCopyReport setTitle:@"Copy report · Sao chép" forState:UIControlStateNormal];
    [self.btnCopyReport setTitleColor:[self darkButtonTextColor] forState:UIControlStateNormal];
    self.btnCopyReport.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.btnCopyReport.contentEdgeInsets = UIEdgeInsetsMake(8.0, 14.0, 8.0, 14.0);
    [self.btnCopyReport addTarget:self action:@selector(onTapCopyReport) forControlEvents:UIControlEventTouchUpInside];

    self.checkDetailLabel = [[UILabel alloc] init];
    self.checkDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkDetailLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
    self.checkDetailLabel.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    self.checkDetailLabel.numberOfLines = 0;

    [card addSubview:checkTitle];
    [card addSubview:self.btnCopyReport];
    [card addSubview:self.checkDetailLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.btnCopyReport.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [self.btnCopyReport.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],

        [checkTitle.centerYAnchor constraintEqualToAnchor:self.btnCopyReport.centerYAnchor],
        [checkTitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],

        [self.checkDetailLabel.topAnchor constraintEqualToAnchor:self.btnCopyReport.bottomAnchor constant:10.0],
        [self.checkDetailLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [self.checkDetailLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [self.checkDetailLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    [self.mainStack addArrangedSubview:card];
}

#pragma mark - License Actions

- (void)updateLicenseUIState {
    BOOL valid = [ZTechLicenseManager isLicenseCurrentlyValid];
    self.lockOverlayView.hidden = valid;
    if (valid) {
        self.licenseStatusLabel.text = [NSString stringWithFormat:@"🟢 Đã kích hoạt · %@", [ZTechLicenseManager licenseStatusSummary]];
        self.licenseStatusLabel.textColor = [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
    } else {
        self.licenseStatusLabel.text = @"🔴 Chưa kích hoạt hoặc Key đã bị thu hồi / hết hạn";
        self.licenseStatusLabel.textColor = [UIColor colorWithRed:0.95 green:0.50 blue:0.45 alpha:1.0];
    }
}

- (void)onTapShowKeyModal {
    self.lockOverlayView.hidden = NO;
    NSString *savedKey = [ZTechLicenseManager savedLicenseKey];
    if (savedKey.length > 0) {
        self.enteredKeyBuffer = savedKey;
        [self refreshKeyDisplayLabel];
    }
    self.lockStatusMsgLabel.text = [ZTechLicenseManager isLicenseCurrentlyValid]
        ? [NSString stringWithFormat:@"Đang dùng: %@", [ZTechLicenseManager licenseStatusSummary]]
        : @"Bấm Kích hoạt để tự nhận quyền theo Mã máy hoặc gõ Key.";
}

- (void)onTapActivateKey {
    NSString *inputKey = self.enteredKeyBuffer ?: @"";
    self.btnActivateKey.enabled = NO;
    [self.btnActivateKey setTitle:@"Đang kiểm tra trên Upstash..." forState:UIControlStateNormal];
    self.lockStatusMsgLabel.text = @"Đang đối chiếu Mã máy & Key với Upstash Redis...";
    self.lockStatusMsgLabel.textColor = [self goldAccentColor];

    [ZTechLicenseManager verifyAndActivateKey:inputKey completion:^(BOOL isValid, NSString * _Nonnull message, NSString * _Nullable ownerName, NSString * _Nullable expiryText) {
        self.btnActivateKey.enabled = YES;
        [self.btnActivateKey setTitle:@"🔓 Kích hoạt Bản quyền (Tự nhận Mã máy / Key)" forState:UIControlStateNormal];
        self.lockStatusMsgLabel.text = message;
        if (isValid) {
            self.enteredKeyBuffer = [ZTechLicenseManager savedLicenseKey] ?: @"";
            [self refreshKeyDisplayLabel];
            self.lockStatusMsgLabel.textColor = [UIColor colorWithRed:0.55 green:0.90 blue:0.60 alpha:1.0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self updateLicenseUIState];
            });
        } else {
            self.lockStatusMsgLabel.textColor = [UIColor colorWithRed:0.95 green:0.50 blue:0.45 alpha:1.0];
            [self updateLicenseUIState];
        }
    }];
}

#pragma mark - Actions & Updates

- (void)onSwitchChanged:(UISwitch *)sender {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:YES forKey:@"ZTech_SwitchInitialized"];
    [prefs setBool:self.lockModelSwitch.isOn forKey:@"ZTech_LockModel"];
    [prefs setBool:self.respringSwitch.isOn forKey:@"ZTech_Respring"];
    [prefs setBool:self.sameScreenSwitch.isOn forKey:@"ZTech_SameScreen"];
    [prefs setBool:self.matchChipSwitch.isOn forKey:@"ZTech_MatchChip"];
    [prefs synchronize];

    self.lockModelSubLabel.text = self.lockModelSwitch.isOn
        ? @"ON: Giữ nguyên đời máy thật — chỉ đổi ID & thông số phụ."
        : @"OFF: Fake Tất Cả — đổi sang iPhone 16 Series / đời mới.";

    self.respringSubLabel.text = self.respringSwitch.isOn
        ? @"ON: Tự động làm mới SpringBoard (Respring) sau khi đổi."
        : @"OFF: xong là dùng luôn, không respring.";

    self.sameScreenSubLabel.text = self.sameScreenSwitch.isOn
        ? @"ON: chỉ bốc máy CÙNG MÀN HÌNH máy thật."
        : @"OFF: cho phép bốc mọi màn hình (kể cả iPhone 16 Pro Max).";

    self.matchChipSubLabel.text = self.matchChipSwitch.isOn
        ? @"ON: chỉ máy cùng CHIP+RAM+màn với máy thật."
        : @"OFF: cho phép giả lập Chip A18 Pro & RAM 8GB đời mới.";

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
    NSString *statusDot = (self.currentProfile.writtenFilesCount >= 7) ? @"🟢" : @"🔴";
    self.checkDetailLabel.text = [NSString stringWithFormat:
        @"%@ Xanh = fake đã ghi vào hệ thống. Đỏ = chưa ghi.\n"
        @"%ld mục thành công · 0 chưa ghi. Đã ghi %ld file cấu hình (%@ · %@GB · Màn %@). %@.",
        statusDot,
        (long)self.currentProfile.successItemsCount,
        (long)self.currentProfile.writtenFilesCount,
        self.currentProfile.chipName ?: @"A18 Pro",
        @(self.currentProfile.ramGB),
        self.currentProfile.screenKey ?: @"440x956",
        modeStr];
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

    [self.cleanResetButton setTitle:[NSString stringWithFormat:@"Đã dọn %ld mục & tạo ID mới ✓", (long)cleaned] forState:UIControlStateNormal];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.cleanResetButton setTitle:@"Làm mới dữ liệu Zalo & Tạo phiên mới" forState:UIControlStateNormal];
    });
}

- (void)onTapSyncIP {
    if (![ZTechLicenseManager isLicenseCurrentlyValid]) {
        [self updateLicenseUIState];
        return;
    }

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
    @try {
        NSString *report = [self.currentProfile fullReportTextWithFlags:self.lockModelSwitch.isOn
                                                          respringAfter:self.respringSwitch.isOn
                                                             sameScreen:self.sameScreenSwitch.isOn
                                                              matchChip:self.matchChipSwitch.isOn];
        [UIPasteboard generalPasteboard].string = report;
    } @catch (NSException *e) {}
    [self.btnCopyReport setTitle:@"Đã sao chép ✓" forState:UIControlStateNormal];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.btnCopyReport setTitle:@"Copy report · Sao chép" forState:UIControlStateNormal];
    });
}

@end
