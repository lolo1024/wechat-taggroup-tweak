/**
 * WeChat Tag Group - 弹窗调试版 v4
 * 测试找到的类是否能正常使用
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试v4"
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
                
                // 测试 ContactTagMgr
                Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                if (tagMgrClass) {
                    [info appendString:@"【ContactTagMgr】\n"];
                    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
                    if ([tagMgrClass respondsToSelector:sharedSel]) {
                        [info appendString:@"sharedInstance: 可用\n"];
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id tagMgr = [tagMgrClass performSelector:sharedSel];
                        #pragma clang diagnostic pop
                        if (tagMgr) {
                            [info appendFormat:@"实例: %@\n", tagMgr];
                            
                            // 尝试获取标签列表
                            SEL getTagsSel = NSSelectorFromString(@"getContactLabels");
                            if ([tagMgr respondsToSelector:getTagsSel]) {
                                [info appendString:@"getContactLabels: 存在\n"];
                            }
                            
                            SEL labelListSel = NSSelectorFromString(@"getLabelList");
                            if ([tagMgr respondsToSelector:labelListSel]) {
                                [info appendString:@"getLabelList: 存在\n"];
                            }
                            
                            SEL allLabelsSel = NSSelectorFromString(@"getAllLabels");
                            if ([tagMgr respondsToSelector:allLabelsSel]) {
                                [info appendString:@"getAllLabels: 存在\n"];
                            }
                        }
                    } else {
                        [info appendString:@"sharedInstance: 不可用\n"];
                    }
                    
                    unsigned int methodCount = 0;
                    Method *methods = class_copyMethodList(tagMgrClass, &methodCount);
                    if (methods) {
                        [info appendFormat:@"共 %d 个方法:\n", methodCount];
                        for (unsigned int i = 0; i < methodCount && i < 20; i++) {
                            NSString *methodName = NSStringFromSelector(method_getName(methods[i]));
                            if ([methodName.lowercaseString containsString:@"label"] ||
                                [methodName.lowercaseString containsString:@"tag"]) {
                                [info appendFormat:@"  - %@\n", methodName];
                            }
                        }
                        free(methods);
                    }
                }
                
                // 测试 MMServiceCenter
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                if (serviceCenterClass) {
                    [info appendString:@"\n【MMServiceCenter】\n"];
                    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
                    if ([serviceCenterClass respondsToSelector:sharedSel]) {
                        [info appendString:@"sharedInstance: 可用\n"];
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id serviceCenter = [serviceCenterClass performSelector:sharedSel];
                        #pragma clang diagnostic pop
                        if (serviceCenter) {
                            [info appendFormat:@"实例: %@\n", serviceCenter];
                            
                            // 尝试获取ContactTagMgr
                            if ([serviceCenter respondsToSelector:@selector(getService:)]) {
                                [info appendString:@"getService: 存在\n"];
                                #pragma clang diagnostic push
                                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                id tagService = [serviceCenter performSelector:@selector(getService:) withObject:tagMgrClass];
                                #pragma clang diagnostic pop
                                if (tagService) {
                                    [info appendFormat:@"ContactTagMgr via ServiceCenter: %@\n", tagService];
                                }
                            }
                        }
                    }
                }
                
                // 测试 CContactMgr
                Class contactClass = NSClassFromString(@"CContactMgr");
                if (contactClass) {
                    [info appendString:@"\n【CContactMgr】\n"];
                    unsigned int methodCount = 0;
                    Method *methods = class_copyMethodList(contactClass, &methodCount);
                    if (methods) {
                        [info appendFormat:@"共 %d 个方法:\n", methodCount];
                        for (unsigned int i = 0; i < methodCount && i < 20; i++) {
                            NSString *methodName = NSStringFromSelector(method_getName(methods[i]));
                            if ([methodName.lowercaseString containsString:@"label"] ||
                                [methodName.lowercaseString containsString:@"tag"]) {
                                [info appendFormat:@"  - %@\n", methodName];
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
    NSLog(@"[WeChatTagGroup] 调试版v4已加载");
}