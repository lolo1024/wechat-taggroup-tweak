/**
 * WeChat Tag Group - v15
 * 获取"客户"标签联系人的完整信息（昵称+wxid）
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL _alertShown = NO;

static void showDebugAlert(NSString *info) {
    if (_alertShown) return;
    _alertShown = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v15"
                                                                           message:info
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [rootVC presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e) {
            NSLog(@"[WeChatTagGroup] Alert error: %@", e);
        }
    });
}

static id safeCall(id obj, SEL selector, id arg) {
    @try {
        if (!obj || ![obj respondsToSelector:selector]) return nil;
        NSMethodSignature *sig = [obj methodSignatureForSelector:selector];
        if (!sig) return nil;
        
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:obj];
        [inv setSelector:selector];
        if (arg) [inv setArgument:&arg atIndex:2];
        [inv invoke];
        
        const char *retType = sig.methodReturnType;
        if (retType[0] == '@') {
            __unsafe_unretained id ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        }
        return nil;
    } @catch (NSException *e) {
        return nil;
    }
}

static id safeCallNoArg(id obj, SEL selector) {
    @try {
        if (!obj || ![obj respondsToSelector:selector]) return nil;
        NSMethodSignature *sig = [obj methodSignatureForSelector:selector];
        if (!sig) return nil;
        
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:obj];
        [inv setSelector:selector];
        [inv invoke];
        
        const char *retType = sig.methodReturnType;
        if (retType[0] == '@') {
            __unsafe_unretained id ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        }
        return nil;
    } @catch (NSException *e) {
        return nil;
    }
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (!_alertShown) {
        NSString *className = NSStringFromClass([self class]);
        if ([className isEqualToString:@"NewMainFrameViewController"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                @try {
                    NSMutableString *info = [NSMutableString string];
                    
                    // 1. 获取 MMServiceCenter
                    Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
                    id serviceCenter = safeCallNoArg(serviceCenterClass, @selector(defaultCenter));
                    
                    // 2. 获取 CContactMgr (用于查询联系人详情)
                    Class contactMgrClass = NSClassFromString(@"CContactMgr");
                    id contactMgr = nil;
                    if (serviceCenter && contactMgrClass) {
                        contactMgr = safeCall(serviceCenter, @selector(getService:), contactMgrClass);
                    }
                    
                    // 3. 获取 ContactTagMgr (用于获取标签联系人)
                    Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                    id tagMgr = nil;
                    if (serviceCenter && tagMgrClass) {
                        tagMgr = safeCall(serviceCenter, @selector(getService:), tagMgrClass);
                    }
                    if (!tagMgr) {
                        tagMgr = [[tagMgrClass alloc] init];
                    }
                    
                    [info appendString:@"=== 微信标签分组插件 v15 ===\n\n"];
                    [info appendFormat:@"CContactMgr: %@\n", contactMgr ? @"OK" : @"失败"];
                    [info appendFormat:@"ContactTagMgr: %@\n\n", tagMgr ? @"OK" : @"失败"];
                    
                    if (tagMgr && contactMgr) {
                        // 4. 获取"客户"标签的联系人wxid列表
                        id wxidArray = safeCall(tagMgr, NSSelectorFromString(@"getContactsForTagName:"), @"客户");
                        
                        if (wxidArray && [wxidArray isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"[客户] 标签共有 %lu 人:\n\n", (unsigned long)[wxidArray count]];
                            
                            for (NSInteger i = 0; i < [wxidArray count]; i++) {
                                @try {
                                    NSString *wxid = wxidArray[i];
                                    [info appendFormat:@"%ld. %@\n", (long)(i+1), wxid];
                                    
                                    // 用 wxid 查询联系人详情
                                    id contact = safeCall(contactMgr, NSSelectorFromString(@"getContactByName:"), wxid);
                                    if (contact) {
                                        // 获取昵称
                                        NSString *nickName = nil;
                                        NSArray *nickMethods = @[@"getNickName", @"nickName", @"m_nsNickName"];
                                        for (NSString *method in nickMethods) {
                                            id val = safeCallNoArg(contact, NSSelectorFromString(method));
                                            if (val && [val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0) {
                                                nickName = val;
                                                break;
                                            }
                                        }
                                        
                                        // 获取备注
                                        NSString *remark = nil;
                                        NSArray *remarkMethods = @[@"getRemark", @"m_nsRemark", @"remark"];
                                        for (NSString *method in remarkMethods) {
                                            id val = safeCallNoArg(contact, NSSelectorFromString(method));
                                            if (val && [val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0) {
                                                remark = val;
                                                break;
                                            }
                                        }
                                        
                                        if (nickName && ![nickName isEqualToString:wxid]) {
                                            [info appendFormat:@"   昵称: %@\n", nickName];
                                        }
                                        if (remark && [remark length] > 0) {
                                            [info appendFormat:@"   备注: %@\n", remark];
                                        }
                                    }
                                    
                                } @catch (NSException *e) {
                                    [info appendFormat:@"   读取出错\n"];
                                }
                            }
                            
                            [info appendString:@"\n✅ 数据获取成功！"];
                        } else if (wxidArray) {
                            [info appendFormat:@"返回类型: %@\n", NSStringFromClass([wxidArray class])];
                        } else {
                            [info appendString:@"没有找到\"客户\"标签的联系人\n"];
                        }
                    }
                    
                    showDebugAlert(info);
                    
                } @catch (NSException *e) {
                    NSLog(@"[WeChatTagGroup] Main try error: %@", e);
                    showDebugAlert([NSString stringWithFormat:@"出错了: %@", e]);
                }
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] v15已加载");
}