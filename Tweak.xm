/**
 * WeChat Tag Group - v13 (安全版)
 * 加了异常保护，不会闪退
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
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v13"
                                                                           message:info
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [rootVC presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e) {
            NSLog(@"[WeChatTagGroup] Alert error: %@", e);
        }
    });
}

// 安全调用方法
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
        NSLog(@"[WeChatTagGroup] safeCall error: %@", e);
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
        NSLog(@"[WeChatTagGroup] safeCallNoArg error: %@", e);
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
                    
                    // 2. 获取 ContactTagMgr
                    Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                    id tagMgr = nil;
                    if (serviceCenter) {
                        tagMgr = safeCall(serviceCenter, @selector(getService:), tagMgrClass);
                    }
                    if (!tagMgr) {
                        tagMgr = [[tagMgrClass alloc] init];
                    }
                    
                    [info appendFormat:@"ContactTagMgr: %@\n\n", tagMgr ? @"获取成功" : @"失败"];
                    
                    if (tagMgr) {
                        // 3. 获取所有标签名
                        NSArray *allLabels = safeCallNoArg(tagMgr, NSSelectorFromString(@"getAllLabelName"));
                        if (allLabels && [allLabels isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"[所有标签名 (%lu个)]\n", (unsigned long)allLabels.count];
                            for (id label in allLabels) {
                                [info appendFormat:@"  - %@\n", label];
                            }
                        }
                        
                        // 4. 尝试获取"客户"标签的联系人
                        [info appendString:@"\n[获取\"客户\"标签联系人]\n"];
                        
                        // 使用 NSInvocation 安全调用
                        id contacts = safeCall(tagMgr, NSSelectorFromString(@"getContactsForTagName:"), @"客户");
                        
                        if (contacts && [contacts isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"找到了 %lu 个联系人:\n", (unsigned long)[contacts count]];
                            
                            for (NSInteger i = 0; i < MIN(10, [contacts count]); i++) {
                                @try {
                                    id contact = contacts[i];
                                    NSString *name = safeCallNoArg(contact, NSSelectorFromString(@"getNickName"));
                                    NSString *wxid = safeCallNoArg(contact, NSSelectorFromString(@"getUserName"));
                                    
                                    [info appendFormat:@"  %ld. %@ (%@)\n", (long)(i+1), 
                                     name ? name : @"?", 
                                     wxid ? wxid : @"?"];
                                } @catch (NSException *e) {
                                    [info appendFormat:@"  %ld. (读取出错)\n", (long)(i+1)];
                                }
                            }
                            
                            if ([contacts count] > 10) {
                                [info appendFormat:@"  ...还有 %lu 个\n", (unsigned long)([contacts count] - 10)];
                            }
                        } else if (contacts) {
                            [info appendFormat:@"返回类型: %@\n", NSStringFromClass([contacts class])];
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
    NSLog(@"[WeChatTagGroup] v13安全版已加载");
}