#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>

#pragma mark - Chained-Fixups + Indirect Symbol GOT Rebinding (App Binary & Frameworks)

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
    void *raw_target;
    void **replaced;
};

static struct zt_rebinding gRebindings[8];
static size_t gRebindingsCount = 0;

static void perform_rebinding_with_section(section_t *section,
                                           intptr_t slide,
                                           nlist_t *symtab,
                                           char *strtab,
                                           uint32_t *indirect_symtab,
                                           uint32_t nindirectsyms) {
    if (section->size < sizeof(void *)) return;
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);

    vm_address_t page_start = (vm_address_t)indirect_symbol_bindings & ~(vm_address_t)(PAGE_SIZE - 1);
    vm_size_t page_len = (((vm_address_t)indirect_symbol_bindings + section->size) - page_start + PAGE_SIZE - 1) & ~(vm_size_t)(PAGE_SIZE - 1);
    kern_return_t kr = vm_protect(mach_task_self(), page_start, page_len, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        return;
    }

    uint32_t *indirect_symbol_indices = (indirect_symtab && section->reserved1 < nindirectsyms)
        ? (indirect_symtab + section->reserved1)
        : NULL;

    uint count = (uint)(section->size / sizeof(void *));
    for (uint i = 0; i < count; i++) {
        void *cur_ptr = indirect_symbol_bindings[i];
        BOOL rebound = NO;

        // 1. Direct pointer match for LC_DYLD_CHAINED_FIXUPS (__got / __const)
        for (size_t j = 0; j < gRebindingsCount; j++) {
            if (gRebindings[j].raw_target != NULL &&
                cur_ptr == gRebindings[j].raw_target &&
                cur_ptr != gRebindings[j].replacement) {
                indirect_symbol_bindings[i] = gRebindings[j].replacement;
                rebound = YES;
                break;
            }
        }
        if (rebound) continue;

        // 2. Classic LC_DYSYMTAB indirect symbol name match
        if (indirect_symbol_indices && symtab && strtab && (section->reserved1 + i) < nindirectsyms) {
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
}

static void rebind_symbols_for_image(const struct mach_header *header, intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0 || !info.dli_fname) return;

    if (strstr(info.dli_fname, "/Application/") == NULL &&
        strstr(info.dli_fname, "Zalo") == NULL) {
        return;
    }

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

    nlist_t *symtab = NULL;
    char *strtab = NULL;
    uint32_t *indirect_symtab = NULL;
    uint32_t nindirectsyms = 0;

    if (symtab_cmd && dysymtab_cmd && linkedit_segment && dysymtab_cmd->nindirectsyms > 0) {
        uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
        symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
        strtab = (char *)(linkedit_base + symtab_cmd->stroff);
        indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);
        nindirectsyms = dysymtab_cmd->nindirectsyms;
    }

    cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0 &&
                strcmp(cur_seg_cmd->segname, SEG_DATA_CONST) != 0 &&
                strcmp(cur_seg_cmd->segname, "__AUTH_CONST") != 0 &&
                strcmp(cur_seg_cmd->segname, "__AUTH") != 0) {
                continue;
            }
            for (uint j = 0; j < cur_seg_cmd->nsects; j++) {
                section_t *sect = (section_t *)(cur + sizeof(segment_command_t)) + j;
                uint32_t flags = sect->flags & SECTION_TYPE;
                BOOL isGotNamed = (strncmp(sect->sectname, "__got", 5) == 0 ||
                                   strncmp(sect->sectname, "__la_symbol_ptr", 15) == 0 ||
                                   strncmp(sect->sectname, "__nl_symbol_ptr", 15) == 0 ||
                                   strncmp(sect->sectname, "__auth_got", 10) == 0);
                if (flags == S_LAZY_SYMBOL_POINTERS || flags == S_NON_LAZY_SYMBOL_POINTERS || isGotNamed) {
                    perform_rebinding_with_section(sect, slide, symtab, strtab, indirect_symtab, nindirectsyms);
                }
            }
        }
    }
}

#pragma mark - Profile Loader (Sandbox-First + Live Auto-Refresh)

static NSDictionary *gCachedProfile = nil;
static CFAbsoluteTime gLastProfileLoadTime = 0;

static NSDictionary *ZTechNormalizeProfile(NSDictionary *raw) {
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:raw ?: @{}];
    NSString *machine = m[@"machineId"];
    if (!machine || machine.length == 0 ||
        [machine hasPrefix:@"iPhone9,"] || [machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone7,"]) {
        m[@"machineId"] = @"iPhone17,2";
        m[@"modelName"] = @"iPhone 16 Pro Max";
    }
    if (!m[@"modelName"] || [m[@"modelName"] length] == 0 ||
        [m[@"modelName"] containsString:@"iPhone 7"] || [m[@"modelName"] containsString:@"iPhone 6"]) {
        m[@"modelName"] = @"iPhone 16 Pro Max";
    }
    NSString *ios = m[@"iosVersion"];
    if (!ios || [ios integerValue] < 16) {
        m[@"iosVersion"] = @"18.2.1";
    }
    if (!m[@"ramGB"] || [m[@"ramGB"] integerValue] < 2) {
        m[@"ramGB"] = @8;
    }
    if (!m[@"batteryPercent"] || [m[@"batteryPercent"] integerValue] <= 0) {
        m[@"batteryPercent"] = @76;
    }
    if (!m[@"identifier"] || [m[@"identifier"] length] == 0) {
        m[@"identifier"] = @"7BD46FDA-D93D-45BD-9158-7178669502DD";
    }
    if (!m[@"activeProxy"]) {
        m[@"activeProxy"] = @"";
    }
    return m;
}

