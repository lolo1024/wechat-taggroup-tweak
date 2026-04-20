/**
 * WeChat Tag Group - 弹窗调试版 v2
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL _alertShown = NO;

static void showDebugAlert() {
    if (_alertShown) return;
    _alertShown = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
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
        
        [info appendString:@"\n【主页面】\n"];
        for (NSString *name in @[@"NewMainFrameViewController", @"WCMainViewController", @"MainViewController"]) {
            Class cls = NSClassFromString(name);
            [info appendFormat:@"%@: %@\n", name, cls ? @"存在" : @"不存在"];
        }
        
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试"
                                                                       message:info
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (!_alertShown) {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"Main"] || [className containsString:@"Chat"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                showDebugAlert();
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] 调试版v2已加载");
}