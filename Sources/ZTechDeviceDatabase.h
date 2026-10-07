#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ZTechDeviceProfile : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *modelName;
@property (nonatomic, copy) NSString *machineId;
@property (nonatomic, copy) NSString *iosVersion;
@property (nonatomic, assign) NSInteger batteryPercent;
@property (nonatomic, copy) NSString *carrier;
@property (nonatomic, copy) NSString *wifiSsid;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, assign) NSInteger contactsCount;
@property (nonatomic, copy) NSString *chipName;
@property (nonatomic, assign) NSInteger ramGB;
@property (nonatomic, copy) NSString *screenKey;
@property (nonatomic, assign) NSInteger writtenFilesCount;
@property (nonatomic, assign) NSInteger successItemsCount;

- (NSString *)summaryLine1;
- (NSString *)summaryLine2;
- (NSString *)fullReportTextWithFlags:(BOOL)lockModel
                         respringAfter:(BOOL)respring
                            sameScreen:(BOOL)sameScreen
                             matchChip:(BOOL)matchChip;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

@interface ZTechDeviceDatabase : NSObject

+ (ZTechDeviceProfile *)loadOrCreateDefaultProfile;
+ (ZTechDeviceProfile *)generateProfileWithLockRealModel:(BOOL)lockModel
                                              sameScreen:(BOOL)sameScreen
                                               matchChip:(BOOL)matchChip
                                             currentCity:(NSString *)currentCity;
+ (BOOL)writeProfileFiles:(ZTechDeviceProfile *)profile error:(NSError **)error;
+ (void)syncLocationByIPWithCompletion:(void (^)(NSString *city, NSString *isp, NSError *error))completion;
+ (void)performRespringIfPossible;

@end
