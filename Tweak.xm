/**
 * WeChat Tag Group - v11
 * 获取"客户"标签的联系人
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v11"
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
                
                // 2. 获取 ContactTagMgr (尝试通过 serviceCenter)
                Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                id tagMgr = nil;
                if (serviceCenter && tagMgrClass && [serviceCenter respondsToSelector:@selector(getService:)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    tagMgr = [serviceCenter performSelector:@selector(getService:) withObject:tagMgrClass];
                    #pragma clang diagnostic pop
                }
                
                // 如果 serviceCenter 不行，尝试 alloc init
                if (!tagMgr && tagMgrClass) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    tagMgr = [[tagMgrClass alloc] init];
                    #pragma clang diagnostic pop
                }
                
                [info appendFormat:@"ContactTagMgr: %@\n", tagMgr ? @"获取成功" : @"失败"];
                
                if (tagMgr) {
                    [info appendFormat:@"实例: %@\n\n", tagMgr];
                    
                    // 3. 尝试 getDicOfUserNameAndTagNames
                    SEL dicSel = NSSelectorFromString(@"getDicOfUserNameAndTagNames:");
                    if ([tagMgr respondsToSelector:dicSel]) {
                        [info appendString:@"[getDicOfUserNameAndTagNames:]\n"];
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        NSDictionary *dic = [tagMgr performSelector:dicSel];
                        #pragma clang diagnostic pop
                        if (dic && dic.count > 0) {
                            [info appendFormat:@"返回了 %lu 个联系人\n", (unsigned long)dic.count];
                            // 遍历找有"客户"标签的
                            NSInteger found = 0;
                            for (NSString *username in dic) {
                                id tagInfo = dic[username];
                                NSString *tagStr = nil;
                                if ([tagInfo isKindOfClass:[NSString class]]) {
                                    tagStr = tagInfo;
                                } else if ([tagInfo isKindOfClass:[NSArray class]]) {
                                    tagStr = [(NSArray *)tagInfo componentsJoinedByString:@","];
                                } else {
                                    tagStr = [NSString stringWithFormat:@"%@", tagInfo];
                                }
                                if ([tagStr containsString:@"客户"]) {
                                    [info appendFormat:@"★ %@: %@\n", username, tagStr];
                                    found++;
                                    if (found >= 10) {
                                        [info appendFormat:@"...还有更多\n"];
                                        break;
                                    }
                                }
                            }
                            if (found == 0) {
                                [info appendString:@"没有找到\"客户\"标签的联系人\n"];
                                // 打印前几个看看格式
                                [info appendString:@"\n前几个数据样例:\n"];
                                NSArray *keys = [dic allKeys];
                                for (NSInteger i = 0; i < MIN(3, keys.count); i++) {
                                    NSString *key = keys[i];
                                    [info appendFormat:@"  %@: %@\n", key, dic[key]];
                                }
                            }
                        } else {
                            [info appendString:@"返回为空\n"];
                        }
                    } else {
                        [info appendString:@"getDicOfUserNameAndTagNames: 不可用\n"];
                    }
                    
                    // 4. 尝试 shouldGetAllLabelsFromServer
                    SEL refreshSel = NSSelectorFromString(@"shouldGetAllLabelsFromServer");
                    if ([tagMgr respondsToSelector:refreshSel]) {
                        [info appendString:@"\n[shouldGetAllLabelsFromServer]\n"];
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [tagMgr performSelector:refreshSel];
                        #pragma clang diagnostic pop
                        [info appendString:@"已调用\n"];
                        
                        // 再试一次 getDicOfUserNameAndTagNames
                        if ([tagMgr respondsToSelector:dicSel]) {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            NSDictionary *dic = [tagMgr performSelector:dicSel];
                            #pragma clang diagnostic pop
                            [info appendFormat:@"刷新后: %lu 个联系人\n", (unsigned long)dic.count];
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
    NSLog(@"[WeChatTagGroup] v11已加载");
}