#import "ZTechLicenseManager.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

static NSString * const kZTechHWIDPrefKey     = @"ZTechPermanentHWID_v1";
static NSString * const kZTechSavedKeyPref    = @"ZTechSavedLicenseKey_v1";
static NSString * const kZTechSavedOwnerPref  = @"ZTechSavedLicenseOwner_v1";
static NSString * const kZTechSavedExpiryPref = @"ZTechSavedLicenseExpiry_v1";
static NSString * const kZTechSavedValidPref  = @"ZTechSavedLicenseValid_v1";

// Upstash Redis REST API Configuration
static NSString * const kUpstashRedisURL      = @"https://right-cat-209639.upstash.io";
static NSString * const kUpstashRedisToken    = @"gQAAAAAAAzLnAAIgcDFiYzU0NDBiOGJmYzE0OTFmYWQ2YTUzYTg4M2MwYmNlNA";
static NSString * const kRedisHashKey         = @"ztech:licenses";

@implementation ZTechLicenseManager

#pragma mark - Permanent Device Hardware ID (1 Key = 1 Device)

+ (NSString *)deviceHardwareID {
    CFTypeRef cfHwid = CFPreferencesCopyAppValue((__bridge CFStringRef)kZTechHWIDPrefKey, kCFPreferencesAnyApplication);
    if (cfHwid && CFGetTypeID(cfHwid) == CFStringGetTypeID()) {
        NSString *val = [(__bridge NSString *)cfHwid copy];
        CFRelease(cfHwid);
        if (val.length >= 10 && [val hasPrefix:@"GT-"]) {
            return val;
        }
    } else if (cfHwid) {
        CFRelease(cfHwid);
    }

    NSArray<NSString *> *hwidPaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.gaulmt.hwid.txt",
        @"/var/mobile/Library/Preferences/com.gaulmt.hwid.txt"
    ];
    for (NSString *path in hwidPaths) {
        NSString *diskVal = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (diskVal.length >= 10 && [diskVal hasPrefix:@"GT-"]) {
            [self savePermanentHWID:diskVal];
            return diskVal;
        }
    }

    NSString *udVal = [[NSUserDefaults standardUserDefaults] stringForKey:kZTechHWIDPrefKey];
    if (udVal.length >= 10 && [udVal hasPrefix:@"GT-"]) {
        [self savePermanentHWID:udVal];
        return udVal;
    }

    NSString *chars = @"0123456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    NSMutableString *p1 = [NSMutableString stringWithCapacity:4];
    NSMutableString *p2 = [NSMutableString stringWithCapacity:4];
    for (int i = 0; i < 4; i++) {
        [p1 appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
        [p2 appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
    }
    NSString *newHwid = [NSString stringWithFormat:@"GT-%@-%@", p1, p2];
    [self savePermanentHWID:newHwid];
    return newHwid;
}

+ (void)savePermanentHWID:(NSString *)hwid {
    [[NSUserDefaults standardUserDefaults] setObject:hwid forKey:kZTechHWIDPrefKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    CFPreferencesSetAppValue((__bridge CFStringRef)kZTechHWIDPrefKey,
                             (__bridge CFStringRef)hwid,
                             kCFPreferencesAnyApplication);
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication);

    NSArray<NSString *> *hwidPaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.gaulmt.hwid.txt",
        @"/var/mobile/Library/Preferences/com.gaulmt.hwid.txt"
    ];
    for (NSString *path in hwidPaths) {
        [hwid writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - License State Getters & Setters

+ (nullable NSString *)savedLicenseKey {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kZTechSavedKeyPref];
}

+ (BOOL)isLicenseCurrentlyValid {
    NSString *key = [self savedLicenseKey];
    if (!key || key.length == 0) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:kZTechSavedValidPref];
}

+ (NSString *)licenseStatusSummary {
    if (![self isLicenseCurrentlyValid]) {
        return @"Chưa kích hoạt bản quyền";
    }
    NSString *owner = [[NSUserDefaults standardUserDefaults] stringForKey:kZTechSavedOwnerPref] ?: @"VIP Member";
    NSString *expiry = [[NSUserDefaults standardUserDefaults] stringForKey:kZTechSavedExpiryPref] ?: @"Vĩnh viễn";
    return [NSString stringWithFormat:@"%@ · Hạn: %@", owner, expiry];
}

+ (void)syncLicenseStateWithHook:(BOOL)isValid {
    [[NSUserDefaults standardUserDefaults] setBool:isValid forKey:kZTechSavedValidPref];
    [[NSUserDefaults standardUserDefaults] synchronize];

    CFPreferencesSetAppValue(CFSTR("ZTechLicenseValid"),
                             isValid ? kCFBooleanTrue : kCFBooleanFalse,
                             kCFPreferencesAnyApplication);
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication);
}

