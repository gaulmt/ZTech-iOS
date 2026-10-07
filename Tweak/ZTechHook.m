#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>

#pragma mark - Embedded Fishhook (Mach-O Symbol Rebinding for AIDA64 & Apps)

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#ifndef SEG_DATA_CONST
#define SEG_DATA_CONST "__DATA_CONST"
#endif

struct zt_rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

static struct zt_rebinding gRebindings[8];
static size_t gRebindingsCount = 0;

static void perform_rebinding_with_section(section_t *section,
                                           intptr_t slide,
                                           nlist_t *symtab,
                                           char *strtab,
                                           uint32_t *indirect_symtab) {
    uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);
    for (uint i = 0; i < section->size / sizeof(void *); i++) {
        uint32_t symtab_index = indirect_symbol_indices[i];
        if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL ||
            symtab_index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        if (symbol_name[0] == '\0') continue;
        for (size_t j = 0; j < gRebindingsCount; j++) {
            if (strcmp(&symbol_name[1], gRebindings[j].name) == 0) {
                if (gRebindings[j].replaced != NULL && *gRebindings[j].replaced == NULL &&
                    indirect_symbol_bindings[i] != gRebindings[j].replacement) {
                    *gRebindings[j].replaced = indirect_symbol_bindings[i];
                }
                indirect_symbol_bindings[i] = gRebindings[j].replacement;
                break;
            }
        }
    }
}

static void rebind_symbols_for_image(const struct mach_header *header, intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) return;

    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    struct symtab_command *symtab_cmd = NULL;
    struct dysymtab_command *dysymtab_cmd = NULL;

    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (struct symtab_command *)cur_seg_cmd;
        } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
            dysymtab_cmd = (struct dysymtab_command *)cur_seg_cmd;
        }
    }

    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment || !dysymtab_cmd->nindirectsyms) return;

    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

    cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0 &&
                strcmp(cur_seg_cmd->segname, SEG_DATA_CONST) != 0) {
                continue;
            }
            for (uint j = 0; j < cur_seg_cmd->nsects; j++) {
                section_t *sect = (section_t *)(cur + sizeof(segment_command_t)) + j;
                uint32_t flags = sect->flags & SECTION_TYPE;
                if (flags == S_LAZY_SYMBOL_POINTERS || flags == S_NON_LAZY_SYMBOL_POINTERS) {
                    perform_rebinding_with_section(sect, slide, symtab, strtab, indirect_symtab);
                }
            }
        }
    }
}

#pragma mark - Profile Loader (Enforces Model >= iPhone 8 & iOS >= 16.0)

static NSDictionary *gCachedProfile = nil;

static NSDictionary *ZTechNormalizeProfile(NSDictionary *raw) {
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:raw ?: @{}];
    NSString *machine = m[@"machineId"];
    if (!machine || machine.length == 0 ||
        [machine hasPrefix:@"iPhone9,"] || [machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone7,"]) {
        m[@"machineId"] = @"iPhone15,2";
        m[@"modelName"] = @"iPhone 14 Pro";
    }
    NSString *ios = m[@"iosVersion"];
    if (!ios || [ios integerValue] < 16) {
        m[@"iosVersion"] = @"16.6.1";
    }
    if (!m[@"ramGB"] || [m[@"ramGB"] integerValue] < 2) {
        m[@"ramGB"] = @6;
    }
    if (!m[@"batteryPercent"] || [m[@"batteryPercent"] integerValue] <= 0) {
        m[@"batteryPercent"] = @68;
    }
    if (!m[@"identifier"] || [m[@"identifier"] length] == 0) {
        m[@"identifier"] = @"7BD46FDA-D93D-45BD-9158-7178669502DD";
    }
    return m;
}

