/**
 * WeChat Tag Group - 调试版 v20
 * 检测 hook 是否触发
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *kTargetTagName = @"客户";
static BOOL _debugShown = NO;

#pragma mark - 安全调用方法

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

#pragma mark - 显示调试弹窗

static void showDebugAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (vc.presentedViewController) {
                vc = vc.presentedViewController;
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [vc presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e) {
            NSLog(@"[WeChatTagGroup] Alert error: %@", e);
        }
    });
}

#pragma mark - 获取联系人数据

@interface TagContact : NSObject
@property (nonatomic, strong) NSString *wxid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *remark;
@end

@implementation TagContact
@end

static NSArray<TagContact *> *getContactsForTag(NSString *tagName) {
    NSMutableArray<TagContact *> *result = [NSMutableArray array];
    
    @try {
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        Class contactMgrClass = NSClassFromString(@"CContactMgr");
        Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
        
        if (!serviceCenterClass || !contactMgrClass || !tagMgrClass) {
            return result;
        }
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id serviceCenter = [serviceCenterClass performSelector:@selector(defaultCenter)];
        if (!serviceCenter) return result;
        
        id contactMgr = [serviceCenter performSelector:@selector(getService:) withObject:contactMgrClass];
        id tagMgr = [serviceCenter performSelector:@selector(getService:) withObject:tagMgrClass];
        if (!tagMgr) {
            tagMgr = [[tagMgrClass alloc] init];
        }
        #pragma clang diagnostic pop
        
        if (!contactMgr || !tagMgr) return result;
        
        SEL getContactsSel = NSSelectorFromString(@"getContactsForTagName:");
        if (![tagMgr respondsToSelector:getContactsSel]) return result;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSArray *wxidArray = [tagMgr performSelector:getContactsSel withObject:tagName];
        #pragma clang diagnostic pop
        
        if (!wxidArray || ![wxidArray isKindOfClass:[NSArray class]]) return result;
        
        SEL getContactSel = NSSelectorFromString(@"getContactByName:");
        
        for (NSString *wxid in wxidArray) {
            if (![wxid isKindOfClass:[NSString class]]) continue;
            
            TagContact *contact = [[TagContact alloc] init];
            contact.wxid = wxid;
            
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id contactObj = [contactMgr performSelector:getContactSel withObject:wxid];
            #pragma clang diagnostic pop
            
            if (contactObj) {
                for (NSString *method in @[@"getNickName", @"nickName", @"m_nsNickName"]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id val = [contactObj performSelector:NSSelectorFromString(method)];
                    #pragma clang diagnostic pop
                    if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                        contact.nickName = val;
                        break;
                    }
                }
                
                for (NSString *method in @[@"getRemark", @"m_nsRemark", @"remark"]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id val = [contactObj performSelector:NSSelectorFromString(method)];
                    #pragma clang diagnostic pop
                    if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                        contact.remark = val;
                        break;
                    }
                }
            }
            
            if (!contact.remark || [contact.remark length] == 0) {
                contact.remark = contact.nickName;
            }
            
            [result addObject:contact];
        }
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getContactsForTag error: %@", e);
    }
    
    return result;
}

#pragma mark - Hook NewMainFrameViewController

@class NewMainFrameViewController;

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    if (_debugShown) return;
    _debugShown = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIViewController *vc = (UIViewController *)self;
        UIView *myView = vc.view;
        
        if (!myView) {
            showDebugAlert(@"v20 Debug", @"Hook触发但view为空!");
            return;
        }
        
        // 检查视图层级
        NSMutableString *hierarchy = [NSMutableString string];
        [hierarchy appendFormat:@"视图层级:\n"];
        [hierarchy appendFormat:@"- root view: %@\n", NSStringFromClass([myView class])];
        [hierarchy appendFormat:@"- subviews数量: %lu\n\n", (unsigned long)[myView.subviews count]];
        
        for (NSInteger i = 0; i < myView.subviews.count && i < 10; i++) {
            UIView *sub = myView.subviews[i];
            [hierarchy appendFormat:@"%ld. %@ (frame: %@)\n", (long)i, NSStringFromClass([sub class]), NSStringFromCGRect(sub.frame)];
        }
        
        [hierarchy appendFormat:@"\nview.frame: %@", NSStringFromCGRect(myView.frame)];
        
        // 获取联系人数量
        NSArray<TagContact *> *contacts = getContactsForTag(kTargetTagName);
        [hierarchy appendFormat:@"\n\n%@标签联系人: %lu人", kTargetTagName, (unsigned long)contacts.count];
        
        // 尝试添加一个简单的测试视图
        UIView *testView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, myView.frame.size.width, 60)];
        testView.backgroundColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:0.8]; // 橙色
        testView.tag = 202420;
        
        UILabel *testLabel = [[UILabel alloc] initWithFrame:testView.bounds];
        testLabel.text = [NSString stringWithFormat:@"✅ Hook触发! %@标签%lu人", kTargetTagName, (unsigned long)contacts.count];
        testLabel.textColor = [UIColor whiteColor];
        testLabel.textAlignment = NSTextAlignmentCenter;
        testLabel.font = [UIFont systemFontOfSize:16];
        [testView addSubview:testLabel];
        
        [myView addSubview:testView];
        
        // 找到TableView并调整
        for (UIView *subview in myView.subviews) {
            if ([subview isKindOfClass:[UITableView class]]) {
                CGRect frame = subview.frame;
                [hierarchy appendFormat:@"\n\n找到TableView: %@", NSStringFromCGRect(frame)];
                frame.origin.y = 70; // 移到测试视图下方
                frame.size.height -= 70;
                subview.frame = frame;
                [hierarchy appendFormat:@"\n调整后: %@", NSStringFromCGRect(frame)];
                break;
            }
        }
        
        showDebugAlert(@"WeChatTagGroup v20", hierarchy);
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v20调试版已加载");
}