static NSDictionary *ZTechLoadProfile(void) {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (gCachedProfile && (now - gLastProfileLoadTime) < 1.5) {
        return gCachedProfile;
    }
    gLastProfileLoadTime = now;

    // 1. Check inside app's own sandbox container first (written directly by ZTechDeviceDatabase & ZTechVaultManager)
    NSString *home = NSHomeDirectory();
    if (home.length > 0) {
        NSArray<NSString *> *localPaths = @[
            [home stringByAppendingPathComponent:@"Documents/_zt_active_profile.plist"],
            [home stringByAppendingPathComponent:@"Library/Preferences/com.ztech.profile.plist"]
        ];
        for (NSString *lp in localPaths) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:lp];
            if (d && [d isKindOfClass:[NSDictionary class]] && d.count > 0) {
                gCachedProfile = ZTechNormalizeProfile(d);
                return gCachedProfile;
            }
        }
    }

    // 2. Check CFPreferences AnyApplication
    CFPropertyListRef cfVal = CFPreferencesCopyAppValue(CFSTR("ZTechGlobalProfile"), kCFPreferencesAnyApplication);
    if (cfVal) {
        if (CFGetTypeID(cfVal) == CFDictionaryGetTypeID()) {
            NSDictionary *d = (__bridge_transfer NSDictionary *)cfVal;
            gCachedProfile = ZTechNormalizeProfile(d);
            return gCachedProfile;
        }
        CFRelease(cfVal);
    }

    // 3. Check shared global paths
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

    gCachedProfile = ZTechNormalizeProfile(nil);
    return gCachedProfile;
}

#pragma mark - Per-Account Proxy Parser & Injection

static NSDictionary *ZTechBuildProxySettings(NSString *rawProxy, NSString **outBasicAuthHeader) {
    if (!rawProxy) return nil;
    NSString *s = [rawProxy stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;

    BOOL isSocks = NO;
    if ([[s lowercaseString] hasPrefix:@"socks5://"]) {
        isSocks = YES;
        s = [s substringFromIndex:9];
    } else if ([[s lowercaseString] hasPrefix:@"socks://"]) {
        isSocks = YES;
        s = [s substringFromIndex:8];
    } else if ([[s lowercaseString] hasPrefix:@"http://"]) {
        s = [s substringFromIndex:7];
    } else if ([[s lowercaseString] hasPrefix:@"https://"]) {
        s = [s substringFromIndex:8];
    }

    NSString *host = nil;
    NSInteger port = 0;
    NSString *user = nil;
    NSString *pass = nil;

    // Support user:pass@host:port OR host:port:user:pass OR host:port
    if ([s containsString:@"@"]) {
        NSArray<NSString *> *atParts = [s componentsSeparatedByString:@"@"];
        if (atParts.count == 2) {
            NSArray<NSString *> *cred = [atParts[0] componentsSeparatedByString:@":"];
            if (cred.count >= 2) {
                user = cred[0];
                pass = cred[1];
            }
            NSArray<NSString *> *hp = [atParts[1] componentsSeparatedByString:@":"];
            if (hp.count >= 2) {
                host = hp[0];
                port = [hp[1] integerValue];
            }
        }
    } else {
        NSArray<NSString *> *parts = [s componentsSeparatedByString:@":"];
        if (parts.count >= 2) {
            host = parts[0];
            port = [parts[1] integerValue];
            if (parts.count >= 4) {
                user = parts[2];
                pass = parts[3];
            }
        }
    }

    if (!host || host.length == 0 || port <= 0 || port > 65535) {
        return nil;
    }

    NSMutableDictionary *proxyDict = [NSMutableDictionary dictionary];
    if (isSocks) {
        proxyDict[@"SOCKSEnable"] = @1;
        proxyDict[@"SOCKSProxy"] = host;
        proxyDict[@"SOCKSPort"] = @(port);
        proxyDict[(__bridge NSString *)kCFStreamPropertySOCKSProxyHost] = host;
        proxyDict[(__bridge NSString *)kCFStreamPropertySOCKSProxyPort] = @(port);
        proxyDict[(__bridge NSString *)kCFStreamPropertySOCKSVersion] = (__bridge NSString *)kCFStreamSocketSOCKSVersion5;
        if (user.length > 0 && pass.length > 0) {
            proxyDict[(__bridge NSString *)kCFStreamPropertySOCKSUser] = user;
            proxyDict[(__bridge NSString *)kCFStreamPropertySOCKSPassword] = pass;
        }
    } else {
        proxyDict[@"HTTPEnable"] = @1;
        proxyDict[@"HTTPProxy"] = host;
        proxyDict[@"HTTPPort"] = @(port);
        proxyDict[@"HTTPSEnable"] = @1;
        proxyDict[@"HTTPSProxy"] = host;
        proxyDict[@"HTTPSPort"] = @(port);
        proxyDict[(__bridge NSString *)kCFStreamPropertyHTTPProxyHost] = host;
        proxyDict[(__bridge NSString *)kCFStreamPropertyHTTPProxyPort] = @(port);
        proxyDict[(__bridge NSString *)kCFStreamPropertyHTTPSProxyHost] = host;
        proxyDict[(__bridge NSString *)kCFStreamPropertyHTTPSProxyPort] = @(port);
        if (user.length > 0 && pass.length > 0) {
            proxyDict[(__bridge NSString *)kCFProxyUsernameKey] = user;
            proxyDict[(__bridge NSString *)kCFProxyPasswordKey] = pass;
            NSString *rawCred = [NSString stringWithFormat:@"%@:%@", user, pass];
            NSData *credData = [rawCred dataUsingEncoding:NSUTF8StringEncoding];
            if (outBasicAuthHeader && credData) {
                *outBasicAuthHeader = [NSString stringWithFormat:@"Basic %@", [credData base64EncodedStringWithOptions:0]];
            }
        }
    }
    return proxyDict;
}

static NSURLSessionConfiguration *(*orig_defaultSessionConfig)(id, SEL) = NULL;
static NSURLSessionConfiguration *swizzled_defaultSessionConfig(id self, SEL _cmd) {
    NSURLSessionConfiguration *cfg = orig_defaultSessionConfig ? orig_defaultSessionConfig(self, _cmd) : nil;
    if (cfg) {
        NSDictionary *prof = ZTechLoadProfile();
        NSString *rawProxy = prof[@"activeProxy"];
        if (rawProxy && rawProxy.length > 0) {
            NSString *authHeader = nil;
            NSDictionary *proxyDict = ZTechBuildProxySettings(rawProxy, &authHeader);
            if (proxyDict) {
                cfg.connectionProxyDictionary = proxyDict;
                if (authHeader.length > 0) {
                    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:cfg.HTTPAdditionalHeaders ?: @{}];
                    headers[@"Proxy-Authorization"] = authHeader;
                    cfg.HTTPAdditionalHeaders = headers;
                }
            }
        }
    }
    return cfg;
}