static NSDictionary *ZTechLoadProfile(void) {
    // 1. Read from Global CFPreferences (.GlobalPreferences) accessible inside all sandboxed App Store apps
    CFPropertyListRef cfVal = CFPreferencesCopyAppValue(CFSTR("ZTechGlobalProfile"), kCFPreferencesAnyApplication);
    if (cfVal) {
        if (CFGetTypeID(cfVal) == CFDictionaryGetTypeID()) {
            NSDictionary *d = (__bridge_transfer NSDictionary *)cfVal;
            gCachedProfile = ZTechNormalizeProfile(d);
            return gCachedProfile;
        }
        CFRelease(cfVal);
    }

    // 2. Read from shared plist paths
    NSArray<NSString *> *paths = @[
        @"/Library/Preferences/ZTechShared/com.ztech.profile.plist",
        @"/var/jb/Library/Preferences/ZTechShared/com.ztech.profile.plist",
        @"/var/jb/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/tmp/com.ztech.profile.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (dict && [dict isKindOfClass:[NSDictionary class]]) {
            gCachedProfile = ZTechNormalizeProfile(dict);
            return gCachedProfile;
        }
    }

    // 3. Guaranteed fallback (>= iPhone 8 & >= iOS 16.0)
    if (!gCachedProfile) {
        gCachedProfile = ZTechNormalizeProfile(nil);
    }
    return gCachedProfile;
}

#pragma mark - C Function Hooks (uname, sysctlbyname, sysctl, MGCopyAnswer)

static int (*orig_uname)(struct utsname *buf) = NULL;
static int hooked_uname(struct utsname *buf) {
    int ret = orig_uname ? orig_uname(buf) : 0;
    if (buf != NULL) {
        NSDictionary *prof = ZTechLoadProfile();
        NSString *machine = prof[@"machineId"] ?: @"iPhone15,2";
        strncpy(buf->machine, [machine UTF8String], sizeof(buf->machine) - 1);
        buf->machine[sizeof(buf->machine) - 1] = '\0';
    }
    return ret;
}

static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) = NULL;
static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name != NULL) {
        NSDictionary *prof = ZTechLoadProfile();
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.product") == 0 || strcmp(name, "hw.model") == 0) {
            NSString *machine = prof[@"machineId"] ?: @"iPhone15,2";
            const char *cstr = [machine UTF8String];
            size_t len = strlen(cstr) + 1;
            if (oldp != NULL && oldlenp != NULL) {
                size_t copyLen = (*oldlenp < len) ? *oldlenp : len;
                memcpy(oldp, cstr, copyLen);
            }
            if (oldlenp != NULL) {
                *oldlenp = len;
            }
            return 0;
        } else if (strcmp(name, "hw.memsize") == 0 || strcmp(name, "hw.physmem") == 0) {
            NSInteger ramGB = [prof[@"ramGB"] integerValue] ?: 6;
            if (oldp != NULL && oldlenp != NULL && *oldlenp >= sizeof(uint64_t)) {
                uint64_t memBytes = (uint64_t)ramGB * 1024ULL * 1024ULL * 1024ULL;
                memcpy(oldp, &memBytes, sizeof(uint64_t));
                *oldlenp = sizeof(uint64_t);
                return 0;
            }
        }
    }
    return orig_sysctlbyname ? orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
}

static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) = NULL;
static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name != NULL && namelen == 2 && name[0] == CTL_HW) {
        NSDictionary *prof = ZTechLoadProfile();
        if (name[1] == HW_MACHINE || name[1] == HW_MODEL) {
            NSString *machine = prof[@"machineId"] ?: @"iPhone15,2";
            const char *cstr = [machine UTF8String];
            size_t len = strlen(cstr) + 1;
            if (oldp != NULL && oldlenp != NULL) {
                size_t copyLen = (*oldlenp < len) ? *oldlenp : len;
                memcpy(oldp, cstr, copyLen);
            }
            if (oldlenp != NULL) {
                *oldlenp = len;
            }
            return 0;
        } else if (name[1] == HW_MEMSIZE || name[1] == HW_PHYSMEM) {
            NSInteger ramGB = [prof[@"ramGB"] integerValue] ?: 6;
            if (oldp != NULL && oldlenp != NULL && *oldlenp >= sizeof(uint64_t)) {
                uint64_t memBytes = (uint64_t)ramGB * 1024ULL * 1024ULL * 1024ULL;
                memcpy(oldp, &memBytes, sizeof(uint64_t));
                *oldlenp = sizeof(uint64_t);
                return 0;
            }
        }
    }
    return orig_sysctl ? orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
}

