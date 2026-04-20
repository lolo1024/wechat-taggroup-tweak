/**
 * WeChat Tag Group - 调试版 v10
 * 专注于获取标签"客户"的数据
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WeChatTagGroup v10"
                                                                       message:info
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

// 打印对象的所有 Ivar
static void printIvars(id obj, NSMutableString *info, NSString *prefix) {
    Class c = [obj class];
    while (c && c != [NSObject class]) {
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(c, &ivarCount);
        if (ivars) {
            for (unsigned int i = 0; i < ivarCount; i++) {
                const char *name = ivar_getName(ivars[i]);
                ptrdiff_t offset = ivar_getOffset(ivars[i]);
                if (offset > 0 && name) {
                    void *ptr = (__bridge void *)obj + offset;
                    id value = nil;
                    memcpy(&value, ptr, sizeof(id));
                    NSString *varName = [NSString stringWithUTF8String:name];
                    // 只显示字符串类型的
                    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
                        [info appendFormat:@"%@%@ = %@\n", prefix, varName, value];
                    }
                }
            }
            free(ivars);
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
                
                // 2. 获取 CContactMgr
                Class contactMgrClass = NSClassFromString(@"CContactMgr");
                id contactMgr = nil;
                if (serviceCenter && [serviceCenter respondsToSelector:@selector(getService:)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    contactMgr = [serviceCenter performSelector:@selector(getService:) withObject:contactMgrClass];
                    #pragma clang diagnostic pop
                }
                
                [info appendFormat:@"CContactMgr: %@\n\n", contactMgr ? @"获取成功" : @"失败"];
                
                // 3. 搜索 ContactTagMgr 相关
                Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
                [info appendFormat:@"ContactTagMgr: %@\n", tagMgrClass ? @"存在" : @"不存在"];
                
                // 4. 查找获取标签列表的方法
                if (contactMgrClass) {
                    [info appendString:@"【CContactMgr 中含 Label/Tag 的方法】\n"];
                    unsigned int mcount = 0;
                    Method *methods = class_copyMethodList(contactMgrClass, &mcount);
                    if (methods) {
                        for (unsigned int i = 0; i < mcount; i++) {
                            NSString *mn = NSStringFromSelector(method_getName(methods[i]));
                            if ([mn.lowercaseString containsString:@"label"] || 
                                [mn.lowercaseString containsString:@"tag"]) {
                                [info appendFormat:@"  %@\n", mn];
                            }
                        }
                        free(methods);
                    }
                }
                
                // 5. 查找获取通讯录/联系人列表的方法
                if (contactMgrClass) {
                    [info appendString:@"\n【获取联系人列表的方法】\n"];
                    unsigned int mcount = 0;
                    Method *methods = class_copyMethodList(contactMgrClass, &mcount);
                    if (methods) {
                        for (unsigned int i = 0; i < mcount; i++) {
                            NSString *mn = NSStringFromSelector(method_getName(methods[i]));
                            // 查找获取联系人的方法
                            if ([mn.lowercaseString containsString:@"getcontact"] ||
                                [mn.lowercaseString containsString:@"fetchcontact"] ||
                                [mn.lowercaseString containsString:@"contactlist"] ||
                                [mn.lowercaseString containsString:@"getallcontact"]) {
                                [info appendFormat:@"  %@\n", mn];
                            }
                        }
                        free(methods);
                    }
                }
                
                // 6. 查找 ContactTagMgr 的方法
                if (tagMgrClass) {
                    [info appendString:@"\n【ContactTagMgr 方法】\n"];
                    unsigned int mcount = 0;
                    Method *methods = class_copyMethodList(tagMgrClass, &mcount);
                    if (methods) {
                        for (unsigned int i = 0; i < mcount && i < 30; i++) {
                            NSString *mn = NSStringFromSelector(method_getName(methods[i]));
                            [info appendFormat:@"  %@\n", mn];
                        }
                        free(methods);
                    }
                }
                
                // 7. 获取 getSelfContact
                if (contactMgr && [contactMgr respondsToSelector:@selector(getSelfContact)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id selfContact = [contactMgr performSelector:@selector(getSelfContact)];
                    #pragma clang diagnostic pop
                    
                    [info appendString:@"\n【当前用户信息】\n"];
                    if (selfContact) {
                        printIvars(selfContact, info, @"  ");
                    }
                }
                
                showDebugAlert(info);
            });
        }
    }
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] v10已加载");
}