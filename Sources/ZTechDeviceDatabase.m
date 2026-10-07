#import "ZTechDeviceDatabase.h"
#import <sys/utsname.h>
#import <spawn.h>

extern char **environ;

@implementation ZTechDeviceProfile

- (NSString *)summaryLine1 {
    return [NSString stringWithFormat:@"%@ (%@) · iOS %@",
            self.modelName ?: @"iPhone 15 Pro",
            self.machineId ?: @"iPhone16,1",
            self.iosVersion ?: @"17.1.2"];
}

- (NSString *)summaryLine2 {
    return [NSString stringWithFormat:@"Pin %ld%% · %@ · %@ · %@ · %ld danh bạ",
            (long)self.batteryPercent,
            self.carrier ?: @"MobiFone",
            self.wifiSsid ?: @"The Coffee House",
            self.city ?: @"Hải Phòng",
            (long)self.contactsCount];
}

- (NSString *)fullReportTextWithFlags:(BOOL)lockModel
                         respringAfter:(BOOL)respring
                            sameScreen:(BOOL)sameScreen
                             matchChip:(BOOL)matchChip {
    NSString *modeText = lockModel ? @"Khoá Đời Máy" : @"Fake Tất Cả";
    return [NSString stringWithFormat:
            @"=== gaulmt -Tech Device Report v3.0 ===\n"
            @"ID: %@\n"
            @"Device: %@ (%@) - iOS %@\n"
            @"Chip/RAM: %@ (%ldGB) - Screen: %@\n"
            @"Status: Pin %ld%% | %@ | %@ | %@ | %ld danh bạ\n"
            @"Config: LockModel=%@ | Respring=%@ | SameScreen=%@ | MatchChip=%@\n"
            @"Result: %ld mục thành công · 0 chưa ghi · Đã ghi %ld file (%@)",
            self.identifier,
            self.modelName, self.machineId, self.iosVersion,
            self.chipName, (long)self.ramGB, self.screenKey,
            (long)self.batteryPercent, self.carrier, self.wifiSsid, self.city, (long)self.contactsCount,
            lockModel ? @"ON" : @"OFF",
            respring ? @"ON" : @"OFF",
            sameScreen ? @"ON" : @"OFF",
            matchChip ? @"ON" : @"OFF",
            (long)self.successItemsCount, (long)self.writtenFilesCount, modeText];
}

