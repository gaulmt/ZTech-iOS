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
static NSString * const kRedisPendingHashKey  = @"ztech:pending_devices";

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

    NSString *chars = @"23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
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

#pragma mark - Upstash Redis Real-Time Verification & Auto HWID Lookup

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

+ (void)registerPendingDeviceInUpstash:(NSString *)hwid {
    NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
    NSDictionary *info = @{
        @"hwid": hwid,
        @"requestedAt": [iso stringFromDate:[NSDate date]]
    };
    NSData *d = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    if (s) {
        [self executeUpstashCommand:@[@"HSET", kRedisPendingHashKey, hwid, s] completion:nil];
    }
}

+ (void)verifyAndActivateKey:(NSString *)rawKey
                  completion:(ZTechLicenseVerifyCompletion)completion {
    NSString *cleanKey = [[rawKey ?: @"" uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *myHwid = [self deviceHardwareID];

    // Fetch all licenses in ztech:licenses so we can match EITHER by entered Key OR automatically by Device HWID!
    [self executeUpstashCommand:@[@"HGETALL", kRedisHashKey] completion:^(id  _Nullable resultObj, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || ![resultObj isKindOfClass:[NSArray class]]) {
                if (completion) completion(NO, @"Lỗi kết nối mạng tới Upstash Redis. Vui lòng kiểm tra Internet!", nil, nil);
                return;
            }

            NSArray *rawArr = (NSArray *)resultObj;
            NSDictionary *matchedEntry = nil;
            NSString *matchedKeyName = nil;

            for (NSUInteger i = 0; i + 1 < rawArr.count; i += 2) {
                NSString *kName = [rawArr[i] isKindOfClass:[NSString class]] ? rawArr[i] : @"";
                NSString *valStr = [rawArr[i + 1] isKindOfClass:[NSString class]] ? rawArr[i + 1] : @"";
                NSData *d = [valStr dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *parsed = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
                if (![parsed isKindOfClass:[NSDictionary class]]) continue;

                NSString *entryKey = [[parsed[@"key"] ?: kName uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString *entryHwid = [[parsed[@"hwid"] ?: @"" uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                // Priority 1: Exact Key match if user entered a Key
                if (cleanKey.length > 0 && [entryKey isEqualToString:cleanKey]) {
                    matchedEntry = parsed;
                    matchedKeyName = entryKey;
                    break;
                }
                // Priority 2: Automatic HWID match (User doesn't even need to type/paste the Key if Admin bound their HWID!)
                if ([entryHwid isEqualToString:myHwid]) {
                    matchedEntry = parsed;
                    matchedKeyName = entryKey;
                }
            }

            if (!matchedEntry || !matchedKeyName) {
                [self syncLicenseStateWithHook:NO];
                [self registerPendingDeviceInUpstash:myHwid];
                if (cleanKey.length == 0) {
                    if (completion) completion(NO, @"Vui lòng nhập hoặc dán mã Key!", nil, nil);
                } else {
                    if (completion) completion(NO, @"Mã Key không hợp lệ hoặc không tồn tại!", nil, nil);
                }
                return;
            }

            // 1. Check if Admin locked/revoked this key
            NSString *status = [matchedEntry[@"status"] ?: @"active" lowercaseString];
            if (![status isEqualToString:@"active"]) {
                [self syncLicenseStateWithHook:NO];
                if (completion) completion(NO, @"Key này đã bị thu hồi hoặc khoá!", nil, nil);
                return;
            }

            // 2. Check expiration date (YYYY-MM-DD or LIFETIME)
            NSString *expiresStr = [matchedEntry[@"expires"] ?: @"LIFETIME" uppercaseString];
            if (![expiresStr isEqualToString:@"LIFETIME"] && ![expiresStr isEqualToString:@"VINHVIEN"]) {
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateFormat = @"yyyy-MM-dd";
                df.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Ho_Chi_Minh"];
                NSDate *expDate = [df dateFromString:expiresStr];
                if (expDate) {
                    NSDate *endOfDay = [expDate dateByAddingTimeInterval:86399];
                    if ([[NSDate date] compare:endOfDay] == NSOrderedDescending) {
                        [self syncLicenseStateWithHook:NO];
                        if (completion) completion(NO, [NSString stringWithFormat:@"Key đã hết hạn (%@)!", expiresStr], nil, nil);
                        return;
                    }
                }
            }

            // 3. Check 1-Key-1-Device HWID Binding
            NSString *boundHwid = [[matchedEntry[@"hwid"] ?: @"" uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *owner = matchedEntry[@"owner"] ?: @"Khách VIP";
            NSString *expDisplay = ([expiresStr isEqualToString:@"LIFETIME"] || [expiresStr isEqualToString:@"VINHVIEN"]) ? @"Vĩnh viễn" : expiresStr;

            if (boundHwid.length == 0) {
                NSMutableDictionary *updatedEntry = [matchedEntry mutableCopy];
                updatedEntry[@"hwid"] = myHwid;
                NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
                updatedEntry[@"activatedAt"] = [iso stringFromDate:[NSDate date]];

                NSData *updatedData = [NSJSONSerialization dataWithJSONObject:updatedEntry options:0 error:nil];
                NSString *updatedJsonStr = [[NSString alloc] initWithData:updatedData encoding:NSUTF8StringEncoding];

                [self executeUpstashCommand:@[@"HSET", kRedisHashKey, matchedKeyName, updatedJsonStr] completion:^(id  _Nullable res2, NSError * _Nullable err2) {
                    [self executeUpstashCommand:@[@"HDEL", kRedisPendingHashKey, myHwid] completion:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self persistValidKey:matchedKeyName owner:owner expiryText:expDisplay];
                        if (completion) completion(YES, @"Kích hoạt bản quyền thành công!", owner, expDisplay);
                    });
                }];
                return;
            } else if (![boundHwid isEqualToString:@"*"] && ![boundHwid isEqualToString:myHwid]) {
                [self syncLicenseStateWithHook:NO];
                if (completion) completion(NO, @"Key này đã được kích hoạt trên thiết bị khác!", nil, nil);
                return;
            }

            [self executeUpstashCommand:@[@"HDEL", kRedisPendingHashKey, myHwid] completion:nil];
            [self persistValidKey:matchedKeyName owner:owner expiryText:expDisplay];
            if (completion) completion(YES, @"Xác thực bản quyền thành công!", owner, expDisplay);
        });
    }];
}

+ (void)refreshSavedLicenseInBackgroundWithCompletion:(void (^)(BOOL isValid, NSString *statusText))completion {
    NSString *savedKey = [self savedLicenseKey] ?: @"";
    [self verifyAndActivateKey:savedKey completion:^(BOOL isValid, NSString * _Nonnull message, NSString * _Nullable ownerName, NSString * _Nullable expiryText) {
        if (completion) {
            completion(isValid, isValid ? [self licenseStatusSummary] : message);
        }
    }];
}

@end
