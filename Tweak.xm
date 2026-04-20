/**
 * WeChat Tag Group - 弹窗调试版 v6
 * 扫描 MMServiceCenter 的所有方法，找正确的获取方式
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试v6"
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
                
                // 1. 列出 MMServiceCenter 的所有类方法
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                if (serviceCenterClass) {
                    [info appendString:@"【MMServiceCenter 类方法】\n"];
                    unsigned int classMethodCount = 0;
                    Method *classMethods = class_copyMethodList(object_getClass(serviceCenterClass), &classMethodCount);
                    if (classMethods) {
                        for (unsigned int i = 0; i < classMethodCount; i++) {
                            NSString *methodName = NSStringFromSelector(method_getName(classMethods[i]));
                            [info appendFormat:@"  +%@\n", methodName];
                        }
                        free(classMethods);
                    } else {
                        [info appendString:@"  无类方法\n"];
                    }
                }
                
                // 2. 列出 CContactMgr 的所有类方法
                Class contactMgrClass = NSClassFromString(@"CContactMgr");
                if (contactMgrClass) {
                    [info appendString:@"\n【CContactMgr 类方法】\n"];
                    unsigned int classMethodCount = 0;
                    Method *classMethods = class_copyMethodList(object_getClass(contactMgrClass), &classMethodCount);
                    if (classMethods) {
                        for (unsigned int i = 0; i < classMethodCount; i++) {
                            NSString *methodName = NSStringFromSelector(method_getName(classMethods[i]));
                            [info appendFormat:@"  +%@\n", methodName];
                        }
                        free(classMethods);
                    } else {
                        [info appendString:@"  无类方法\n"];
                    }
                }
                
                // 3. 尝试常见方法名获取单例
                [info appendString:@"\n【尝试获取单例】\n"];
                NSArray *singletonNames = @[@"sharedInstance", @"defaultManager", @"shareInstance", 
                                            @"sharedMgr", @"shared", @"defaultInstance"];
                
                for (NSString *name in singletonNames) {
                    if (serviceCenterClass) {
                        SEL sel = NSSelectorFromString(name);
                        if ([serviceCenterClass respondsToSelector:sel]) {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            id instance = [serviceCenterClass performSelector:sel];
                            #pragma clang diagnostic pop
                            [info appendFormat:@"MMServiceCenter.%@: %@\n", name, instance ? @"成功" : @"返回nil"];
                        }
                    }
                    
                    if (contactMgrClass) {
                        SEL sel = NSSelectorFromString(name);
                        if ([contactMgrClass respondsToSelector:sel]) {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            id instance = [contactMgrClass performSelector:sel];
                            #pragma clang diagnostic pop
                            [info appendFormat:@"CContactMgr.%@: %@\n", name, instance ? @"成功" : @"返回nil"];
                        }
                    }
                }
                
                // 4. 尝试 alloc init
                [info appendString:@"\n【尝试 alloc init】\n"];
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id contactMgrAlloc = [[contactMgrClass alloc] init];
                #pragma clang diagnostic pop
                if (contactMgrAlloc) {
                    [info appendFormat:@"CContactMgr alloc init: 成功 %@\n", contactMgrAlloc];
                    
                    // 尝试调用 getArrContactTagIDWithUserName:
                    SEL getTagsSel = NSSelectorFromString(@"getArrContactTagIDWithUserName:");
                    if ([contactMgrAlloc respondsToSelector:getTagsSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        NSArray *tags = [contactMgrAlloc performSelector:getTagsSel withObject:@"weixin"];
                        #pragma clang diagnostic pop
                        [info appendFormat:@"getArrContactTagIDWithUserName:weixin = %@\n", tags];
                    }
                } else {
                    [info appendString:@"CContactMgr alloc init: 失败\n"];
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] 调试版v6已加载");
}