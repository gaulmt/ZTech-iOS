#import "ZTechLicenseManager.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

static NSString * const kZTechHWIDPrefKey       = @"ZTechPermanentHWID_v1";
static NSString * const kZTechSavedKeyPref      = @"ZTechSavedLicenseKey_v1";
static NSString * const kZTechSavedOwnerPref    = @"ZTechSavedLicenseOwner_v1";
static NSString * const kZTechSavedExpiryPref   = @"ZTechSavedLicenseExpiry_v1";
static NSString * const kZTechSavedValidPref    = @"ZTechSavedLicenseValid_v1";
static NSString * const kZTechSecretSalt        = @"GAULMT_TECH_SECRET_2026_V43";

@implementation ZTechLicenseManager

#pragma mark - Permanent Device Hardware ID (1 Key = 1 Device)

+ (NSString *)deviceHardwareID {
    // 1. Check CFPreferences AnyApplication
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

    // 2. Check persistent files in /var/jb or /var/mobile
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

    // 3. Check NSUserDefaults
    NSString *udVal = [[NSUserDefaults standardUserDefaults] stringForKey:kZTechHWIDPrefKey];
    if (udVal.length >= 10 && [udVal hasPrefix:@"GT-"]) {
        [self savePermanentHWID:udVal];
        return udVal;
    }

    // 4. Generate a new deterministic/permanent HWID and persist across all storage layers
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

#pragma mark - Cryptographic Signature Helper (Matches Web Admin Generator)

/// Computes an 8-character uppercase hex signature from (HWID + "|" + ExpiryYYYYMMDD + "|" + SecretSalt)
+ (NSString *)computeSignatureForHWID:(NSString *)hwid expiryDateCode:(NSString *)expiryCode {
    NSString *cleanHwid = [[hwid uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *payload = [NSString stringWithFormat:@"%@|%@|%@", cleanHwid, expiryCode, kZTechSecretSalt];
    const char *cstr = [payload UTF8String];
    // FNV-1a 64-bit hash mixed with DJB2 for cross-platform JS <-> ObjC compatibility
    uint32_t h1 = 0x811c9dc5u;
    uint32_t h2 = 5381u;
    for (size_t i = 0; cstr[i] != '\0'; i++) {
        uint8_t ch = (uint8_t)cstr[i];
        h1 ^= ch;
        h1 = h1 * 0x01000193u;
        h2 = ((h2 << 5) + h2) ^ ch;
    }
    return [NSString stringWithFormat:@"%04X%04X", (unsigned int)(h1 & 0xFFFF), (unsigned int)(h2 & 0xFFFF)];
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

#pragma mark - Online + Signed HWID Verification

+ (void)verifyAndActivateKey:(NSString *)rawKey
                  completion:(ZTechLicenseVerifyCompletion)completion {
    NSString *cleanKey = [[rawKey uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanKey.length < 6) {
        [self syncLicenseStateWithHook:NO];
        if (completion) completion(NO, @"Vui lòng nhập mã Key hợp lệ!", nil, nil);
        return;
    }

    NSString *myHwid = [self deviceHardwareID];

    // Fetch live online license database from GitHub (bypasses cache using timestamp query)
    long long ts = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *urlStr = [NSString stringWithFormat:@"https://raw.githubusercontent.com/gaulmt/gaulmt.github.io/gh-pages/licenses.json?t=%lld", ts];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                   timeoutInterval:8.0];
    [req setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *onlineJson = nil;
        if (data && !error) {
            onlineJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self evaluateKey:cleanKey
                   deviceHwid:myHwid
                   onlineData:onlineJson
                   completion:completion];
        });
    }] resume];
}

