/**
 * WeChat Tag Group - 弹窗调试版 v8（安全版，不会闪退）
 * 只检测类和方法，不调用带参数的方法
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试v8"
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
                
                // 1. MMServiceCenter.defaultCenter
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                if (serviceCenterClass) {
                    [info appendString:@"【MMServiceCenter】\n"];
                    [info appendFormat:@"defaultCenter: %@\n", 
                     [serviceCenterClass respondsToSelector:@selector(defaultCenter)] ? @"存在" : @"不存在"];
                    
                    unsigned int cm = 0;
                    Method *cms = class_copyMethodList(object_getClass(serviceCenterClass), &cm);
                    if (cms) {
                        [info appendFormat:@"类方法数: %d\n", cm];
                        for (unsigned int i = 0; i < cm; i++) {
                            [info appendFormat:@"  +%@\n", NSStringFromSelector(method_getName(cms[i]))];
                        }
                        free(cms);
                    }
                }
                
                // 2. CContactMgr 常用方法
                Class contactClass = NSClassFromString(@"CContactMgr");
                if (contactClass) {
                    [info appendString:@"\n【CContactMgr 关键方法】\n"];
                    unsigned int mcount = 0;
                    Method *methods = class_copyMethodList(contactClass, &mcount);
                    if (methods) {
                        for (unsigned int i = 0; i < mcount; i++) {
                            NSString *mn = NSStringFromSelector(method_getName(methods[i]));
                            // 只显示包含特定关键词的方法
                            if ([mn.lowercaseString containsString:@"tag"] ||
                                [mn.lowercaseString containsString:@"label"] ||
                                [mn.lowercaseString containsString:@"self"] ||
                                [mn.lowercaseString containsString:@"usr"]) {
                                [info appendFormat:@"  %@\n", mn];
                            }
                        }
                        free(methods);
                    }
                }
                
                // 3. 找获取当前用户的类
                [info appendString:@"\n【可能获取当前用户的类】\n"];
                NSArray *classes = @[@"CContact", @"MMContact", @"Contact", @"PersonalOMM"];
                for (NSString *cn in classes) {
                    Class cls = NSClassFromString(cn);
                    [info appendFormat:@"%@: %@\n", cn, cls ? @"存在" : @"不存在"];
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] 调试版v8(安全)已加载");
}