static NSURLSessionConfiguration *(*orig_ephemeralSessionConfig)(id, SEL) = NULL;
static NSURLSessionConfiguration *swizzled_ephemeralSessionConfig(id self, SEL _cmd) {
    NSURLSessionConfiguration *cfg = orig_ephemeralSessionConfig ? orig_ephemeralSessionConfig(self, _cmd) : nil;
    if (cfg) {
        NSDictionary *prof = ZTechLoadProfile();
        NSString *rawProxy = prof[@"activeProxy"];
        if (rawProxy && rawProxy.length > 0) {
            NSString *authHeader = nil;
            NSDictionary *proxyDict = ZTechBuildProxySettings(rawProxy, &authHeader);
            if (proxyDict) {
                cfg.connectionProxyDictionary = proxyDict;
                if (authHeader.length > 0) {
                    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:cfg.HTTPAdditionalHeaders ?: @{}];
                    headers[@"Proxy-Authorization"] = authHeader;
                    cfg.HTTPAdditionalHeaders = headers;
                }
            }
        }
    }
    return cfg;
}

static CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void) = NULL;
static CFDictionaryRef hooked_CFNetworkCopySystemProxySettings(void) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *rawProxy = prof[@"activeProxy"];
    if (rawProxy && rawProxy.length > 0) {
        NSDictionary *proxyDict = ZTechBuildProxySettings(rawProxy, NULL);
        if (proxyDict) {
            return (__bridge_retained CFDictionaryRef)[proxyDict copy];
        }
    }
    return orig_CFNetworkCopySystemProxySettings ? orig_CFNetworkCopySystemProxySettings() : NULL;
}

#pragma mark - C Function Hooks (uname, sysctlbyname, sysctl, MGCopyAnswer)

static int (*orig_uname)(struct utsname *buf) = NULL;
static int hooked_uname(struct utsname *buf) {
    int ret = orig_uname ? orig_uname(buf) : 0;
    if (buf != NULL) {
        NSDictionary *prof = ZTechLoadProfile();
        NSString *machine = prof[@"machineId"] ?: @"iPhone17,2";
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
            NSString *machine = prof[@"machineId"] ?: @"iPhone17,2";
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
            NSInteger ramGB = [prof[@"ramGB"] integerValue] ?: 8;
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
            NSString *machine = prof[@"machineId"] ?: @"iPhone17,2";
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
            NSInteger ramGB = [prof[@"ramGB"] integerValue] ?: 8;
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
            NSString *machine = prof[@"machineId"] ?: @"iPhone17,2";
            return (__bridge_retained CFTypeRef)[machine copy];
        } else if ([key isEqualToString:@"MarketingName"] ||
                   [key isEqualToString:@"DeviceName"] ||
                   [key isEqualToString:@"UserAssignedDeviceName"] ||
                   [key isEqualToString:@"LocalizedModel"]) {
            NSString *modelName = prof[@"modelName"] ?: @"iPhone 16 Pro Max";
            return (__bridge_retained CFTypeRef)[modelName copy];
        } else if ([key isEqualToString:@"HWModelStr"] || [key isEqualToString:@"ModelNumber"]) {
            return (__bridge_retained CFTypeRef)[@"D94AP" copy];
        } else if ([key isEqualToString:@"ProductVersion"]) {
            NSString *ver = prof[@"iosVersion"] ?: @"18.2.1";
            return (__bridge_retained CFTypeRef)[ver copy];
        } else if ([key isEqualToString:@"BuildVersion"]) {
            return (__bridge_retained CFTypeRef)[@"22C152" copy];
        } else if ([key isEqualToString:@"UniqueDeviceID"]) {
            NSString *uuid = prof[@"identifier"] ?: @"7BD46FDA-D93D-45BD-9158-7178669502DD";
            return (__bridge_retained CFTypeRef)[uuid copy];
        }
    }
    return orig_MGCopyAnswer ? orig_MGCopyAnswer(prop) : NULL;
}

#pragma mark - Objective-C Swizzles (UIDevice, NSProcessInfo, NSMutableURLRequest, UILabel, WKWebView)

static NSString *(*orig_systemVersion)(id, SEL) = NULL;
static NSString *swizzled_systemVersion(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    return prof[@"iosVersion"] ?: @"18.2.1";
}

static NSString *(*orig_deviceName)(id, SEL) = NULL;
static NSString *swizzled_deviceName(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    return prof[@"modelName"] ?: @"iPhone 16 Pro Max";
}

static float (*orig_batteryLevel)(id, SEL) = NULL;
static float swizzled_batteryLevel(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSInteger pct = [prof[@"batteryPercent"] integerValue];
    if (pct > 0 && pct <= 100) {
        return (float)pct / 100.0f;
    }
    return 0.76f;
}