- (NSDictionary *)toDictionary {
    return @{
        @"identifier": self.identifier ?: @"",
        @"modelName": self.modelName ?: @"",
        @"machineId": self.machineId ?: @"",
        @"iosVersion": self.iosVersion ?: @"",
        @"batteryPercent": @(self.batteryPercent),
        @"carrier": self.carrier ?: @"",
        @"wifiSsid": self.wifiSsid ?: @"",
        @"city": self.city ?: @"",
        @"contactsCount": @(self.contactsCount),
        @"chipName": self.chipName ?: @"",
        @"ramGB": @(self.ramGB),
        @"screenKey": self.screenKey ?: @"",
        @"writtenFilesCount": @(self.writtenFilesCount),
        @"successItemsCount": @(self.successItemsCount)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    ZTechDeviceProfile *p = [[ZTechDeviceProfile alloc] init];
    p.identifier = dict[@"identifier"] ?: [[NSUUID UUID] UUIDString];
    p.modelName = dict[@"modelName"] ?: @"iPhone 15 Pro";
    p.machineId = dict[@"machineId"] ?: @"iPhone16,1";
    p.iosVersion = dict[@"iosVersion"] ?: @"17.1.2";
    p.batteryPercent = [dict[@"batteryPercent"] integerValue] ?: 60;
    p.carrier = dict[@"carrier"] ?: @"MobiFone";
    p.wifiSsid = dict[@"wifiSsid"] ?: @"The Coffee House";
    p.city = dict[@"city"] ?: @"Hải Phòng";
    p.contactsCount = [dict[@"contactsCount"] integerValue] ?: 36;
    p.chipName = dict[@"chipName"] ?: @"A17 Pro";
    p.ramGB = [dict[@"ramGB"] integerValue] ?: 8;
    p.screenKey = dict[@"screenKey"] ?: @"393x852";
    p.writtenFilesCount = [dict[@"writtenFilesCount"] integerValue] ?: 7;
    p.successItemsCount = [dict[@"successItemsCount"] integerValue] ?: 10;
    return p;
}

@end

@implementation ZTechDeviceDatabase

+ (NSArray<NSDictionary *> *)allDeviceSpecs {
    return @[
        @{@"name": @"iPhone 8", @"machine": @"iPhone10,4", @"chip": @"A11 Bionic", @"ram": @2, @"screen": @"375x667", @"ios": @[@"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone SE (2020)", @"machine": @"iPhone12,8", @"chip": @"A13 Bionic", @"ram": @3, @"screen": @"375x667", @"ios": @[@"16.6.1", @"17.1.2", @"17.4.1"]},
        @{@"name": @"iPhone SE (2022)", @"machine": @"iPhone14,6", @"chip": @"A15 Bionic", @"ram": @4, @"screen": @"375x667", @"ios": @[@"16.6.1", @"17.1.2", @"17.3.1", @"17.4.1"]},
        @{@"name": @"iPhone 11", @"machine": @"iPhone12,1", @"chip": @"A13 Bionic", @"ram": @4, @"screen": @"414x896", @"ios": @[@"16.5.1", @"16.6.1", @"17.1.2"]},
        @{@"name": @"iPhone 11 Pro", @"machine": @"iPhone12,3", @"chip": @"A13 Bionic", @"ram": @4, @"screen": @"375x812", @"ios": @[@"16.6", @"16.7.2", @"17.1.2"]},
        @{@"name": @"iPhone 11 Pro Max", @"machine": @"iPhone12,5", @"chip": @"A13 Bionic", @"ram": @4, @"screen": @"414x896", @"ios": @[@"16.6.1", @"17.1.1", @"17.1.2"]},
        @{@"name": @"iPhone 12", @"machine": @"iPhone13,2", @"chip": @"A14 Bionic", @"ram": @4, @"screen": @"390x844", @"ios": @[@"16.6.1", @"16.7.2", @"17.1.2"]},
        @{@"name": @"iPhone 12 Pro", @"machine": @"iPhone13,3", @"chip": @"A14 Bionic", @"ram": @6, @"screen": @"390x844", @"ios": @[@"16.6.1", @"17.0.3", @"17.1.2"]},
        @{@"name": @"iPhone 12 Pro Max", @"machine": @"iPhone13,4", @"chip": @"A14 Bionic", @"ram": @6, @"screen": @"428x926", @"ios": @[@"16.6.1", @"17.1.1", @"17.1.2"]},
        @{@"name": @"iPhone 13", @"machine": @"iPhone14,5", @"chip": @"A15 Bionic", @"ram": @4, @"screen": @"390x844", @"ios": @[@"16.5", @"16.6.1", @"17.1.2", @"17.2.1"]},
        @{@"name": @"iPhone 13 Pro", @"machine": @"iPhone14,2", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"390x844", @"ios": @[@"16.6", @"17.1.2", @"17.2.1"]},
        @{@"name": @"iPhone 13 Pro Max", @"machine": @"iPhone14,3", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"428x926", @"ios": @[@"16.6.1", @"17.1.2", @"17.2.1"]},
        @{@"name": @"iPhone 14", @"machine": @"iPhone14,7", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"390x844", @"ios": @[@"16.6.1", @"17.1.1", @"17.1.2"]},
        @{@"name": @"iPhone 14 Plus", @"machine": @"iPhone14,8", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"428x926", @"ios": @[@"16.6.1", @"17.1.2", @"17.2.1"]},
        @{@"name": @"iPhone 14 Pro", @"machine": @"iPhone15,2", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"393x852", @"ios": @[@"16.6.1", @"17.0.3", @"17.1.2", @"17.3.1"]},
        @{@"name": @"iPhone 14 Pro Max", @"machine": @"iPhone15,3", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"430x932", @"ios": @[@"16.6.1", @"17.1.2", @"17.3.1"]},
        @{@"name": @"iPhone 15", @"machine": @"iPhone15,4", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"393x852", @"ios": @[@"17.0.3", @"17.1.1", @"17.1.2", @"17.4.1"]},
        @{@"name": @"iPhone 15 Plus", @"machine": @"iPhone15,5", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"430x932", @"ios": @[@"17.1.1", @"17.1.2", @"17.4.1"]},
        @{@"name": @"iPhone 15 Pro", @"machine": @"iPhone16,1", @"chip": @"A17 Pro", @"ram": @8, @"screen": @"393x852", @"ios": @[@"17.1.1", @"17.1.2", @"17.2.1", @"17.4.1"]},
        @{@"name": @"iPhone 15 Pro Max", @"machine": @"iPhone16,2", @"chip": @"A17 Pro", @"ram": @8, @"screen": @"430x932", @"ios": @[@"17.1.1", @"17.1.2", @"17.2.1", @"17.4.1"]}
    ];
}

+ (NSString *)realHardwareMachine {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if (!machine || ![machine hasPrefix:@"iPhone"]) {
        return @"iPhone16,1";
    }
    return machine;
}

+ (NSString *)realScreenKey {
    CGSize size = [UIScreen mainScreen].bounds.size;
    NSInteger w = (NSInteger)MIN(size.width, size.height);
    NSInteger h = (NSInteger)MAX(size.width, size.height);
    return [NSString stringWithFormat:@"%ldx%ld", (long)w, (long)h];
}

+ (NSDictionary *)realDeviceSpecFallback {
    NSString *realMachine = [self realHardwareMachine];
    for (NSDictionary *spec in [self allDeviceSpecs]) {
        if ([spec[@"machine"] isEqualToString:realMachine]) {
            return spec;
        }
    }
    NSString *screenKey = [self realScreenKey];
    for (NSDictionary *spec in [self allDeviceSpecs]) {
        if ([spec[@"screen"] isEqualToString:screenKey]) {
            return spec;
        }
    }
    return [self allDeviceSpecs][18];
}

+ (ZTechDeviceProfile *)loadOrCreateDefaultProfile {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ZTechCurrentProfile"];
    if (saved) {
        ZTechDeviceProfile *loaded = [ZTechDeviceProfile fromDictionary:saved];
        if (loaded) {
            [self writeProfileFiles:loaded error:nil];
            return loaded;
        }
    }
    ZTechDeviceProfile *initial = [[ZTechDeviceProfile alloc] init];
    initial.identifier = @"7BD46FDA-D93D-45BD-9158-7178669502DD";
    initial.modelName = @"iPhone 15 Pro";
    initial.machineId = @"iPhone16,1";
    initial.iosVersion = @"17.1.2";
    initial.batteryPercent = 60;
    initial.carrier = @"MobiFone";
    initial.wifiSsid = @"The Coffee House";
    initial.city = @"Hải Phòng";
    initial.contactsCount = 36;
    initial.chipName = @"A17 Pro";
    initial.ramGB = 8;
    initial.screenKey = @"393x852";
    initial.writtenFilesCount = 7;
    initial.successItemsCount = 10;
    [self writeProfileFiles:initial error:nil];
    return initial;
}

+ (ZTechDeviceProfile *)generateProfileWithLockRealModel:(BOOL)lockModel
                                              sameScreen:(BOOL)sameScreen
                                               matchChip:(BOOL)matchChip
                                             currentCity:(NSString *)currentCity {
    NSArray<NSDictionary *> *allSpecs = [self allDeviceSpecs];
    NSDictionary *realSpec = [self realDeviceSpecFallback];
    NSString *realScreen = [self realScreenKey];
    NSDictionary *prevSaved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ZTechCurrentProfile"];
    NSString *prevMachine = prevSaved[@"machineId"];

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];

    if (lockModel) {
        [candidates addObject:realSpec];
    } else {
        for (NSDictionary *spec in allSpecs) {
            BOOL ok = YES;
            if (sameScreen && ![spec[@"screen"] isEqualToString:realScreen] && ![spec[@"screen"] isEqualToString:realSpec[@"screen"]]) {
                ok = NO;
            }
            if (matchChip && ![spec[@"ram"] isEqualToNumber:realSpec[@"ram"]]) {
                ok = NO;
            }
            if (ok) {
                [candidates addObject:spec];
            }
        }
        if (candidates.count <= 1 && sameScreen) {
            [candidates removeAllObjects];
            for (NSDictionary *spec in allSpecs) {
                if ([spec[@"screen"] isEqualToString:realScreen] || [spec[@"screen"] isEqualToString:realSpec[@"screen"]]) {
                    [candidates addObject:spec];
                }
            }
        }
        if (candidates.count <= 1) {
            candidates = [allSpecs mutableCopy];
        }
        if (candidates.count > 1 && prevMachine.length > 0) {
            NSMutableArray<NSDictionary *> *nonRepeat = [NSMutableArray array];
            for (NSDictionary *spec in candidates) {
                if (![spec[@"machine"] isEqualToString:prevMachine]) {
                    [nonRepeat addObject:spec];
                }
            }
            if (nonRepeat.count > 0) {
                candidates = nonRepeat;
            }
        }
    }

    NSDictionary *chosen = candidates[arc4random_uniform((uint32_t)candidates.count)];
    NSArray<NSString *> *iosList = chosen[@"ios"];
    NSString *chosenIOS = iosList[arc4random_uniform((uint32_t)iosList.count)];

    NSArray<NSString *> *carriers = @[@"MobiFone", @"Viettel", @"Vinaphone", @"Vietnamobile"];
    NSArray<NSString *> *wifis = @[
        @"The Coffee House",
        @"Highlands Coffee",
        @"PhucLong_FreeWiFi",
        @"Starbucks_VN",
        @"Viettel_Home_5G",
        @"FPT_Telecom_5G",
        @"VNPT_Fiber_5G",
        @"Aha_Cafe_WiFi"
    ];
    NSArray<NSString *> *cities = @[
        @"Hải Phòng", @"Hà Nội", @"TP. Hồ Chí Minh", @"Đà Nẵng", @"Quảng Ninh", @"Cần Thơ"
    ];

    ZTechDeviceProfile *profile = [[ZTechDeviceProfile alloc] init];
    profile.identifier = [[[NSUUID UUID] UUIDString] uppercaseString];
    profile.modelName = chosen[@"name"];
    profile.machineId = chosen[@"machine"];
    profile.iosVersion = chosenIOS;
    profile.batteryPercent = 20 + arc4random_uniform(76);
    profile.carrier = carriers[arc4random_uniform((uint32_t)carriers.count)];
    profile.wifiSsid = wifis[arc4random_uniform((uint32_t)wifis.count)];
    profile.city = cities[arc4random_uniform((uint32_t)cities.count)];
    profile.contactsCount = 15 + arc4random_uniform(95);
    profile.chipName = chosen[@"chip"];
    profile.ramGB = [chosen[@"ram"] integerValue];
    profile.screenKey = chosen[@"screen"];

    [self writeProfileFiles:profile error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:[profile toDictionary] forKey:@"ZTechCurrentProfile"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    return profile;
}

+ (NSString *)storageDirectoryPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *jbPrefPath = @"/var/jb/var/mobile/Library/Preferences/ZTechProfile";
    if ([fm fileExistsAtPath:@"/var/jb/var/mobile/Library/Preferences"] &&
        [fm isWritableFileAtPath:@"/var/jb/var/mobile/Library/Preferences"]) {
        return jbPrefPath;
    }
    NSString *rootPrefPath = @"/var/mobile/Library/Preferences/ZTechProfile";
    if ([fm isWritableFileAtPath:@"/var/mobile/Library/Preferences"]) {
        return rootPrefPath;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:@"ZTechProfile"];
}

+ (BOOL)writeProfileFiles:(ZTechDeviceProfile *)profile error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self storageDirectoryPath];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSDictionary<NSString *, NSDictionary *> *filesToWrite = @{
        @"01_identity.plist": @{
            @"UUID": profile.identifier ?: @"",
            @"VendorID": [[NSUUID UUID] UUIDString],
            @"Timestamp": @([[NSDate date] timeIntervalSince1970])
        },
        @"02_hardware.plist": @{
            @"ModelName": profile.modelName ?: @"",
            @"Machine": profile.machineId ?: @"",
            @"Chip": profile.chipName ?: @"",
            @"RAM_GB": @(profile.ramGB)
        },
        @"03_system_os.plist": @{
            @"OSVersion": profile.iosVersion ?: @"",
            @"BuildVersion": @"21B101"
        },
        @"04_screen_display.plist": @{
            @"ScreenResolution": profile.screenKey ?: @"393x852",
            @"Scale": @3
        },
        @"05_network_carrier.plist": @{
            @"CarrierName": profile.carrier ?: @"MobiFone",
            @"WiFiSSID": profile.wifiSsid ?: @"The Coffee House"
        },
        @"06_battery_power.plist": @{
            @"BatteryLevel": @(profile.batteryPercent),
            @"BatteryState": @"Unplugged"
        },
        @"07_region_contacts.plist": @{
            @"City": profile.city ?: @"Hải Phòng",
            @"ContactsCount": @(profile.contactsCount)
        }
    };

    NSInteger written = 0;
    for (NSString *fileName in filesToWrite) {
        NSString *fullPath = [dir stringByAppendingPathComponent:fileName];
        NSDictionary *content = filesToWrite[fileName];
        if ([content writeToFile:fullPath atomically:YES]) {
            NSDictionary *verify = [NSDictionary dictionaryWithContentsOfFile:fullPath];
            if (verify && verify.count > 0) {
                written++;
            }
        }
    }
    profile.writtenFilesCount = written;
    profile.successItemsCount = (written == 7) ? 10 : (written * 10 / 7);
    return (written == 7);
}