+ (void)clearSavedLicense {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kZTechSavedKeyPref];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kZTechSavedOwnerPref];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kZTechSavedExpiryPref];
    [self syncLicenseStateWithHook:NO];
}

+ (void)persistValidKey:(NSString *)key owner:(NSString *)owner expiryText:(NSString *)expiryText {
    [[NSUserDefaults standardUserDefaults] setObject:key forKey:kZTechSavedKeyPref];
    [[NSUserDefaults standardUserDefaults] setObject:owner forKey:kZTechSavedOwnerPref];
    [[NSUserDefaults standardUserDefaults] setObject:expiryText forKey:kZTechSavedExpiryPref];
    [self syncLicenseStateWithHook:YES];
}

#pragma mark - Upstash Redis Real-Time Verification & Auto HWID Binding

+ (void)executeUpstashCommand:(NSArray *)commandArray
                   completion:(void (^)(id _Nullable resultObj, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:kUpstashRedisURL];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                   timeoutInterval:10.0];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %@", kUpstashRedisToken] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:commandArray options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        id res = json ? json[@"result"] : nil;
        if (completion) completion(res, nil);
    }] resume];
}

+ (void)verifyAndActivateKey:(NSString *)rawKey
                  completion:(ZTechLicenseVerifyCompletion)completion {
    NSString *cleanKey = [[rawKey uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanKey.length < 4) {
        [self syncLicenseStateWithHook:NO];
        if (completion) completion(NO, @"Vui lòng nhập mã Key hợp lệ!", nil, nil);
        return;
    }

    NSString *myHwid = [self deviceHardwareID];

    // Query Upstash Redis directly: ["HGET", "ztech:licenses", cleanKey]
    [self executeUpstashCommand:@[@"HGET", kRedisHashKey, cleanKey] completion:^(id  _Nullable resultObj, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(NO, @"Lỗi kết nối mạng tới máy chủ bản quyền. Vui lòng kiểm tra Internet!", nil, nil);
                return;
            }

            if (!resultObj || [resultObj isKindOfClass:[NSNull class]] || ![resultObj isKindOfClass:[NSString class]]) {
                [self syncLicenseStateWithHook:NO];
                if (completion) completion(NO, @"Mã Key không tồn tại hoặc đã bị Admin xoá khỏi hệ thống!", nil, nil);
                return;
            }

            NSString *jsonStr = (NSString *)resultObj;
            NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *entry = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
            if (!entry || ![entry isKindOfClass:[NSDictionary class]]) {
                [self syncLicenseStateWithHook:NO];
                if (completion) completion(NO, @"Dữ liệu Key trên máy chủ không hợp lệ!", nil, nil);
                return;
            }

            // 1. Check if Admin locked/revoked this key
            NSString *status = [entry[@"status"] ?: @"active" lowercaseString];
            if (![status isEqualToString:@"active"]) {
                [self syncLicenseStateWithHook:NO];
                if (completion) completion(NO, @"⛔ Key này đã bị Admin THU HỒI hoặc KHOÁ từ xa!", nil, nil);
                return;
            }

            // 2. Check expiration date (YYYY-MM-DD or LIFETIME)
            NSString *expiresStr = [entry[@"expires"] ?: @"LIFETIME" uppercaseString];
            if (![expiresStr isEqualToString:@"LIFETIME"] && ![expiresStr isEqualToString:@"VINHVIEN"]) {
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateFormat = @"yyyy-MM-dd";
                df.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Ho_Chi_Minh"];
                NSDate *expDate = [df dateFromString:expiresStr];
                if (expDate) {
                    NSDate *endOfDay = [expDate dateByAddingTimeInterval:86399];
                    if ([[NSDate date] compare:endOfDay] == NSOrderedDescending) {
                        [self syncLicenseStateWithHook:NO];
                        if (completion) completion(NO, [NSString stringWithFormat:@"⏰ Key đã hết hạn vào ngày %@. Vui lòng liên hệ Admin gia hạn!", expiresStr], nil, nil);
                        return;
                    }
                }
            }

            // 3. Check 1-Key-1-Device HWID Binding
            NSString *boundHwid = [[entry[@"hwid"] ?: @"" uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *owner = entry[@"owner"] ?: @"Khách VIP";
            NSString *expDisplay = ([expiresStr isEqualToString:@"LIFETIME"] || [expiresStr isEqualToString:@"VINHVIEN"]) ? @"Vĩnh viễn" : expiresStr;

            if (boundHwid.length == 0) {
                // First time activation! Bind this device's HWID to the key in Upstash Redis immediately
                NSMutableDictionary *updatedEntry = [entry mutableCopy];
                updatedEntry[@"hwid"] = myHwid;
                NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
                updatedEntry[@"activatedAt"] = [iso stringFromDate:[NSDate date]];

                NSData *updatedData = [NSJSONSerialization dataWithJSONObject:updatedEntry options:0 error:nil];
                NSString *updatedJsonStr = [[NSString alloc] initWithData:updatedData encoding:NSUTF8StringEncoding];

                [self executeUpstashCommand:@[@"HSET", kRedisHashKey, cleanKey, updatedJsonStr] completion:^(id  _Nullable res2, NSError * _Nullable err2) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self persistValidKey:cleanKey owner:owner expiryText:expDisplay];
                        if (completion) completion(YES, [NSString stringWithFormat:@"Kích hoạt thành công! Đã khoá cứng Key vào máy %@", myHwid], owner, expDisplay);
                    });
                }];
                return;
            } else if (![boundHwid isEqualToString:@"*"] && ![boundHwid isEqualToString:myHwid]) {
                // Bound to a different device!
                [self syncLicenseStateWithHook:NO];
                NSString *errMsg = [NSString stringWithFormat:@"⛔ Key này đã gắn cứng với thiết bị khác (%@)!\nMã máy của bạn là: %@", boundHwid, myHwid];
                if (completion) completion(NO, errMsg, nil, nil);
                return;
            }

            // Valid & matches this device!
            [self persistValidKey:cleanKey owner:owner expiryText:expDisplay];
            if (completion) completion(YES, @"Xác thực bản quyền thành công!", owner, expDisplay);
        });
    }];
}

+ (void)refreshSavedLicenseInBackgroundWithCompletion:(void (^)(BOOL isValid, NSString *statusText))completion {
    NSString *savedKey = [self savedLicenseKey];
    if (!savedKey || savedKey.length == 0) {
        [self syncLicenseStateWithHook:NO];
        if (completion) completion(NO, @"Chưa kích hoạt bản quyền");
        return;
    }

    [self verifyAndActivateKey:savedKey completion:^(BOOL isValid, NSString * _Nonnull message, NSString * _Nullable ownerName, NSString * _Nullable expiryText) {
        if (completion) {
            completion(isValid, isValid ? [self licenseStatusSummary] : message);
        }
    }];
}

@end