static NSUUID *(*orig_identifierForVendor)(id, SEL) = NULL;
static NSUUID *swizzled_identifierForVendor(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *uuidStr = prof[@"identifier"];
    if (uuidStr.length > 0) {
        NSUUID *u = [[NSUUID alloc] initWithUUIDString:uuidStr];
        if (u) return u;
    }
    return orig_identifierForVendor ? orig_identifierForVendor(self, _cmd) : [NSUUID UUID];
}

static NSOperatingSystemVersion (*orig_osVersion)(id, SEL) = NULL;
static NSOperatingSystemVersion swizzled_osVersion(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *ver = prof[@"iosVersion"] ?: @"18.2.1";
    NSArray<NSString *> *parts = [ver componentsSeparatedByString:@"."];
    NSOperatingSystemVersion v = {18, 2, 1};
    if (parts.count > 0 && [parts[0] integerValue] >= 16) v.majorVersion = [parts[0] integerValue];
    if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
    if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
    return v;
}

static NSString *(*orig_osVersionString)(id, SEL) = NULL;
static NSString *swizzled_osVersionString(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSString *ver = prof[@"iosVersion"] ?: @"18.2.1";
    return [NSString stringWithFormat:@"Version %@ (Build 22C152)", ver];
}

static unsigned long long (*orig_physicalMemory)(id, SEL) = NULL;
static unsigned long long swizzled_physicalMemory(id self, SEL _cmd) {
    NSDictionary *prof = ZTechLoadProfile();
    NSInteger ramGB = [prof[@"ramGB"] integerValue] ?: 8;
    return (unsigned long long)ramGB * 1024ULL * 1024ULL * 1024ULL;
}

static NSString *ZTechRewriteDeviceTokensInString(NSString *input) {
    if (![input isKindOfClass:[NSString class]] || input.length == 0) return input;
    if (![input containsString:@"iPhone 7"] &&
        ![input containsString:@"iPhone9,"] &&
        ![input containsString:@"iPhone 6"] &&
        ![input containsString:@"iPhone8,"] &&
        ![input containsString:@"15.8"] &&
        ![input containsString:@"15_8"]) {
        return input;
    }
    NSDictionary *prof = ZTechLoadProfile();
    NSString *modelName = prof[@"modelName"] ?: @"iPhone 16 Pro Max";
    NSString *machineId = prof[@"machineId"] ?: @"iPhone17,2";
    NSString *iosVer = prof[@"iosVersion"] ?: @"18.2.1";
    NSString *iosVerUnderscore = [iosVer stringByReplacingOccurrencesOfString:@"." withString:@"_"];

    NSString *out = input;
    out = [out stringByReplacingOccurrencesOfString:@"iPhone 7 Plus" withString:modelName];
    out = [out stringByReplacingOccurrencesOfString:@"iPhone 7" withString:modelName];
    out = [out stringByReplacingOccurrencesOfString:@"iPhone9,1" withString:machineId];
    out = [out stringByReplacingOccurrencesOfString:@"iPhone9,2" withString:machineId];
    out = [out stringByReplacingOccurrencesOfString:@"iPhone9,3" withString:machineId];
    out = [out stringByReplacingOccurrencesOfString:@"iPhone9,4" withString:machineId];
    out = [out stringByReplacingOccurrencesOfString:@"15.8.3" withString:iosVer];
    out = [out stringByReplacingOccurrencesOfString:@"15.8.2" withString:iosVer];
    out = [out stringByReplacingOccurrencesOfString:@"15.8.1" withString:iosVer];
    out = [out stringByReplacingOccurrencesOfString:@"15.8" withString:iosVer];
    out = [out stringByReplacingOccurrencesOfString:@"15_8_3" withString:iosVerUnderscore];
    out = [out stringByReplacingOccurrencesOfString:@"15_8_2" withString:iosVerUnderscore];
    out = [out stringByReplacingOccurrencesOfString:@"15_8" withString:iosVerUnderscore];
    return out;
}

static void (*orig_URLReq_setValue)(id, SEL, NSString *, NSString *) = NULL;
static void swizzled_URLReq_setValue(id self, SEL _cmd, NSString *value, NSString *field) {
    if ([value isKindOfClass:[NSString class]]) {
        value = ZTechRewriteDeviceTokensInString(value);
    }
    if (orig_URLReq_setValue) {
        orig_URLReq_setValue(self, _cmd, value, field);
    }
}

static void (*orig_URLReq_addValue)(id, SEL, NSString *, NSString *) = NULL;
static void swizzled_URLReq_addValue(id self, SEL _cmd, NSString *value, NSString *field) {
    if ([value isKindOfClass:[NSString class]]) {
        value = ZTechRewriteDeviceTokensInString(value);
    }
    if (orig_URLReq_addValue) {
        orig_URLReq_addValue(self, _cmd, value, field);
    }
}

static void (*orig_UILabel_setText)(id, SEL, NSString *) = NULL;
static void swizzled_UILabel_setText(id self, SEL _cmd, NSString *text) {
    if ([text isKindOfClass:[NSString class]] && text.length > 0) {
        text = ZTechRewriteDeviceTokensInString(text);
    }
    if (orig_UILabel_setText) {
        orig_UILabel_setText(self, _cmd, text);
    }
}