+ (void)syncLocationByIPWithCompletion:(void (^)(NSString *city, NSString *isp, NSError *error))completion {
    NSURL *url = [NSURL URLWithString:@"https://ipwho.is/"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, error);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *city = json[@"city"];
        NSDictionary *conn = json[@"connection"];
        NSString *isp = [conn isKindOfClass:[NSDictionary class]] ? conn[@"isp"] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(city, isp, nil);
        });
    }];
    [task resume];
}

+ (void)performRespringIfPossible {
    NSArray<NSString *> *candidates = @[
        @"/var/jb/usr/bin/sbreload",
        @"/usr/bin/sbreload",
        @"/var/jb/usr/bin/killall",
        @"/usr/bin/killall"
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *bin in candidates) {
        if ([fm isExecutableFileAtPath:bin]) {
            pid_t pid;
            if ([bin hasSuffix:@"sbreload"]) {
                const char *args[] = { [bin UTF8String], NULL };
                posix_spawn(&pid, [bin UTF8String], NULL, NULL, (char *const *)args, environ);
            } else {
                const char *args[] = { [bin UTF8String], "-9", "SpringBoard", NULL };
                posix_spawn(&pid, [bin UTF8String], NULL, NULL, (char *const *)args, environ);
            }
            break;
        }
    }
}

@end