static CFTypeRef (*orig_MGCopyAnswer)(CFStringRef prop) = NULL;
static CFTypeRef hooked_MGCopyAnswer(CFStringRef prop) {
    if (prop != NULL) {
        NSString *key = (__bridge NSString *)prop;
        NSDictionary *prof = ZTechLoadProfile();
        if ([key isEqualToString:@"ProductType"]) {
            NSString *machine = prof[@"machineId"] ?: @"iPhone15,2";
            return (__bridge_retained CFTypeRef)[machine copy];
        } else if ([key isEqualToString:@"ProductVersion"]) {
            NSString *ver = prof[@"iosVersion"] ?: @"16.6.1";
            return (__bridge_retained CFTypeRef)[ver copy];
        } else if ([key isEqualToString:@"UniqueDeviceID"]) {
            NSString *uuid = prof[@"identifier"] ?: @"7BD46FDA-D93D-45BD-9158-7178669502DD";
            return (__bridge_retained CFTypeRef)[uuid copy];
        }
    }
    return orig_MGCopyAnswer ? orig_MGCopyAnswer(prop) : NULL;
}

#pragma mark - Objective-C Swizzles (UIDevice & NSProcessInfo)

static NSString *(*orig_systemVersion)(id, SEL) = NULL;
static NSString *swizzled_systemVersion(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    return prof[@"iosVersion"] ?: @"16.6.1";
}

static float (*orig_batteryLevel)(id, SEL) = NULL;
static float swizzled_batteryLevel(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSInteger pct = [prof[@"batteryPercent"] integerValue];
    if (pct > 0 && pct <= 100) {
        return (float)pct / 100.0f;
    }
    return 0.68f;
}

static NSUUID *(*orig_identifierForVendor)(id, SEL) = NULL;
static NSUUID *swizzled_identifierForVendor(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *uuidStr = prof[@"identifier"];
    if (uuidStr.length > 0) {
        NSUUID *u = [[NSUUID alloc] initWithUUIDString:uuidStr];
        if (u) return u;
    }
    return orig_identifierForVendor(self, _cmd);
}

static NSOperatingSystemVersion (*orig_osVersion)(id, SEL) = NULL;
static NSOperatingSystemVersion swizzled_osVersion(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *ver = prof[@"iosVersion"] ?: @"16.6.1";
    NSArray<NSString *> *parts = [ver componentsSeparatedByString:@"."];
    NSOperatingSystemVersion v = {16, 6, 1};
    if (parts.count > 0 && [parts[0] integerValue] >= 16) v.majorVersion = [parts[0] integerValue];
    if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
    if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
    return v;
}

static NSString *(*orig_osVersionString)(id, SEL) = NULL;
static NSString *swizzled_osVersionString(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *ver = prof[@"iosVersion"] ?: @"16.6.1";
    return [NSString stringWithFormat:@"Version %@ (Build 21E236)", ver];
}

static unsigned long long (*orig_physicalMemory)(id, SEL) = NULL;
static unsigned long long swizzled_physicalMemory(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSInteger ramGB = [prof[@"ramGB"] integerValue] ?: 6;
    return (unsigned long long)ramGB * 1024ULL * 1024ULL * 1024ULL;
}

#pragma mark - In-Process App Data & Keychain Reset

static void ZTechWipeSubfolder(NSString *folderPath) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:folderPath error:nil];
    for (NSString *item in items) {
        if ([item isEqualToString:@"_zt_last_reset_token.txt"]) continue;
        [fm removeItemAtPath:[folderPath stringByAppendingPathComponent:item] error:nil];
    }
}