static void (*orig_UILabel_setAttributedText)(id, SEL, NSAttributedString *) = NULL;
static void swizzled_UILabel_setAttributedText(id self, SEL _cmd, NSAttributedString *attrText) {
    if ([attrText isKindOfClass:[NSAttributedString class]] && attrText.length > 0) {
        NSString *raw = attrText.string;
        if ([raw containsString:@"iPhone 7"] || [raw containsString:@"iPhone9,"]) {
            NSString *rewritten = ZTechRewriteDeviceTokensInString(raw);
            if (![rewritten isEqualToString:raw]) {
                NSMutableAttributedString *mut = [attrText mutableCopy];
                [mut.mutableString setString:rewritten];
                attrText = mut;
            }
        }
    }
    if (orig_UILabel_setAttributedText) {
        orig_UILabel_setAttributedText(self, _cmd, attrText);
    }
}

static id (*orig_WKWebView_initWithFrameConfig)(id, SEL, CGRect, id) = NULL;
static id swizzled_WKWebView_initWithFrameConfig(id self, SEL _cmd, CGRect frame, id configuration) {
    @try {
        if (configuration) {
            NSDictionary *prof = ZTechLoadProfile();
            NSString *modelName = prof[@"modelName"] ?: @"iPhone 16 Pro Max";
            NSString *safeModel = [modelName stringByReplacingOccurrencesOfString:@"'" withString:@""];
            NSString *js = [NSString stringWithFormat:
                @"(function(){"
                @"var m='%@';"
                @"function r(n){"
                @"if(!n)return;"
                @"if(n.nodeType===3){"
                @"var v=n.nodeValue;"
                @"if(v&&(v.indexOf('iPhone 7')!==-1||v.indexOf('iPhone9,')!==-1)){"
                @"n.nodeValue=v.replace(/iPhone 7 Plus/g,m).replace(/iPhone 7/g,m).replace(/iPhone9,[1234]/g,m);"
                @"}"
                @"}else if(n.childNodes){for(var i=0;i<n.childNodes.length;i++)r(n.childNodes[i]);}"
                @"}"
                @"r(document.body||document.documentElement);"
                @"if(typeof MutationObserver!=='undefined'){"
                @"var obs=new MutationObserver(function(){r(document.body||document.documentElement);});"
                @"obs.observe(document.documentElement,{childList:true,subtree:true,characterData:true});"
                @"}"
                @"setInterval(function(){r(document.body||document.documentElement);},350);"
                @"})();", safeModel];

            Class usrScriptCls = NSClassFromString(@"WKUserScript");
            if (usrScriptCls) {
                SEL allocSel = sel_registerName("alloc");
                SEL initSel = sel_registerName("initWithSource:injectionTime:forMainFrameOnly:");
                id scriptAlloc = ((id (*)(id, SEL))objc_msgSend)(usrScriptCls, allocSel);
                if (scriptAlloc && [scriptAlloc respondsToSelector:initSel]) {
                    id usrScript = ((id (*)(id, SEL, NSString *, NSInteger, BOOL))objc_msgSend)(scriptAlloc, initSel, js, 1, NO);
                    SEL uccSel = sel_registerName("userContentController");
                    if (usrScript && [configuration respondsToSelector:uccSel]) {
                        id ucc = ((id (*)(id, SEL))objc_msgSend)(configuration, uccSel);
                        SEL addSel = sel_registerName("addUserScript:");
                        if (ucc && [ucc respondsToSelector:addSel]) {
                            ((void (*)(id, SEL, id))objc_msgSend)(ucc, addSel, usrScript);
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {}
    return orig_WKWebView_initWithFrameConfig ? orig_WKWebView_initWithFrameConfig(self, _cmd, frame, configuration) : nil;
}

#pragma mark - Safe Container Repair, Vault Snapshot/Restore & In-Process Reset

static void ZTechEnsureContainerDirectoriesExist(NSString *home) {
    if (!home || home.length == 0) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *requiredDirs = @[
        @"Documents",
        @"tmp",
        @"SystemData",
        @"Library",
        @"Library/Caches",
        @"Library/Preferences",
        @"Library/Cookies",
        @"Library/Application Support",
        @"Library/SplashBoard"
    ];
    for (NSString *sub in requiredDirs) {
        NSString *p = [home stringByAppendingPathComponent:sub];
        if (![fm fileExistsAtPath:p]) {
            [fm createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
        }
        chmod([p UTF8String], 0777);
    }
    NSString *globalPrefsLink = [home stringByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
    if (![fm fileExistsAtPath:globalPrefsLink]) {
        symlink("/private/var/mobile/Library/Preferences/.GlobalPreferences.plist", [globalPrefsLink UTF8String]);
    }
}

static void ZTechSnapshotZaloKeychainAndPrefs(NSString *bundleId) {
    @try {
        NSString *home = NSHomeDirectory();
        NSString *docsDir = [home stringByAppendingPathComponent:@"Documents"];

        // Write Zalo marker file so ZTechVaultManager always finds this container immediately
        NSString *markerPath = [docsDir stringByAppendingPathComponent:@"_zt_zalo_marker.txt"];
        if (bundleId.length > 0) {
            [bundleId writeToFile:markerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            chmod([markerPath UTF8String], 0666);
        }

        // 1. Export NSUserDefaults persistent domain to Documents/_zt_prefs_snapshot.plist
        if (bundleId.length > 0) {
            NSDictionary *dom = [[NSUserDefaults standardUserDefaults] persistentDomainForName:bundleId];
            if (dom && dom.count > 0) {
                NSString *prefsSnapPath = [docsDir stringByAppendingPathComponent:@"_zt_prefs_snapshot.plist"];
                [dom writeToFile:prefsSnapPath atomically:YES];
            }
        }

        // 2. Export Keychain items (GenericPassword + InternetPassword) to Documents/_zt_keychain_snapshot.plist
        NSMutableArray *savedItems = [NSMutableArray array];
        NSArray *classes = @[
            (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecClassInternetPassword
        ];
        for (id secClass in classes) {
            NSDictionary *query = @{
                (__bridge id)kSecClass: secClass,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecReturnData: @YES,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
            };
            CFTypeRef result = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
            if (status == errSecSuccess && result) {
                NSArray *items = (__bridge_transfer NSArray *)result;
                for (NSDictionary *item in items) {
                    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                    entry[@"secClass"] = [secClass isEqual:(__bridge id)kSecClassGenericPassword] ? @"genp" : @"inet";
                    if ([item[(__bridge id)kSecAttrAccount] isKindOfClass:[NSString class]] ||
                        [item[(__bridge id)kSecAttrAccount] isKindOfClass:[NSData class]]) {
                        entry[@"acct"] = item[(__bridge id)kSecAttrAccount];
                    }
                    if ([item[(__bridge id)kSecAttrService] isKindOfClass:[NSString class]] ||
                        [item[(__bridge id)kSecAttrService] isKindOfClass:[NSData class]]) {
                        entry[@"svce"] = item[(__bridge id)kSecAttrService];
                    }
                    if ([item[(__bridge id)kSecAttrGeneric] isKindOfClass:[NSData class]] ||
                        [item[(__bridge id)kSecAttrGeneric] isKindOfClass:[NSString class]]) {
                        entry[@"gena"] = item[(__bridge id)kSecAttrGeneric];
                    }
                    if ([item[(__bridge id)kSecValueData] isKindOfClass:[NSData class]]) {
                        entry[@"v_Data"] = item[(__bridge id)kSecValueData];
                    }
                    if (entry[@"v_Data"]) {
                        [savedItems addObject:entry];
                    }
                }
            }
        }
        if (savedItems.count > 0) {
            NSString *kcSnapPath = [docsDir stringByAppendingPathComponent:@"_zt_keychain_snapshot.plist"];
            [savedItems writeToFile:kcSnapPath atomically:YES];
        }
    } @catch (NSException *e) {}
}

static void ZTechCheckAndPerformInAppRestore(NSString *bundleId) {
    @try {
        NSString *home = NSHomeDirectory();
        NSString *docsDir = [home stringByAppendingPathComponent:@"Documents"];
        NSString *triggerFile = [docsDir stringByAppendingPathComponent:@"_zt_restore_trigger.txt"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:triggerFile]) {
            return;
        }

        [fm removeItemAtPath:triggerFile error:nil];

        // Sync reset token so ZTechCheckAndPerformInAppReset does not wipe this restored session
        CFTypeRef cfToken = CFPreferencesCopyAppValue(CFSTR("ZTechResetToken"), kCFPreferencesAnyApplication);
        if (cfToken && CFGetTypeID(cfToken) == CFStringGetTypeID()) {
            NSString *globalToken = [(__bridge NSString *)cfToken copy];
            NSString *tokenFile = [docsDir stringByAppendingPathComponent:@"_zt_last_reset_token.txt"];
            [globalToken writeToFile:tokenFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        if (cfToken) CFRelease(cfToken);

        // 1. Restore NSUserDefaults persistent domain from _zt_prefs_snapshot.plist
        NSString *prefsSnapPath = [docsDir stringByAppendingPathComponent:@"_zt_prefs_snapshot.plist"];
        NSDictionary *savedPrefs = [NSDictionary dictionaryWithContentsOfFile:prefsSnapPath];
        if (savedPrefs && [savedPrefs isKindOfClass:[NSDictionary class]] && bundleId.length > 0) {
            [[NSUserDefaults standardUserDefaults] setPersistentDomain:savedPrefs forName:bundleId];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        // 2. Restore Keychain items from _zt_keychain_snapshot.plist
        NSString *kcSnapPath = [docsDir stringByAppendingPathComponent:@"_zt_keychain_snapshot.plist"];
        NSArray *savedKc = [NSArray arrayWithContentsOfFile:kcSnapPath];
        if (savedKc && [savedKc isKindOfClass:[NSArray class]]) {
            NSArray *secClasses = @[
                (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecClassInternetPassword
            ];
            for (id secClass in secClasses) {
                NSDictionary *delQuery = @{(__bridge id)kSecClass: secClass};
                SecItemDelete((__bridge CFDictionaryRef)delQuery);
            }
            for (NSDictionary *entry in savedKc) {
                if (![entry isKindOfClass:[NSDictionary class]] || !entry[@"v_Data"]) continue;
                NSMutableDictionary *addItem = [NSMutableDictionary dictionary];
                NSString *clsType = entry[@"secClass"];
                addItem[(__bridge id)kSecClass] = [clsType isEqualToString:@"inet"]
                    ? (__bridge id)kSecClassInternetPassword
                    : (__bridge id)kSecClassGenericPassword;
                addItem[(__bridge id)kSecValueData] = entry[@"v_Data"];
                addItem[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
                if (entry[@"acct"]) addItem[(__bridge id)kSecAttrAccount] = entry[@"acct"];
                if (entry[@"svce"]) addItem[(__bridge id)kSecAttrService] = entry[@"svce"];
                if (entry[@"gena"]) addItem[(__bridge id)kSecAttrGeneric] = entry[@"gena"];
                SecItemAdd((__bridge CFDictionaryRef)addItem, NULL);
            }
        }
    } @catch (NSException *e) {}
}

static void ZTechWipeSubfolderContentsOnly(NSString *folderPath) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:folderPath error:nil];
    for (NSString *item in items) {
        if ([item isEqualToString:@"_zt_last_reset_token.txt"] ||
            [item isEqualToString:@"_zt_restore_trigger.txt"] ||
            [item isEqualToString:@"_zt_zalo_marker.txt"] ||
            [item isEqualToString:@"_zt_active_profile.plist"] ||
            [item hasPrefix:@".GlobalPreferences"] ||
            [item hasPrefix:@".com.apple."] ||
            [item isEqualToString:@"SplashBoard"] ||
            [item isEqualToString:@"Caches"] ||
            [item isEqualToString:@"Preferences"]) {
            continue;
        }
        [fm removeItemAtPath:[folderPath stringByAppendingPathComponent:item] error:nil];
    }
}

static void ZTechCheckAndPerformInAppReset(NSString *bundleId) {
    @try {
        NSString *lowerBundle = [bundleId lowercaseString];
        if (![lowerBundle containsString:@"zalo"] &&
            ![lowerBundle containsString:@"vng"] &&
            ![lowerBundle containsString:@"tiktok"] &&
            ![lowerBundle containsString:@"musical"] &&
            ![lowerBundle containsString:@"shopee"]) {
            return;
        }

        NSString *home = NSHomeDirectory();
        ZTechEnsureContainerDirectoriesExist(home);

        if ([lowerBundle containsString:@"zalo"] || [lowerBundle containsString:@"vng"]) {
            NSString *markerPath = [home stringByAppendingPathComponent:@"Documents/_zt_zalo_marker.txt"];
            [bundleId writeToFile:markerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            chmod([markerPath UTF8String], 0666);
        }

        // First check if a Vault Restore was triggered
        ZTechCheckAndPerformInAppRestore(bundleId);

        CFTypeRef cfToken = CFPreferencesCopyAppValue(CFSTR("ZTechResetToken"), kCFPreferencesAnyApplication);
        NSString *globalToken = nil;
        if (cfToken && CFGetTypeID(cfToken) == CFStringGetTypeID()) {
            globalToken = [(__bridge NSString *)cfToken copy];
        }
        if (cfToken) CFRelease(cfToken);

        if (!globalToken || globalToken.length == 0) return;

        NSString *tokenFile = [home stringByAppendingPathComponent:@"Documents/_zt_last_reset_token.txt"];
        NSString *lastToken = [NSString stringWithContentsOfFile:tokenFile encoding:NSUTF8StringEncoding error:nil];

        if (!lastToken || ![lastToken isEqualToString:globalToken]) {
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

            if (bundleId.length > 0) {
                [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleId];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }

            NSArray<NSString *> *subDirs = @[
                @"Documents",
                @"tmp",
                @"Library/Caches",
                @"Library/Cookies",
                @"Library/WebKit",
                @"Library/Application Support"
            ];
            for (NSString *sub in subDirs) {
                ZTechWipeSubfolderContentsOnly([home stringByAppendingPathComponent:sub]);
            }

            ZTechEnsureContainerDirectoriesExist(home);
            [globalToken writeToFile:tokenFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    } @catch (NSException *exception) {
    }
}

#pragma mark - Constructor

typedef void (*MSHookFunction_t)(void *symbol, void *replace, void **result);

static MSHookFunction_t ZTechResolveMSHookFunction(void) {
    void *fn = dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (fn) return (MSHookFunction_t)fn;

    const char *hookLibs[] = {
        "/var/jb/usr/lib/libellekit.dylib",
        "/var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
        "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
        "/usr/lib/libsubstrate.dylib",
        "/usr/lib/libsubstitute.dylib"
    };
    for (size_t i = 0; i < sizeof(hookLibs) / sizeof(hookLibs[0]); i++) {
        void *handle = dlopen(hookLibs[i], RTLD_LAZY | RTLD_NOLOAD);
        if (!handle) {
            handle = dlopen(hookLibs[i], RTLD_LAZY);
        }
        if (handle) {
            fn = dlsym(handle, "MSHookFunction");
            if (fn) return (MSHookFunction_t)fn;
        }
    }
    return NULL;
}

__attribute__((constructor))
static void ZTechHookInit(void) {
    @autoreleasepool {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

        if (!bundleId || !bundlePath ||
            [bundleId isEqualToString:@"com.ztech.devicechanger"] ||
            [bundleId hasPrefix:@"com.apple."] ||
            ![bundlePath containsString:@"/Application"] ||
            ![bundlePath hasSuffix:@".app"]) {
            return;
        }

        ZTechEnsureContainerDirectoriesExist(NSHomeDirectory());

        Boolean keyExists = false;
        Boolean isLicenseValid = CFPreferencesGetAppBooleanValue(CFSTR("ZTechLicenseValid"), kCFPreferencesAnyApplication, &keyExists);
        if (keyExists && !isLicenseValid) {
            return;
        }

        ZTechLoadProfile();
        ZTechCheckAndPerformInAppReset(bundleId);

        // Automatically snapshot Zalo Keychain & Prefs when Zalo becomes active or enters background so Account Vault always has complete auth tokens
        NSString *lowerBundle = [bundleId lowercaseString];
        if ([lowerBundle containsString:@"zalo"] || [lowerBundle containsString:@"vng"]) {
            NSString *markerPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/_zt_zalo_marker.txt"];
            [bundleId writeToFile:markerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            chmod([markerPath UTF8String], 0666);

            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                gLastProfileLoadTime = 0;
                ZTechLoadProfile();
                ZTechSnapshotZaloKeychainAndPrefs(bundleId);
            }];
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                ZTechSnapshotZaloKeychainAndPrefs(bundleId);
            }];
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                ZTechSnapshotZaloKeychainAndPrefs(bundleId);
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                ZTechSnapshotZaloKeychainAndPrefs(bundleId);
            });
        }

        // 1. Objective-C Swizzles on UIDevice, NSProcessInfo, NSURLSessionConfiguration, NSMutableURLRequest, UILabel & WKWebView
        Class uiDeviceCls = [UIDevice class];
        Method mSysVer = class_getInstanceMethod(uiDeviceCls, @selector(systemVersion));
        if (mSysVer) {
            orig_systemVersion = (void *)method_getImplementation(mSysVer);
            method_setImplementation(mSysVer, (IMP)swizzled_systemVersion);
        }

        Method mDevName = class_getInstanceMethod(uiDeviceCls, @selector(name));
        if (mDevName) {
            orig_deviceName = (void *)method_getImplementation(mDevName);
            method_setImplementation(mDevName, (IMP)swizzled_deviceName);
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

        Class urlCfgCls = [NSURLSessionConfiguration class];
        Method mDefCfg = class_getClassMethod(urlCfgCls, @selector(defaultSessionConfiguration));
        if (mDefCfg) {
            orig_defaultSessionConfig = (void *)method_getImplementation(mDefCfg);
            method_setImplementation(mDefCfg, (IMP)swizzled_defaultSessionConfig);
        }
        Method mEphCfg = class_getClassMethod(urlCfgCls, @selector(ephemeralSessionConfiguration));
        if (mEphCfg) {
            orig_ephemeralSessionConfig = (void *)method_getImplementation(mEphCfg);
            method_setImplementation(mEphCfg, (IMP)swizzled_ephemeralSessionConfig);
        }

        Class mutReqCls = [NSMutableURLRequest class];
        Method mReqSet = class_getInstanceMethod(mutReqCls, @selector(setValue:forHTTPHeaderField:));
        if (mReqSet) {
            orig_URLReq_setValue = (void *)method_getImplementation(mReqSet);
            method_setImplementation(mReqSet, (IMP)swizzled_URLReq_setValue);
        }
        Method mReqAdd = class_getInstanceMethod(mutReqCls, @selector(addValue:forHTTPHeaderField:));
        if (mReqAdd) {
            orig_URLReq_addValue = (void *)method_getImplementation(mReqAdd);
            method_setImplementation(mReqAdd, (IMP)swizzled_URLReq_addValue);
        }

        if ([lowerBundle containsString:@"zalo"] || [lowerBundle containsString:@"vng"]) {
            Class lblCls = [UILabel class];
            Method mSetTxt = class_getInstanceMethod(lblCls, @selector(setText:));
            if (mSetTxt) {
                orig_UILabel_setText = (void *)method_getImplementation(mSetTxt);
                method_setImplementation(mSetTxt, (IMP)swizzled_UILabel_setText);
            }
            Method mSetAttrTxt = class_getInstanceMethod(lblCls, @selector(setAttributedText:));
            if (mSetAttrTxt) {
                orig_UILabel_setAttributedText = (void *)method_getImplementation(mSetAttrTxt);
                method_setImplementation(mSetAttrTxt, (IMP)swizzled_UILabel_setAttributedText);
            }

            Class wkCls = NSClassFromString(@"WKWebView");
            if (wkCls) {
                Method mWkInit = class_getInstanceMethod(wkCls, sel_registerName("initWithFrame:configuration:"));
                if (mWkInit) {
                    orig_WKWebView_initWithFrameConfig = (void *)method_getImplementation(mWkInit);
                    method_setImplementation(mWkInit, (IMP)swizzled_WKWebView_initWithFrameConfig);
                }
            }
        }

        // 2. C-Function Hooks: MSHookFunction (ElleKit/Substrate/Substitute) + Chained-Fixups GOT Rebinding
        void *raw_uname = dlsym(RTLD_DEFAULT, "uname");
        void *raw_sysctlbyname = dlsym(RTLD_DEFAULT, "sysctlbyname");
        void *raw_sysctl = dlsym(RTLD_DEFAULT, "sysctl");
        void *raw_MGCopyAnswer = dlsym(RTLD_DEFAULT, "MGCopyAnswer");
        void *raw_CFProxy = dlsym(RTLD_DEFAULT, "CFNetworkCopySystemProxySettings");

        orig_uname = raw_uname;
        orig_sysctlbyname = raw_sysctlbyname;
        orig_sysctl = raw_sysctl;
        orig_MGCopyAnswer = raw_MGCopyAnswer;
        orig_CFNetworkCopySystemProxySettings = raw_CFProxy;

        MSHookFunction_t msHook = ZTechResolveMSHookFunction();
        if (msHook != NULL) {
            if (raw_uname) msHook(raw_uname, (void *)hooked_uname, (void **)&orig_uname);
            if (raw_sysctlbyname) msHook(raw_sysctlbyname, (void *)hooked_sysctlbyname, (void **)&orig_sysctlbyname);
            if (raw_sysctl) msHook(raw_sysctl, (void *)hooked_sysctl, (void **)&orig_sysctl);
            if (raw_MGCopyAnswer) msHook(raw_MGCopyAnswer, (void *)hooked_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
            if (raw_CFProxy) msHook(raw_CFProxy, (void *)hooked_CFNetworkCopySystemProxySettings, (void **)&orig_CFNetworkCopySystemProxySettings);
        }

        gRebindings[0] = (struct zt_rebinding){"uname", (void *)hooked_uname, raw_uname, (void **)&orig_uname};
        gRebindings[1] = (struct zt_rebinding){"sysctlbyname", (void *)hooked_sysctlbyname, raw_sysctlbyname, (void **)&orig_sysctlbyname};
        gRebindings[2] = (struct zt_rebinding){"sysctl", (void *)hooked_sysctl, raw_sysctl, (void **)&orig_sysctl};
        gRebindings[3] = (struct zt_rebinding){"MGCopyAnswer", (void *)hooked_MGCopyAnswer, raw_MGCopyAnswer, (void **)&orig_MGCopyAnswer};
        gRebindings[4] = (struct zt_rebinding){"CFNetworkCopySystemProxySettings", (void *)hooked_CFNetworkCopySystemProxySettings, raw_CFProxy, (void **)&orig_CFNetworkCopySystemProxySettings};
        gRebindingsCount = 5;

        _dyld_register_func_for_add_image(rebind_symbols_for_image);
    }
}
