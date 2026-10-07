#import "ZTechAppDelegate.h"
#import "ZTechRootViewController.h"

@implementation ZTechAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.04 alpha:1.0];
    ZTechRootViewController *rootVC = [[ZTechRootViewController alloc] init];
    self.window.rootViewController = rootVC;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
