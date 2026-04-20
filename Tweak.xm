/**
 * WeChat Tag Group - 弹窗调试版 v5
 * 测试调用 CContactMgr 的标签方法
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup 调试v5"
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
                
                // 1. 通过 MMServiceCenter 获取 CContactMgr
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                Class contactMgrClass = NSClassFromString(@"CContactMgr");
                
                if (serviceCenterClass && contactMgrClass) {
                    [info appendString:@"【MMServiceCenter 获取 CContactMgr】\n"];
                    
                    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
                    if ([serviceCenterClass respondsToSelector:sharedSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id serviceCenter = [serviceCenterClass performSelector:sharedSel];
                        #pragma clang diagnostic pop
                        
                        if (serviceCenter) {
                            [info appendFormat:@"MMServiceCenter 实例: %@\n", serviceCenter];
                            
                            // 尝试 getService:
                            if ([serviceCenter respondsToSelector:@selector(getService:)]) {
                                [info appendString:@"getService: 可调用\n"];
                                
                                #pragma clang diagnostic push
                                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                id contactMgr = [serviceCenter performSelector:@selector(getService:) withObject:contactMgrClass];
                                #pragma clang diagnostic pop
                                
                                if (contactMgr) {
                                    [info appendFormat:@"CContactMgr 实例: %@\n", contactMgr];
                                    
                                    // 尝试调用 getArrContactTagIDWithUserName:
                                    SEL getTagsSel = NSSelectorFromString(@"getArrContactTagIDWithUserName:");
                                    if ([contactMgr respondsToSelector:getTagsSel]) {
                                        [info appendString:@"getArrContactTagIDWithUserName: 可调用\n"];
                                        
                                        // 尝试获取自己的标签
                                        #pragma clang diagnostic push
                                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                        NSArray *myTags = [contactMgr performSelector:getTagsSel withObject:@"weixin"];
                                        #pragma clang diagnostic pop
                                        if (myTags) {
                                            [info appendFormat:@"我的标签: %@\n", myTags];
                                        } else {
                                            [info appendString:@"我的标签: (空)\n"];
                                        }
                                    } else {
                                        [info appendString:@"getArrContactTagIDWithUserName: 不可调用\n"];
                                    }
                                } else {
                                    [info appendString:@"CContactMgr 实例: 获取失败\n"];
                                }
                            } else {
                                [info appendString:@"getService: 不可调用\n"];
                            }
                        }
                    } else {
                        [info appendString:@"sharedInstance: 不可用\n"];
                    }
                }
                
                // 2. 列出 CContactMgr 中所有标签相关方法
                if (contactMgrClass) {
                    [info appendString:@"\n【CContactMgr 标签方法列表】\n"];
                    unsigned int methodCount = 0;
                    Method *methods = class_copyMethodList(contactMgrClass, &methodCount);
                    if (methods) {
                        for (unsigned int i = 0; i < methodCount; i++) {
                            NSString *methodName = NSStringFromSelector(method_getName(methods[i]));
                            if ([methodName.lowercaseString containsString:@"tag"]) {
                                [info appendFormat:@"  %@\n", methodName];
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
    NSLog(@"[WeChatTagGroup] 调试版v5已加载");
}