+ (void)evaluateKey:(NSString *)cleanKey
         deviceHwid:(NSString *)myHwid
         onlineData:(nullable NSDictionary *)onlineJson
         completion:(ZTechLicenseVerifyCompletion)completion {

    // 1. Check Master Admin Key
    if ([cleanKey isEqualToString:@"GT-ADMIN-MASTER-9999"]) {
        [self persistValidKey:cleanKey owner:@"Admin Master" expiryText:@"Vĩnh viễn"];
        if (completion) completion(YES, @"Kích hoạt quyền Admin thành công!", @"Admin Master", @"Vĩnh viễn");
        return;
    }

    // 2. Check Online Database (licenses.json) first
    if (onlineJson && [onlineJson[@"keys"] isKindOfClass:[NSArray class]]) {
        NSArray *keysList = onlineJson[@"keys"];
        for (NSDictionary *entry in keysList) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *entryKey = [[entry[@"key"] ?: @"" uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([entryKey isEqualToString:cleanKey]) {
                // Found in Online Database!
                NSString *status = [entry[@"status"] ?: @"active" lowercaseString];
                if ([status isEqualToString:@"locked"] || [status isEqualToString:@"revoked"] || [status isEqualToString:@"disabled"]) {
                    [self syncLicenseStateWithHook:NO];
                    if (completion) completion(NO, @"Key này đã bị Admin khoá hoặc thu hồi!", nil, nil);
                    return;
                }

                // Check 1-Key-1-Device HWID binding
                NSString *boundHwid = [[entry[@"hwid"] ?: @"" uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (boundHwid.length > 0 && ![boundHwid isEqualToString:@"*"] && ![boundHwid isEqualToString:myHwid]) {
                    [self syncLicenseStateWithHook:NO];
                    NSString *errMsg = [NSString stringWithFormat:@"Key này đã khoá cứng cho máy khác (%@).\nMã máy của bạn là: %@", boundHwid, myHwid];
                    if (completion) completion(NO, errMsg, nil, nil);
                    return;
                }

                // Check expiration date (YYYY-MM-DD or "LIFETIME")
                NSString *expiresStr = [entry[@"expires"] ?: @"LIFETIME" uppercaseString];
                if (![expiresStr isEqualToString:@"LIFETIME"] && ![expiresStr isEqualToString:@"VINHVIEN"]) {
                    NSDateFormatter *df = [[NSDateFormatter alloc] init];
                    df.dateFormat = @"yyyy-MM-dd";
                    df.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Ho_Chi_Minh"];
                    NSDate *expDate = [df dateFromString:expiresStr];
                    if (expDate) {
                        // Valid until end of that day (23:59:59)
                        NSDate *endOfDay = [expDate dateByAddingTimeInterval:86399];
                        if ([[NSDate date] compare:endOfDay] == NSOrderedDescending) {
                            [self syncLicenseStateWithHook:NO];
                            if (completion) completion(NO, [NSString stringWithFormat:@"Key đã hết hạn vào ngày %@. Vui lòng liên hệ Admin để gia hạn!", expiresStr], nil, nil);
                            return;
                        }
                    }
                }

                NSString *owner = entry[@"owner"] ?: @"Khách VIP";
                NSString *expDisplay = ([expiresStr isEqualToString:@"LIFETIME"] || [expiresStr isEqualToString:@"VINHVIEN"]) ? @"Vĩnh viễn" : expiresStr;
                [self persistValidKey:cleanKey owner:owner expiryText:expDisplay];
                if (completion) completion(YES, @"Kích hoạt bản quyền thành công!", owner, expDisplay);
                return;
            }
        }
    }

    // 3. Also verify Cryptographically Signed HWID Key format: GT-<YYYYMMDD or 99999999>-<8CHAR_SIG>
    //    Generated by Web Admin for instant activation even before GitHub CDN refreshes
    NSArray<NSString *> *parts = [cleanKey componentsSeparatedByString:@"-"];
    if (parts.count == 3 && [parts[0] isEqualToString:@"GT"]) {
        NSString *dateCode = parts[1]; // e.g., 20261107 or 99999999
        NSString *sigProvided = parts[2];
        NSString *expectedSig = [self computeSignatureForHWID:myHwid expiryDateCode:dateCode];

        if ([sigProvided isEqualToString:expectedSig]) {
            NSString *expDisplay = @"Vĩnh viễn";
            if (![dateCode isEqualToString:@"99999999"] && dateCode.length == 8) {
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateFormat = @"yyyyMMdd";
                df.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Ho_Chi_Minh"];
                NSDate *expDate = [df dateFromString:dateCode];
                if (!expDate) {
                    [self syncLicenseStateWithHook:NO];
                    if (completion) completion(NO, @"Định dạng ngày hạn sử dụng trong Key không hợp lệ!", nil, nil);
                    return;
                }
                NSDate *endOfDay = [expDate dateByAddingTimeInterval:86399];
                if ([[NSDate date] compare:endOfDay] == NSOrderedDescending) {
                    [self syncLicenseStateWithHook:NO];
                    if (completion) completion(NO, @"Key bản quyền đã hết hạn sử dụng. Vui lòng liên hệ Admin!", nil, nil);
                    return;
                }
                expDisplay = [NSString stringWithFormat:@"%@-%@-%@",
                              [dateCode substringWithRange:NSMakeRange(0, 4)],
                              [dateCode substringWithRange:NSMakeRange(4, 2)],
                              [dateCode substringWithRange:NSMakeRange(6, 2)]];
            }

            [self persistValidKey:cleanKey owner:@"VIP Device" expiryText:expDisplay];
            if (completion) completion(YES, @"Kích hoạt Key theo Mã máy thành công!", @"VIP Device", expDisplay);
            return;
        } else {
            [self syncLicenseStateWithHook:NO];
            NSString *errMsg = [NSString stringWithFormat:@"Key không hợp lệ hoặc đã được cấp riêng cho Mã máy khác!\nMã máy của bạn: %@", myHwid];
            if (completion) completion(NO, errMsg, nil, nil);
            return;
        }
    }

    [self syncLicenseStateWithHook:NO];
    if (completion) completion(NO, @"Mã Key không tồn tại hoặc không đúng với Mã máy này!", nil, nil);
}

+ (void)persistValidKey:(NSString *)key owner:(NSString *)owner expiryText:(NSString *)expiryText {
    [[NSUserDefaults standardUserDefaults] setObject:key forKey:kZTechSavedKeyPref];
    [[NSUserDefaults standardUserDefaults] setObject:owner forKey:kZTechSavedOwnerPref];
    [[NSUserDefaults standardUserDefaults] setObject:expiryText forKey:kZTechSavedExpiryPref];
    [self syncLicenseStateWithHook:YES];
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
