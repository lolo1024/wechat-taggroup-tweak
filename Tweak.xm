/**
 * WeChat Tag Group - v12
 * 直接获取"客户"标签的联系人
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v12"
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
                
                // 1. 获取 MMServiceCenter
                Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                id serviceCenter = nil;
                if (serviceCenterClass && [serviceCenterClass respondsToSelector:@selector(defaultCenter)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    serviceCenter = [serviceCenterClass performSelector:@selector(defaultCenter)];
                    #pragma clang diagnostic pop
                }
                
                // 2. 获取 ContactTagMgr
                Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                id tagMgr = nil;
                if (serviceCenter && tagMgrClass && [serviceCenter respondsToSelector:@selector(getService:)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    tagMgr = [serviceCenter performSelector:@selector(getService:) withObject:tagMgrClass];
                    #pragma clang diagnostic pop
                }
                if (!tagMgr && tagMgrClass) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    tagMgr = [[tagMgrClass alloc] init];
                    #pragma clang diagnostic pop
                }
                
                [info appendFormat:@"ContactTagMgr: %@\n\n", tagMgr ? @"获取成功" : @"失败"];
                
                if (tagMgr) {
                    // 3. 获取所有标签名
                    SEL allLabelSel = NSSelectorFromString(@"getAllLabelName");
                    NSArray *allLabels = nil;
                    if ([tagMgr respondsToSelector:allLabelSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        allLabels = [tagMgr performSelector:allLabelSel];
                        #pragma clang diagnostic pop
                        
                        if (allLabels && [allLabels isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"[所有标签名 (%lu个)]\n", (unsigned long)allLabels.count];
                            for (id label in allLabels) {
                                [info appendFormat:@"  - %@\n", label];
                            }
                        }
                    }
                    
                    // 4. 核心：获取"客户"标签的联系人
                    [info appendString:@"\n[获取\"客户\"标签联系人]\n"];
                    
                    // 方法1: getContactsForTagName:
                    SEL forTagNameSel = NSSelectorFromString(@"getContactsForTagName:");
                    if ([tagMgr respondsToSelector:forTagNameSel]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id contacts = [tagMgr performSelector:forTagNameSel withObject:@"客户"];
                        #pragma clang diagnostic pop
                        
                        if (contacts && [contacts isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"getContactsForTagName: 返回了 %lu 个联系人\n", (unsigned long)[contacts count]];
                            
                            // 打印联系人信息
                            for (NSInteger i = 0; i < MIN(20, [contacts count]); i++) {
                                id contact = contacts[i];
                                NSString *name = nil;
                                NSString *wxid = nil;
                                
                                // 尝试获取昵称
                                SEL nicknameSel = NSSelectorFromString(@"getNickName");
                                if ([contact respondsToSelector:nicknameSel]) {
                                    #pragma clang diagnostic push
                                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                    name = [contact performSelector:nicknameSel];
                                    #pragma clang diagnostic pop
                                }
                                
                                // 尝试获取微信号
                                SEL wxidSel = NSSelectorFromString(@"getUserName");
                                if ([contact respondsToSelector:wxidSel]) {
                                    #pragma clang diagnostic push
                                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                    wxid = [contact performSelector:wxidSel];
                                    #pragma clang diagnostic pop
                                }
                                
                                [info appendFormat:@"  %ld. %@ (%@)\n", (long)(i+1), name ? name : @"?", wxid ? wxid : @"?"];
                            }
                            
                            if ([contacts count] > 20) {
                                [info appendFormat:@"  ...还有 %lu 个\n", (unsigned long)([contacts count] - 20)];
                            }
                        } else if (contacts) {
                            [info appendFormat:@"返回类型: %@\n", NSStringFromClass([contacts class])];
                        } else {
                            [info appendString:@"返回为空\n"];
                        }
                    } else {
                        [info appendString:@"getContactsForTagName: 不可用\n"];
                    }
                    
                    // 方法2: getContactsForLabel: (备用)
                    SEL forLabelSel = NSSelectorFromString(@"getContactsForLabel:");
                    if ([tagMgr respondsToSelector:forLabelSel] && allLabels) {
                        [info appendString:@"\n[备用: getContactsForLabel:]\n"];
                        // 尝试用标签名作为参数
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        id contacts2 = [tagMgr performSelector:forLabelSel withObject:@"客户"];
                        #pragma clang diagnostic pop
                        if (contacts2) {
                            [info appendFormat:@"返回: %@\n", contacts2];
                        }
                    }
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] v12已加载");
}