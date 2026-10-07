#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <string.h>

static NSDictionary *gFakeProfile = nil;

static NSDictionary *ZTechLoadProfile(void) {
    NSArray<NSString *> *paths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/tmp/com.ztech.profile.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (dict && [dict isKindOfClass:[NSDictionary class]] && [dict[@"machineId"] length] > 0) {
            return dict;
        }
    }
    return nil;
}

#pragma mark - C Function Hooks (uname & sysctlbyname)

static int (*orig_uname)(struct utsname *buf) = NULL;
static int hooked_uname(struct utsname *buf) {
    int ret = orig_uname ? orig_uname(buf) : uname(buf);
    if (ret == 0 && buf != NULL) {
        NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
        NSString *machine = prof[@"machineId"];
        if (machine.length > 0) {
            strncpy(buf->machine, [machine UTF8String], sizeof(buf->machine) - 1);
            buf->machine[sizeof(buf->machine) - 1] = '\0';
        }
    }
    return ret;
}

static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) = NULL;
static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name != NULL) {
        NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.product") == 0 || strcmp(name, "hw.model") == 0) {
            NSString *machine = prof[@"machineId"];
            if (machine.length > 0) {
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
            }
        } else if (strcmp(name, "hw.memsize") == 0 || strcmp(name, "hw.physmem") == 0) {
            NSInteger ramGB = [prof[@"ramGB"] integerValue];
            if (ramGB > 0 && oldp != NULL && oldlenp != NULL && *oldlenp >= sizeof(uint64_t)) {
                uint64_t memBytes = (uint64_t)ramGB * 1024ULL * 1024ULL * 1024ULL;
                memcpy(oldp, &memBytes, sizeof(uint64_t));
                *oldlenp = sizeof(uint64_t);
                return 0;
            }
        }
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

#pragma mark - Objective-C Swizzles (UIDevice & NSProcessInfo)

static NSString *(*orig_systemVersion)(id, SEL) = NULL;
static NSString *swizzled_systemVersion(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
    NSString *ver = prof[@"iosVersion"];
    if (ver.length > 0) return ver;
    return orig_systemVersion(self, _cmd);
}

static float (*orig_batteryLevel)(id, SEL) = NULL;
static float swizzled_batteryLevel(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
    NSInteger pct = [prof[@"batteryPercent"] integerValue];
    if (pct > 0 && pct <= 100) {
        return (float)pct / 100.0f;
    }
    return orig_batteryLevel(self, _cmd);
}

static NSUUID *(*orig_identifierForVendor)(id, SEL) = NULL;
static NSUUID *swizzled_identifierForVendor(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
    NSString *uuidStr = prof[@"identifier"];
    if (uuidStr.length > 0) {
        NSUUID *u = [[NSUUID alloc] initWithUUIDString:uuidStr];
        if (u) return u;
    }
    return orig_identifierForVendor(self, _cmd);
}

static NSOperatingSystemVersion (*orig_osVersion)(id, SEL) = NULL;
static NSOperatingSystemVersion swizzled_osVersion(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
    NSString *ver = prof[@"iosVersion"];
    if (ver.length > 0) {
        NSArray<NSString *> *parts = [ver componentsSeparatedByString:@"."];
        NSOperatingSystemVersion v = {0, 0, 0};
        if (parts.count > 0) v.majorVersion = [parts[0] integerValue];
        if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
        if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
        if (v.majorVersion > 0) return v;
    }
    return orig_osVersion(self, _cmd);
}

static unsigned long long (*orig_physicalMemory)(id, SEL) = NULL;
static unsigned long long swizzled_physicalMemory(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile() ?: gFakeProfile;
    NSInteger ramGB = [prof[@"ramGB"] integerValue];
    if (ramGB > 0) {
        return (unsigned long long)ramGB * 1024ULL * 1024ULL * 1024ULL;
    }
    return orig_physicalMemory(self, _cmd);
}

#pragma mark - Constructor

typedef void (*MSHookFunction_t)(void *symbol, void *replace, void **result);

__attribute__((constructor))
static void ZTechHookInit(void) {
    @autoreleasepool {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

        // Do not hook SpringBoard, system daemons, or the gaulmt -Tech control app itself
        if (!bundleId ||
            [bundleId isEqualToString:@"com.ztech.devicechanger"] ||
            [bundleId hasPrefix:@"com.apple."] ||
            ![bundlePath containsString:@"/Application"]) {
            return;
        }

        gFakeProfile = ZTechLoadProfile();

        // 1. Hook Objective-C methods on UIDevice and NSProcessInfo
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

        Method mPhysMem = class_getInstanceMethod(procCls, @selector(physicalMemory));
        if (mPhysMem) {
            orig_physicalMemory = (void *)method_getImplementation(mPhysMem);
            method_setImplementation(mPhysMem, (IMP)swizzled_physicalMemory);
        }

        // 2. Dynamically resolve MSHookFunction from ElleKit (Rootless) or Substrate/Substitute (Rootful)
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
            if (symUname) {
                pMSHookFunction(symUname, (void *)hooked_uname, (void **)&orig_uname);
            }
            void *symSysctl = dlsym(RTLD_DEFAULT, "sysctlbyname");
            if (symSysctl) {
                pMSHookFunction(symSysctl, (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname);
            }
        }
    }
}
