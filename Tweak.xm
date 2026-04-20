/**
 * WeChat Tag Group - 弹窗调试版
 * 安装后打开微信会弹窗显示调试信息
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void showAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:ok];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSMutableString *info = [NSMutableString string];
        
        [info appendString:@"【会话管理器】\n"];
        for (NSString *name in @[@"MMSessionMgr", @"WCSessionMgr", @"WCDsessionMgr"]) {
            Class cls = NSClassFromString(name);
            [info appendFormat:@"%@: %@\n", name, cls ? @"存在" : @"不存在"];
        }
        
        [info appendString:@"\n【标签管理器】\n"];
        for (NSString *name in @[@"WCLabelMgr", @"WCContactLabelMgr", @"CLabelMgr"]) {
            Class cls = NSClassFromString(name);
            [info appendFormat:@"%@: %@\n", name, cls ? @"存在" : @"不存在"];
        }
        
        [info appendString:@"\n【主控制器】\n"];
        for (NSString *name in @[@"NewMainFrameViewController", @"WCMainViewController", @"MainViewController"]) {
            Class cls = NSClassFromString(name);
            [info appendFormat:@"%@: %@\n", name, cls ? @"存在" : @"不存在"];
        }
        
        showAlert(@"WeChatTagGroup 调试信息", info);
    });
    
    return result;
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] 弹窗调试版已加载");
}