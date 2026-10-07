#import "ZTechVaultManager.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/stat.h>
#import <unistd.h>
#import <spawn.h>

extern char **environ;

@implementation ZTechVaultAccount

- (NSDictionary *)toDictionary {
    return @{
        @"accountId": self.accountId ?: @"",
        @"title": self.title ?: @"Acc Zalo",
        @"proxyString": self.proxyString ?: @"",
        @"createdAt": self.createdAt ?: @"",
        @"deviceProfileDict": self.deviceProfileDict ?: @{}
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    ZTechVaultAccount *acc = [[ZTechVaultAccount alloc] init];
    acc.accountId = dict[@"accountId"] ?: @"";
    if (acc.accountId.length == 0) return nil;
    acc.title = dict[@"title"] ?: @"Acc Zalo";
    acc.proxyString = dict[@"proxyString"] ?: @"";
    acc.createdAt = dict[@"createdAt"] ?: @"";
    acc.deviceProfileDict = [dict[@"deviceProfileDict"] isKindOfClass:[NSDictionary class]] ? dict[@"deviceProfileDict"] : @{};
    return acc;
}

- (NSString *)shortDeviceSummary {
    NSString *model = self.deviceProfileDict[@"modelName"] ?: @"iPhone 16 Pro Max";
    NSString *ios = self.deviceProfileDict[@"iosVersion"] ?: @"18.2";
    NSString *uuid = self.deviceProfileDict[@"identifier"] ?: @"";
    NSString *shortUuid = (uuid.length >= 8) ? [uuid substringToIndex:8] : uuid;
    return [NSString stringWithFormat:@"%@ · iOS %@ · ID:%@", model, ios, shortUuid];
}

- (NSString *)proxyDisplayText {
    if (!self.proxyString || self.proxyString.length == 0) {
        return @"🌐 Mạng trực tiếp (Không Proxy / 4G)";
    }
    return [NSString stringWithFormat:@"🛡 Proxy: %@", self.proxyString];
}

@end

@implementation ZTechVaultManager

+ (NSString *)vaultRootDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candidates = @[
        @"/var/jb/var/mobile/Library/Preferences/ZTechVault",
        @"/var/mobile/Library/Preferences/ZTechVault"
    ];
    for (NSString *path in candidates) {
        NSString *parent = [path stringByDeletingLastPathComponent];
        if ([fm fileExistsAtPath:parent] && [fm isWritableFileAtPath:parent]) {
            if (![fm fileExistsAtPath:path]) {
                [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
                chmod([path UTF8String], 0777);
            }
            return path;
        }
    }
    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *fallback = [docs.firstObject stringByAppendingPathComponent:@"ZTechVault"];
    if (![fm fileExistsAtPath:fallback]) {
        [fm createDirectoryAtPath:fallback withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return fallback;
}

+ (NSString *)indexFilePath {
    return [[self vaultRootDirectory] stringByAppendingPathComponent:@"vault_index.plist"];
}

+ (NSString *)activeAccountId {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"ZTechActiveVaultAccountId"];
}

+ (NSArray<ZTechVaultAccount *> *)listSavedAccounts {
    NSArray *rawList = [NSArray arrayWithContentsOfFile:[self indexFilePath]];
    if (!rawList || ![rawList isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray<ZTechVaultAccount *> *result = [NSMutableArray array];
    for (NSDictionary *item in rawList) {
        ZTechVaultAccount *acc = [ZTechVaultAccount fromDictionary:item];
        if (acc) {
            [result addObject:acc];
        }
    }
    return result;
}

+ (void)saveAccountsList:(NSArray<ZTechVaultAccount *> *)accounts {
    NSMutableArray *raw = [NSMutableArray arrayWithCapacity:accounts.count];
    for (ZTechVaultAccount *acc in accounts) {
        [raw addObject:[acc toDictionary]];
    }
    NSString *indexPath = [self indexFilePath];
    [raw writeToFile:indexPath atomically:YES];
    chmod([indexPath UTF8String], 0666);
}

+ (void)killZaloProcess {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *killBins = @[@"/var/jb/usr/bin/killall", @"/usr/bin/killall"];
    for (NSString *bin in killBins) {
        if ([fm isExecutableFileAtPath:bin]) {
            pid_t pid;
            const char *args[] = { [bin UTF8String], "-9", "Zalo", NULL };
            posix_spawn(&pid, [bin UTF8String], NULL, NULL, (char *const *)args, environ);
            break;
        }
    }
}

+ (nullable NSString *)findZaloDataContainerPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *roots = @[
        @"/var/mobile/Containers/Data/Application",
        @"/private/var/mobile/Containers/Data/Application"
    ];
    for (NSString *root in roots) {
        NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *uuid in uuids) {
            NSString *container = [root stringByAppendingPathComponent:uuid];
            NSString *metaPath = [container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
            NSString *bundleId = [meta[@"MCMMetadataIdentifier"] lowercaseString];
            if ([bundleId isEqualToString:@"vn.com.vng.zalo"] || [bundleId containsString:@"zalo"]) {
                return container;
            }
        }
    }
    return nil;
}

+ (NSDictionary<NSString *, NSString *> *)findZaloAppGroupContainers {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableDictionary<NSString *, NSString *> *groups = [NSMutableDictionary dictionary];
    NSArray<NSString *> *roots = @[
        @"/var/mobile/Containers/Shared/AppGroup",
        @"/private/var/mobile/Containers/Shared/AppGroup"
    ];
    for (NSString *root in roots) {
        NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *uuid in uuids) {
            NSString *container = [root stringByAppendingPathComponent:uuid];
            NSString *metaPath = [container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
            NSString *groupId = [meta[@"MCMMetadataIdentifier"] lowercaseString];
            if ([groupId containsString:@"zalo"] || [groupId containsString:@"vng"]) {
                groups[groupId] = container;
            }
        }
    }
    return groups;
}

+ (void)copyDirectoryContentsFrom:(NSString *)srcDir to:(NSString *)dstDir fileManager:(NSFileManager *)fm fixMobileOwner:(BOOL)fixOwner {
    if (![fm fileExistsAtPath:srcDir]) return;
    if (![fm fileExistsAtPath:dstDir]) {
        [fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:nil];
        if (fixOwner) {
            chown([dstDir UTF8String], 501, 501);
        }
        chmod([dstDir UTF8String], 0777);
    }

    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:srcDir error:nil];
    for (NSString *item in items) {
        if ([item isEqualToString:@".com.apple.mobile_container_manager.metadata.plist"] ||
            [item hasPrefix:@".GlobalPreferences"] ||
            [item isEqualToString:@"SplashBoard"] ||
            [item isEqualToString:@"Caches"]) {
            continue;
        }
        NSString *srcPath = [srcDir stringByAppendingPathComponent:item];
        NSString *dstPath = [dstDir stringByAppendingPathComponent:item];

        // Check if symlink
        NSDictionary *attrs = [fm attributesOfItemAtPath:srcPath error:nil];
        if ([attrs[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
            continue;
        }

        [fm removeItemAtPath:dstPath error:nil];
        [fm copyItemAtPath:srcPath toPath:dstPath error:nil];

        if (fixOwner) {
            [self recursivelyFixMobileOwnershipAtPath:dstPath fileManager:fm];
        }
    }
}

+ (void)recursivelyFixMobileOwnershipAtPath:(NSString *)path fileManager:(NSFileManager *)fm {
    chown([path UTF8String], 501, 501);
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        chmod([path UTF8String], 0777);
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
        NSString *relPath = nil;
        while ((relPath = [enumerator nextObject])) {
            NSString *full = [path stringByAppendingPathComponent:relPath];
            lchown([full UTF8String], 501, 501);
            BOOL subDir = NO;
            if ([fm fileExistsAtPath:full isDirectory:&subDir]) {
                chmod([full UTF8String], subDir ? 0777 : 0666);
            }
        }
    } else {
        chmod([path UTF8String], 0666);
    }
}

+ (nullable ZTechVaultAccount *)saveCurrentZaloSessionWithTitle:(nullable NSString *)title
                                                          proxy:(nullable NSString *)proxyString
                                                        profile:(ZTechDeviceProfile *)profile
                                                          error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *zaloContainer = [self findZaloDataContainerPath];
    if (!zaloContainer) {
        if (error) {
            *error = [NSError errorWithDomain:@"ZTechVault"
                                         code:404
                                     userInfo:@{NSLocalizedDescriptionKey: @"Không tìm thấy thư mục dữ liệu Zalo trên máy. Hãy cài đặt và mở Zalo ít nhất 1 lần."}];
        }
        return nil;
    }

    NSMutableArray<ZTechVaultAccount *> *accounts = [[self listSavedAccounts] mutableCopy];
    NSInteger nextIndex = accounts.count + 1;
    NSString *accId = [NSString stringWithFormat:@"ACC-%03ld-%04u", (long)nextIndex, arc4random_uniform(9000) + 1000];

    NSString *cleanTitle = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!cleanTitle || cleanTitle.length == 0) {
        cleanTitle = [NSString stringWithFormat:@"Acc Zalo #%ld (%@)", (long)nextIndex, profile.modelName ?: @"iPhone"];
    }

    NSString *cleanProxy = [proxyString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"dd/MM HH:mm";
    NSString *nowStr = [df stringFromDate:[NSDate date]];

    // Update profile proxy before saving
    profile.activeProxy = cleanProxy;
    [ZTechDeviceDatabase writeProfileFiles:profile error:nil];

    NSString *slotDir = [[self vaultRootDirectory] stringByAppendingPathComponent:accId];
    NSString *dataBackupDir = [slotDir stringByAppendingPathComponent:@"DataContainer"];
    NSString *groupBackupDir = [slotDir stringByAppendingPathComponent:@"AppGroups"];
    [fm createDirectoryAtPath:dataBackupDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:groupBackupDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Copy key Zalo directories
    NSArray<NSString *> *subFolders = @[
        @"Documents",
        @"Library/Preferences",
        @"Library/Application Support",
        @"Library/Cookies"
    ];
    for (NSString *sub in subFolders) {
        NSString *src = [zaloContainer stringByAppendingPathComponent:sub];
        NSString *dst = [dataBackupDir stringByAppendingPathComponent:sub];
        [self copyDirectoryContentsFrom:src to:dst fileManager:fm fixMobileOwner:NO];
    }

    // Copy Zalo AppGroup containers (holds shared auth tokens & database)
    NSDictionary<NSString *, NSString *> *appGroups = [self findZaloAppGroupContainers];
    for (NSString *groupId in appGroups) {
        NSString *groupContainer = appGroups[groupId];
        NSString *dstGroup = [groupBackupDir stringByAppendingPathComponent:groupId];
        for (NSString *sub in subFolders) {
            NSString *src = [groupContainer stringByAppendingPathComponent:sub];
            NSString *dst = [dstGroup stringByAppendingPathComponent:sub];
            [self copyDirectoryContentsFrom:src to:dst fileManager:fm fixMobileOwner:NO];
        }
    }

    ZTechVaultAccount *newAcc = [[ZTechVaultAccount alloc] init];
    newAcc.accountId = accId;
    newAcc.title = cleanTitle;
    newAcc.proxyString = cleanProxy;
    newAcc.createdAt = nowStr;
    newAcc.deviceProfileDict = [profile toDictionary];

    [accounts insertObject:newAcc atIndex:0];
    [self saveAccountsList:accounts];

    [[NSUserDefaults standardUserDefaults] setObject:accId forKey:@"ZTechActiveVaultAccountId"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    return newAcc;
}

+ (BOOL)restoreAndLaunchAccount:(ZTechVaultAccount *)account
                     outProfile:(ZTechDeviceProfile * _Nullable * _Nullable)outProfile
                          error:(NSError **)error {
    if (!account || account.accountId.length == 0) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *slotDir = [[self vaultRootDirectory] stringByAppendingPathComponent:account.accountId];
    NSString *dataBackupDir = [slotDir stringByAppendingPathComponent:@"DataContainer"];
    if (![fm fileExistsAtPath:dataBackupDir]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ZTechVault"
                                         code:404
                                     userInfo:@{NSLocalizedDescriptionKey: @"Không tìm thấy dữ liệu sao lưu của Acc này trong Kho."}];
        }
        return NO;
    }

    NSString *zaloContainer = [self findZaloDataContainerPath];
    if (!zaloContainer) {
        if (error) {
            *error = [NSError errorWithDomain:@"ZTechVault"
                                         code:404
                                     userInfo:@{NSLocalizedDescriptionKey: @"Không tìm thấy thư mục Zalo trên thiết bị."}];
        }
        return NO;
    }

    // 1. Kill Zalo first so SQLite databases are unlocked
    [self killZaloProcess];
    usleep(250000); // 250ms

    // 2. Restore Device Profile + Proxy
    ZTechDeviceProfile *restoredProfile = [ZTechDeviceProfile fromDictionary:account.deviceProfileDict];
    if (!restoredProfile) {
        restoredProfile = [ZTechDeviceDatabase loadOrCreateDefaultProfile];
    }
    restoredProfile.activeProxy = account.proxyString ?: @"";
    [ZTechDeviceDatabase writeProfileFiles:restoredProfile error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:[restoredProfile toDictionary] forKey:@"ZTechCurrentProfile"];
    [[NSUserDefaults standardUserDefaults] setObject:account.accountId forKey:@"ZTechActiveVaultAccountId"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (outProfile) {
        *outProfile = restoredProfile;
    }

    // 3. Clean existing Zalo container subdirectories while keeping container structure intact
    NSArray<NSString *> *cleanSubs = @[
        @"Documents",
        @"tmp",
        @"Library/Caches",
        @"Library/Cookies",
        @"Library/Preferences",
        @"Library/WebKit",
        @"Library/Application Support"
    ];
    for (NSString *sub in cleanSubs) {
        NSString *dirPath = [zaloContainer stringByAppendingPathComponent:sub];
        NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:dirPath error:nil];
        for (NSString *item in items) {
            if ([item hasPrefix:@".GlobalPreferences"] || [item hasPrefix:@".com.apple."]) {
                continue;
            }
            [fm removeItemAtPath:[dirPath stringByAppendingPathComponent:item] error:nil];
        }
    }

    // 4. Pump backed-up DataContainer files back into Zalo
    NSArray<NSString *> *restoreSubs = @[
        @"Documents",
        @"Library/Preferences",
        @"Library/Application Support",
        @"Library/Cookies"
    ];
    for (NSString *sub in restoreSubs) {
        NSString *src = [dataBackupDir stringByAppendingPathComponent:sub];
        NSString *dst = [zaloContainer stringByAppendingPathComponent:sub];
        [self copyDirectoryContentsFrom:src to:dst fileManager:fm fixMobileOwner:YES];
    }

    // 5. Pump backed-up AppGroup files back into Zalo's Shared AppGroups
    NSString *groupBackupDir = [slotDir stringByAppendingPathComponent:@"AppGroups"];
    NSDictionary<NSString *, NSString *> *appGroups = [self findZaloAppGroupContainers];
    for (NSString *groupId in appGroups) {
        NSString *liveGroupPath = appGroups[groupId];
        for (NSString *sub in cleanSubs) {
            NSString *dirPath = [liveGroupPath stringByAppendingPathComponent:sub];
            NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:dirPath error:nil];
            for (NSString *item in items) {
                if ([item hasPrefix:@".GlobalPreferences"] || [item hasPrefix:@".com.apple."]) continue;
                [fm removeItemAtPath:[dirPath stringByAppendingPathComponent:item] error:nil];
            }
        }
        NSString *savedGroupPath = [groupBackupDir stringByAppendingPathComponent:groupId];
        if ([fm fileExistsAtPath:savedGroupPath]) {
            for (NSString *sub in restoreSubs) {
                NSString *src = [savedGroupPath stringByAppendingPathComponent:sub];
                NSString *dst = [liveGroupPath stringByAppendingPathComponent:sub];
                [self copyDirectoryContentsFrom:src to:dst fileManager:fm fixMobileOwner:YES];
            }
        }
    }

    // 6. Write restore trigger so ZTechHook.dylib imports backed-up Keychain & NSUserDefaults inside Zalo on launch
    NSString *docsDir = [zaloContainer stringByAppendingPathComponent:@"Documents"];
    NSString *triggerFile = [docsDir stringByAppendingPathComponent:@"_zt_restore_trigger.txt"];
    [account.accountId writeToFile:triggerFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    chown([triggerFile UTF8String], 501, 501);
    chmod([triggerFile UTF8String], 0666);

    // Ensure .GlobalPreferences symlink exists
    NSString *globalPrefsLink = [zaloContainer stringByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
    if (![fm fileExistsAtPath:globalPrefsLink]) {
        symlink("/private/var/mobile/Library/Preferences/.GlobalPreferences.plist", [globalPrefsLink UTF8String]);
        lchown([globalPrefsLink UTF8String], 501, 501);
    }

    // 7. Launch Zalo automatically!
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self launchZaloApp];
    });

    return YES;
}

