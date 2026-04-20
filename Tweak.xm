/**
 * WeChat Tag Group - v14
 * 尝试获取联系人详细信息
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
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v14"
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

// 打印对象的所有方法
static void listMethods(id obj, NSMutableString *info, NSString *prefix) {
    Class c = [obj class];
    while (c && c != [NSObject class]) {
        unsigned int mcount = 0;
        Method *methods = class_copyMethodList(c, &mcount);
        if (methods) {
            for (unsigned int i = 0; i < mcount; i++) {
                NSString *mn = NSStringFromSelector(method_getName(methods[i]));
                // 只显示返回NSString的方法
                Method m = methods[i];
                char retType[256];
                method_getReturnType(m, retType, sizeof(retType));
                if (retType[0] == '@') {
                    [info appendFormat:@"%@%@\n", prefix, mn];
                }
            }
            free(methods);
        }
        c = class_getSuperclass(c);
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
                        // 3. 获取"客户"标签的联系人
                        [info appendString:@"[获取\"客户\"标签联系人]\n"];
                        
                        id contacts = safeCall(tagMgr, NSSelectorFromString(@"getContactsForTagName:"), @"客户");
                        
                        if (contacts && [contacts isKindOfClass:[NSArray class]]) {
                            [info appendFormat:@"找到了 %lu 个联系人:\n\n", (unsigned long)[contacts count]];
                            
                            for (NSInteger i = 0; i < MIN(6, [contacts count]); i++) {
                                @try {
                                    id contact = contacts[i];
                                    
                                    // 先看看这个对象是什么类型
                                    [info appendFormat:@"--- 联系人 %ld ---\n", (long)(i+1)];
                                    [info appendFormat:@"类型: %@\n", NSStringFromClass([contact class])];
                                    
                                    // 尝试各种可能的方法名获取昵称
                                    NSArray *nickMethods = @[
                                        @"getNickName",
                                        @"nickName",
                                        @"getDisplayName",
                                        @"getContactDisplayName",
                                        @"m_nsNickName",
                                        @"getRemarkOrNickOrName",
                                        @"getFriendExternalNickName"
                                    ];
                                    
                                    NSString *nickName = nil;
                                    for (NSString *method in nickMethods) {
                                        id val = safeCallNoArg(contact, NSSelectorFromString(method));
                                        if (val && [val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0) {
                                            nickName = val;
                                            [info appendFormat:@"昵称(%@): %@\n", method, val];
                                            break;
                                        }
                                    }
                                    
                                    // 尝试各种可能的方法名获取微信号/用户名
                                    NSArray *idMethods = @[
                                        @"getUserName",
                                        @"m_nsUsrName", 
                                        @"userName",
                                        @"m_nsHeadImageUrl",
                                        @"getContactID"
                                    ];
                                    
                                    NSString *userId = nil;
                                    for (NSString *method in idMethods) {
                                        id val = safeCallNoArg(contact, NSSelectorFromString(method));
                                        if (val && [val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0) {
                                            userId = val;
                                            [info appendFormat:@"ID(%@): %@\n", method, val];
                                            break;
                                        }
                                    }
                                    
                                    if (!nickName) [info appendString:@"昵称: (空)\n"];
                                    if (!userId) [info appendString:@"ID: (空)\n"];
                                    
                                } @catch (NSException *e) {
                                    [info appendFormat:@"读取出错: %@\n", e];
                                }
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
                }
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] v14已加载");
}