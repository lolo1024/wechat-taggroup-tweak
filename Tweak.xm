/**
 * WeChat Tag Group - 弹窗调试版 v3
 * 尝试更多可能的类名
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL _alertShown = NO;

static void showDebugAlert(NSString *info) {
    if (_alertShown) return;
    _alertShown = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试v3"
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
        if ([className isEqualToString:@"NewMainFrameViewController"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSMutableString *info = [NSMutableString string];
                
                [info appendString:@"【会话相关】\n"];
                for (NSString *name in @[
                    @"MMConversationMgr", @"ConversationMgr",
                    @"MMConversationService", @"ConversationService",
                    @"MMMsgMgr", @"MessageManager",
                    @"CMessageMgr", @"MessageMgr",
                    @"SessionService", @"MMServiceCenter"
                ]) {
                    Class cls = NSClassFromString(name);
                    [info appendFormat:@"%@: %@\n", name, cls ? @"存在" : @"不存在"];
                }
                
                [info appendString:@"\n【联系人/标签相关】\n"];
                for (NSString *name in @[
                    @"ContactStorage", @"ContactMgr",
                    @"MMContactMgr", @"CContactMgr",
                    @"AddressBookMgr", @"MMAddressBookMgr",
                    @"TagMgr", @"ContactTagMgr", @"LabelMgr"
                ]) {
                    Class cls = NSClassFromString(name);
                    [info appendFormat:@"%@: %@\n", name, cls ? @"存在" : @"不存在"];
                }
                
                [info appendString:@"\n【共享实例方法】\n"];
                for (NSString *sel in @[
                    @"sharedInstance", @"defaultManager", @"defaultMgr",
                    @"sharedManager", @"Instance", @"sharedConversationMgr"
                ]) {
                    [info appendFormat:@"尝试: %@\n", sel];
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] 调试版v3已加载");
}