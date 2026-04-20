/**
 * WeChat Tag Group - 弹窗调试版 v7
 * 使用 +defaultCenter 获取 MMServiceCenter，然后获取当前用户
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试v7"
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
                
                // 1. 通过 defaultCenter 获取 MMServiceCenter
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                if (serviceCenterClass) {
                    SEL defaultCenterSel = NSSelectorFromString(@"defaultCenter");
                    if ([serviceCenterClass respondsToSelector:defaultCenterSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id serviceCenter = [serviceCenterClass performSelector:defaultCenterSel];
                        #pragma clang diagnostic pop
                        
                        if (serviceCenter) {
                            [info appendFormat:@"MMServiceCenter.defaultCenter: 成功\n"];
                            [info appendFormat:@"实例: %@\n", serviceCenter];
                            
                            // 2. 通过 serviceCenter 获取 CContactMgr
                            Class contactMgrClass = NSClassFromString(@"CContactMgr");
                            if ([serviceCenter respondsToSelector:@selector(getService:)]) {
                                #pragma clang diagnostic push
                                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                id contactMgr = [serviceCenter performSelector:@selector(getService:) withObject:contactMgrClass];
                                #pragma clang diagnostic pop
                                
                                if (contactMgr) {
                                    [info appendFormat:@"CContactMgr via ServiceCenter: 成功\n"];
                                    [info appendFormat:@"实例: %@\n", contactMgr];
                                    
                                    // 3. 尝试获取当前用户
                                    NSArray *userMethods = @[@"getMyUserName", @"GetMyUserName", @"m_nsUsrName", @"getSelfContact"];
                                    for (NSString *methodName in userMethods) {
                                        SEL sel = NSSelectorFromString(methodName);
                                        if ([contactMgr respondsToSelector:sel]) {
                                            #pragma clang diagnostic push
                                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                            NSString *myUserName = [contactMgr performSelector:sel];
                                            #pragma clang diagnostic pop
                                            [info appendFormat:@"%@: %@\n", methodName, myUserName];
                                            
                                            if (myUserName) {
                                                // 4. 尝试获取该用户的标签
                                                SEL getTagsSel = NSSelectorFromString(@"getArrContactTagIDWithUserName:");
                                                if ([contactMgr respondsToSelector:getTagsSel]) {
                                                    #pragma clang diagnostic push
                                                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                                    NSArray *tags = [contactMgr performSelector:getTagsSel withObject:myUserName];
                                                    #pragma clang diagnostic pop
                                                    [info appendFormat:@"该用户标签: %@\n", tags];
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                [info appendString:@"ServiceCenter.getService: 不可用\n"];
                            }
                        }
                    } else {
                        [info appendString:@"MMServiceCenter.defaultCenter: 不可用\n"];
                    }
                }
                
                // 5. 列出更多 CContactMgr 的方法
                Class contactMgrClass = NSClassFromString(@"CContactMgr");
                if (contactMgrClass) {
                    [info appendString:@"\n【更多 CContactMgr 方法】\n"];
                    unsigned int methodCount = 0;
                    Method *methods = class_copyMethodList(contactMgrClass, &methodCount);
                    if (methods) {
                        for (unsigned int i = 0; i < methodCount; i++) {
                            NSString *methodName = NSStringFromSelector(method_getName(methods[i]));
                            if ([methodName.lowercaseString containsString:@"user"] ||
                                [methodName.lowercaseString containsString:@"self"] ||
                                [methodName.lowercaseString containsString:@"name"]) {
                                if ([methodName.lowercaseString containsString:@"tag"]) {
                                    [info appendFormat:@"  %@\n", methodName];
                                }
                            }
                        }
                        free(methods);
                    }
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] 调试版v7已加载");
}