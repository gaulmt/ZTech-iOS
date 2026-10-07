#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ZTechLicenseVerifyCompletion)(BOOL isValid, NSString *message, NSString * _Nullable ownerName, NSString * _Nullable expiryText);

@interface ZTechLicenseManager : NSObject

/// Mã phần cứng cố định của máy (1 Key = 1 Máy), định dạng: GT-XXXX-XXXX
+ (NSString *)deviceHardwareID;

/// Key hiện tại đang lưu trên máy
+ (nullable NSString *)savedLicenseKey;

/// Trạng thái bản quyền hiện tại (cached)
+ (BOOL)isLicenseCurrentlyValid;

/// Thông tin hiển thị (Tên gói/khách + Hạn dùng)
+ (NSString *)licenseStatusSummary;

/// Kích hoạt hoặc kiểm tra lại Key Online + Chữ ký thiết bị
+ (void)verifyAndActivateKey:(NSString *)rawKey
                  completion:(ZTechLicenseVerifyCompletion)completion;

/// Kiểm tra ngầm trạng thái Key khi mở app (để tự khoá nếu Admin khoá từ xa hoặc hết hạn)
+ (void)refreshSavedLicenseInBackgroundWithCompletion:(void (^)(BOOL isValid, NSString *statusText))completion;

/// Xoá key khỏi máy hiện tại
+ (void)clearSavedLicense;

@end

NS_ASSUME_NONNULL_END