static void ZTechCheckAndPerformInAppReset(NSString *bundleId) {
    CFTypeRef cfToken = CFPreferencesCopyAppValue(CFSTR("ZTechResetToken"), kCFPreferencesAnyApplication);
    NSString *globalToken = nil;
    if (cfToken && CFGetTypeID(cfToken) == CFStringGetTypeID()) {
        globalToken = [(__bridge NSString *)cfToken copy];
    }
    if (cfToken) CFRelease(cfToken);

    if (!globalToken || globalToken.length == 0) {
        NSDictionary *prof = ZTechLoadProfile();
        globalToken = prof[@"identifier"];
    }
    if (!globalToken || globalToken.length == 0) return;

    NSString *home = NSHomeDirectory();
    NSString *tokenFile = [home stringByAppendingPathComponent:@"Documents/_zt_last_reset_token.txt"];
    NSString *lastToken = [NSString stringWithContentsOfFile:tokenFile encoding:NSUTF8StringEncoding error:nil];

    if (!lastToken || ![lastToken isEqualToString:globalToken]) {
        // 1. Wipe all Keychain items owned by this app's entitlements (Zalo stores device_id & login token here!)
        NSArray *secClasses = @[
            (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecClassInternetPassword,
            (__bridge id)kSecClassCertificate,
            (__bridge id)kSecClassKey,
            (__bridge id)kSecClassIdentity
        ];
        for (id secClass in secClasses) {
            NSDictionary *query = @{(__bridge id)kSecClass: secClass};
            SecItemDelete((__bridge CFDictionaryRef)query);
        }

        // 2. Wipe NSUserDefaults persistent domain for this app
        if (bundleId.length > 0) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleId];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        // 3. Wipe HTTP Cookies & URLCache
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage.cookies copy]) {
            [cookieStorage deleteCookie:cookie];
        }
        [[NSURLCache sharedURLCache] removeAllCachedResponses];

        // 4. Wipe local sandbox folders (Documents, tmp, Library/Caches, Library/Application Support, Library/Cookies, Library/WebKit)
        NSArray<NSString *> *subDirs = @[
            @"Documents",
            @"tmp",
            @"Library/Caches",
            @"Library/Cookies",
            @"Library/WebKit",
            @"Library/Application Support",
            @"Library/Saved Application State"
        ];
        for (NSString *sub in subDirs) {
            ZTechWipeSubfolder([home stringByAppendingPathComponent:sub]);
        }

        // 5. Wipe Shared AppGroup container from inside the app's own entitlement context
        NSArray<NSString *> *appGroups = @[
            @"group.com.vng.zalo",
            @"group.vn.com.vng.zalo",
            @"group.com.vng.zalo.share",
            [NSString stringWithFormat:@"group.%@", bundleId]
        ];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *groupId in appGroups) {
            NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:groupId];
            if (groupURL && groupURL.path.length > 0) {
                ZTechWipeSubfolder(groupURL.path);
                ZTechWipeSubfolder([groupURL.path stringByAppendingPathComponent:@"Library/Preferences"]);
                ZTechWipeSubfolder([groupURL.path stringByAppendingPathComponent:@"Library/Caches"]);
                ZTechWipeSubfolder([groupURL.path stringByAppendingPathComponent:@"Documents"]);
            }
        }

        // 6. Save current reset token so we don't wipe again until next reset
        [globalToken writeToFile:tokenFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - Constructor

typedef void (*MSHookFunction_t)(void *symbol, void *replace, void **result);

__attribute__((constructor))
static void ZTechHookInit(void) {
    @autoreleasepool {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

        if (!bundleId ||
            [bundleId isEqualToString:@"com.ztech.devicechanger"] ||
            [bundleId hasPrefix:@"com.apple."] ||
            ![bundlePath containsString:@"/Application"]) {
            return;
        }

        Boolean keyExists = false;
        Boolean isLicenseValid = CFPreferencesGetAppBooleanValue(CFSTR("ZTechLicenseValid"), kCFPreferencesAnyApplication, &keyExists);
        if (!keyExists || !isLicenseValid) {
            return;
        }

        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
        ZTechLoadProfile();
        ZTechCheckAndPerformInAppReset(bundleId);

        // 1. Objective-C Swizzles on UIDevice & NSProcessInfo
        Class uiDeviceCls = [UIDevice class];
        Method mSysVer = class_getInstanceMethod(uiDeviceCls, @selector(systemVersion));
        if (mSysVer) {
            orig_systemVersion = (void *)method_getImplementation(mSysVer);
            method_setImplementation(mSysVer, (IMP)swizzled_systemVersion);
        }

        Method mBat = class_getInstanceMethod(uiDeviceCls, @selector(batteryLevel));
        if (mBat) {
            orig_batteryLevel = (void *)method_getImplementation(mBat);
            method_setImplementation(mBat, (IMP)swizzled_batteryLevel);
        }

        Method mIdfv = class_getInstanceMethod(uiDeviceCls, @selector(identifierForVendor));
        if (mIdfv) {
            orig_identifierForVendor = (void *)method_getImplementation(mIdfv);
            method_setImplementation(mIdfv, (IMP)swizzled_identifierForVendor);
        }

        Class procCls = [NSProcessInfo class];
        Method mOsVer = class_getInstanceMethod(procCls, @selector(operatingSystemVersion));
        if (mOsVer) {
            orig_osVersion = (void *)method_getImplementation(mOsVer);
            method_setImplementation(mOsVer, (IMP)swizzled_osVersion);
        }

        Method mOsVerStr = class_getInstanceMethod(procCls, @selector(operatingSystemVersionString));
        if (mOsVerStr) {
            orig_osVersionString = (void *)method_getImplementation(mOsVerStr);
            method_setImplementation(mOsVerStr, (IMP)swizzled_osVersionString);
        }

        Method mPhysMem = class_getInstanceMethod(procCls, @selector(physicalMemory));
        if (mPhysMem) {
            orig_physicalMemory = (void *)method_getImplementation(mPhysMem);
            method_setImplementation(mPhysMem, (IMP)swizzled_physicalMemory);
        }

        // 2. Mach-O Symbol Rebinding (Fishhook) across all loaded images (catches AIDA64 C/C++ calls)
        orig_uname = dlsym(RTLD_DEFAULT, "uname");
        orig_sysctlbyname = dlsym(RTLD_DEFAULT, "sysctlbyname");
        orig_sysctl = dlsym(RTLD_DEFAULT, "sysctl");
        orig_MGCopyAnswer = dlsym(RTLD_DEFAULT, "MGCopyAnswer");

        gRebindings[0] = (struct zt_rebinding){"uname", (void *)hooked_uname, (void **)&orig_uname};
        gRebindings[1] = (struct zt_rebinding){"sysctlbyname", (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname};
        gRebindings[2] = (struct zt_rebinding){"sysctl", (void *)hooked_sysctl, (void **)&orig_sysctl};
        gRebindings[3] = (struct zt_rebinding){"MGCopyAnswer", (void *)hooked_MGCopyAnswer, (void **)&orig_MGCopyAnswer};
        gRebindingsCount = 4;

        _dyld_register_func_for_add_image(rebind_symbols_for_image);

        // 3. Also hook via ElleKit / Substrate if loaded
        const char *hookLibs[] = {
            "/var/jb/usr/lib/libellekit.dylib",
            "/var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
            "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
            "/usr/lib/libsubstitute.dylib",
            "/usr/lib/libsubstrate.dylib"
        };
        MSHookFunction_t pMSHookFunction = NULL;
        for (size_t i = 0; i < sizeof(hookLibs) / sizeof(hookLibs[0]); i++) {
            void *handle = dlopen(hookLibs[i], RTLD_NOW | RTLD_NOLOAD);
            if (!handle) handle = dlopen(hookLibs[i], RTLD_NOW);
            if (handle) {
                pMSHookFunction = (MSHookFunction_t)dlsym(handle, "MSHookFunction");
                if (pMSHookFunction) break;
            }
        }
        if (pMSHookFunction) {
            void *symUname = dlsym(RTLD_DEFAULT, "uname");
            if (symUname) pMSHookFunction(symUname, (void *)hooked_uname, (void **)&orig_uname);
            void *symSysctlName = dlsym(RTLD_DEFAULT, "sysctlbyname");
            if (symSysctlName) pMSHookFunction(symSysctlName, (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname);
            void *symSysctl = dlsym(RTLD_DEFAULT, "sysctl");
            if (symSysctl) pMSHookFunction(symSysctl, (void *)hooked_sysctl, (void **)&orig_sysctl);
        }
    }
}
