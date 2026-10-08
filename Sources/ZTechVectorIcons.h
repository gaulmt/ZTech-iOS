#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ZTechCustomIconType) {
    ZTechIconBrandCrest = 0,
    ZTechIconTabSpoof,
    ZTechIconTabVault,
    ZTechIconTabLicense,
    ZTechIconDevicePhone,
    ZTechIconChipCpu,
    ZTechIconDisplayScreen,
    ZTechIconSignalRadar,
    ZTechIconBatteryBolt,
    ZTechIconRefreshMorph,
    ZTechIconCleanWipe,
    ZTechIconLocationPin,
    ZTechIconRocketLaunch,
    ZTechIconVaultSave,
    ZTechIconProxyNodes,
    ZTechIconSlidersTune,
    ZTechIconTrashDelete,
    ZTechIconCopyClone,
    ZTechIconClipboardPaste,
    ZTechIconShieldCheck,
    ZTechIconShieldLock,
    ZTechIconKeyVip,
    ZTechIconKeypadGrid,
    ZTechIconCloudSync,
    ZTechIconCrownTier,
    ZTechIconAirplaneFly
};

@interface ZTechVectorIcons : NSObject

+ (UIImage *)iconWithType:(ZTechCustomIconType)type
                     size:(CGFloat)ptSize
                    color:(UIColor *)primaryColor;

+ (UIImage *)brandCrestLogoWithSize:(CGFloat)ptSize;

@end

NS_ASSUME_NONNULL_END