+ (BOOL)updateAccount:(NSString *)accountId
                title:(nullable NSString *)title
          proxyString:(nullable NSString *)proxyString {
    NSMutableArray<ZTechVaultAccount *> *accounts = [[self listSavedAccounts] mutableCopy];
    BOOL found = NO;
    NSString *cleanProxy = [proxyString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";

    for (ZTechVaultAccount *acc in accounts) {
        if ([acc.accountId isEqualToString:accountId]) {
            if (title && title.length > 0) {
                acc.title = title;
            }
            acc.proxyString = cleanProxy;
            NSMutableDictionary *profMut = [acc.deviceProfileDict mutableCopy] ?: [NSMutableDictionary dictionary];
            profMut[@"activeProxy"] = cleanProxy;
            acc.deviceProfileDict = profMut;
            found = YES;

            // If this account is currently active, immediately apply the new proxy to active profile
            if ([[self activeAccountId] isEqualToString:accountId]) {
                ZTechDeviceProfile *cur = [ZTechDeviceDatabase loadOrCreateDefaultProfile];
                cur.activeProxy = cleanProxy;
                [ZTechDeviceDatabase writeProfileFiles:cur error:nil];
                [[NSUserDefaults standardUserDefaults] setObject:[cur toDictionary] forKey:@"ZTechCurrentProfile"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            break;
        }
    }
    if (found) {
        [self saveAccountsList:accounts];
    }
    return found;
}

+ (BOOL)deleteAccountWithId:(NSString *)accountId {
    if (!accountId || accountId.length == 0) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *slotDir = [[self vaultRootDirectory] stringByAppendingPathComponent:accountId];
    [fm removeItemAtPath:slotDir error:nil];

    NSMutableArray<ZTechVaultAccount *> *accounts = [[self listSavedAccounts] mutableCopy];
    NSIndexSet *toRemove = [accounts indexesOfObjectsPassingTest:^BOOL(ZTechVaultAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.accountId isEqualToString:accountId];
    }];
    if (toRemove.count > 0) {
        [accounts removeObjectsAtIndexes:toRemove];
        [self saveAccountsList:accounts];
        return YES;
    }
    return NO;
}

+ (void)launchZaloApp {
    @try {
        Class wsCls = NSClassFromString(@"LSApplicationWorkspace");
        if (wsCls) {
            id ws = ((id (*)(id, SEL))objc_msgSend)(wsCls, sel_registerName("defaultWorkspace"));
            if (ws) {
                SEL openSel = sel_registerName("openApplicationWithBundleID:");
                if ([ws respondsToSelector:openSel]) {
                    BOOL opened = ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws, openSel, @"vn.com.vng.zalo");
                    if (opened) return;
                }
            }
        }
        NSURL *zaloUrl = [NSURL URLWithString:@"zalo://"];
        if ([[UIApplication sharedApplication] canOpenURL:zaloUrl]) {
            [[UIApplication sharedApplication] openURL:zaloUrl options:@{} completionHandler:nil];
        }
    } @catch (NSException *e) {}
}

@end
