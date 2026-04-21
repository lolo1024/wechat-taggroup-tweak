/**
 * WeChat Tag Group - 调试版 v21
 * 检查所有标签 + 修复联系人获取
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

// 获取所有标签名称
static NSArray *getAllTagNames() {
    @try {
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
        
        if (!serviceCenterClass || !tagMgrClass) return @[];
        
        // 使用 NSInvocation（和 v15 一样的方式）
        id serviceCenter = safeCallNoArg(serviceCenterClass, @selector(defaultCenter));
        if (!serviceCenter) {
            NSLog(@"[WeChatTagGroup] serviceCenter 为空");
            return @[];
        }
        
        id tagMgr = safeCall(serviceCenter, @selector(getService:), tagMgrClass);
        if (!tagMgr) {
            NSLog(@"[WeChatTagGroup] tagMgr 为空，尝试 alloc init");
            tagMgr = [[tagMgrClass alloc] init];
        }
        
        if (!tagMgr) return @[];
        
        // 尝试获取所有标签
        NSMutableArray *tagNames = [NSMutableArray array];
        
        // 方法1: getAllTagNames
        SEL allTagsSel = NSSelectorFromString(@"getAllTagNames");
        if ([tagMgr respondsToSelector:allTagsSel]) {
            id result = safeCallNoArg(tagMgr, allTagsSel);
            if (result && [result isKindOfClass:[NSArray class]]) {
                return result;
            }
        }
        
        // 方法2: getDicOfUserNameAndTagNames
        SEL dicSel = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
        if ([tagMgr respondsToSelector:dicSel]) {
            id dic = safeCallNoArg(tagMgr, dicSel);
            if (dic && [dic isKindOfClass:[NSDictionary class]]) {
                NSMutableSet *names = [NSMutableSet set];
                for (NSArray *tags in [dic allValues]) {
                    if ([tags isKindOfClass:[NSArray class]]) {
                        [names addObjectsFromArray:tags];
                    }
                }
                return [names allObjects];
            }
        }
        
        return tagNames;
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getAllTagNames error: %@", e);
        return @[];
    }
}

// 获取指定标签的联系人wxid列表
static NSArray *getWxidsForTag(NSString *tagName) {
    @try {
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
        
        if (!serviceCenterClass || !tagMgrClass) return @[];
        
        id serviceCenter = safeCallNoArg(serviceCenterClass, @selector(defaultCenter));
        if (!serviceCenter) return @[];
        
        id tagMgr = safeCall(serviceCenter, @selector(getService:), tagMgrClass);
        if (!tagMgr) {
            tagMgr = [[tagMgrClass alloc] init];
        }
        
        if (!tagMgr) return @[];
        
        // 尝试 getContactsForTagName:
        SEL sel = NSSelectorFromString(@"getContactsForTagName:");
        if ([tagMgr respondsToSelector:sel]) {
            id result = safeCall(tagMgr, sel, tagName);
            if (result && [result isKindOfClass:[NSArray class]]) {
                return result;
            }
        }
        
        // 备选: getDicOfUserNameAndTagNames 然后过滤
        SEL dicSel = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
        if ([tagMgr respondsToSelector:dicSel]) {
            id dic = safeCallNoArg(tagMgr, dicSel);
            if (dic && [dic isKindOfClass:[NSDictionary class]]) {
                NSMutableArray *wxids = [NSMutableArray array];
                for (NSString *wxid in dic) {
                    id tags = dic[wxid];
                    if ([tags isKindOfClass:[NSArray class]] && [tags containsObject:tagName]) {
                        [wxids addObject:wxid];
                    }
                }
                return wxids;
            }
        }
        
        return @[];
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getWxidsForTag error: %@", e);
        return @[];
    }
}

// 获取联系人详情
static TagContact *getContactDetail(NSString *wxid) {
    @try {
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        Class contactMgrClass = NSClassFromString(@"CContactMgr");
        
        if (!serviceCenterClass || !contactMgrClass) return nil;
        
        id serviceCenter = safeCallNoArg(serviceCenterClass, @selector(defaultCenter));
        if (!serviceCenter) return nil;
        
        id contactMgr = safeCall(serviceCenter, @selector(getService:), contactMgrClass);
        if (!contactMgr) return nil;
        
        id contact = safeCall(contactMgr, NSSelectorFromString(@"getContactByName:"), wxid);
        if (!contact) return nil;
        
        TagContact *result = [[TagContact alloc] init];
        result.wxid = wxid;
        
        for (NSString *method in @[@"getNickName", @"nickName", @"m_nsNickName"]) {
            id val = safeCallNoArg(contact, NSSelectorFromString(method));
            if (val && [val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0) {
                result.nickName = val;
                break;
            }
        }
        
        for (NSString *method in @[@"getRemark", @"m_nsRemark", @"remark"]) {
            id val = safeCallNoArg(contact, NSSelectorFromString(method));
            if (val && [val isKindOfClass:[NSString class]] && [(NSString*)val length] > 0) {
                result.remark = val;
                break;
            }
        }
        
        if (!result.remark || [result.remark length] == 0) {
            result.remark = result.nickName;
        }
        
        return result;
        
    } @catch (NSException *e) {
        return nil;
    }
}

#pragma mark - Hook

@class NewMainFrameViewController;

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    if (_debugShown) return;
    _debugShown = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIViewController *vc = (UIViewController *)self;
        UIView *myView = vc.view;
        
        if (!myView) return;
        
        // 1. 获取所有标签
        NSArray *allTags = getAllTagNames();
        
        // 2. 获取"客户"标签的联系人
        NSArray *wxids = getWxidsForTag(kTargetTagName);
        
        NSMutableString *info = [NSMutableString string];
        [info appendFormat:@"=== v21 调试信息 ===\n\n"];
        [info appendFormat:@"所有标签 (%lu个):\n", (unsigned long)[allTags count]];
        for (NSString *tag in allTags) {
            [info appendFormat:@"• %@\n", tag];
        }
        
        [info appendFormat:@"\n[%@] 标签联系人 wxid 列表:\n", kTargetTagName];
        [info appendFormat:@"数量: %lu\n", (unsigned long)[wxids count]];
        
        for (NSString *wxid in wxids) {
            TagContact *c = getContactDetail(wxid);
            NSString *name = c ? (c.remark ?: c.nickName ?: wxid) : wxid;
            [info appendFormat:@"• %@\n", name];
        }
        
        // 如果找到联系人，创建 UI
        if (wxids.count > 0) {
            [info appendFormat:@"\n正在创建UI..."];
            
            // 创建标签分组视图
            UIView *container = [[UIView alloc] init];
            container.backgroundColor = [UIColor whiteColor];
            container.tag = 202421;
            
            // 标签头
            UILabel *header = [[UILabel alloc] init];
            header.text = [NSString stringWithFormat:@"📋 %@ (%lu人)", kTargetTagName, (unsigned long)wxids.count];
            header.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
            header.textColor = [UIColor darkTextColor];
            header.frame = CGRectMake(15, 10, 200, 20);
            [container addSubview:header];
            
            // 横向滚动视图
            UIScrollView *scroll = [[UIScrollView alloc] init];
            scroll.showsHorizontalScrollIndicator = NO;
            scroll.frame = CGRectMake(0, 35, myView.frame.size.width, 80);
            [container addSubview:scroll];
            
            CGFloat x = 15;
            CGFloat cellW = 65;
            
            for (NSString *wxid in wxids) {
                TagContact *c = getContactDetail(wxid);
                if (!c) continue;
                
                NSString *displayName = c.remark ?: c.nickName ?: wxid;
                if ([displayName length] > 5) {
                    displayName = [[displayName substringToIndex:5] stringByAppendingString:@"…"];
                }
                
                UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(x, 0, cellW, 75)];
                
                UIView *avatar = [[UIView alloc] initWithFrame:CGRectMake((cellW-45)/2, 0, 45, 45)];
                avatar.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                avatar.layer.cornerRadius = 22.5;
                [cell addSubview:avatar];
                
                NSString *firstChar = @"?";
                if (c.nickName && [c.nickName length] > 0) {
                    unichar ch = [c.nickName characterAtIndex:0];
                    firstChar = [NSString stringWithCharacters:&ch length:1];
                }
                
                UILabel *charLabel = [[UILabel alloc] initWithFrame:avatar.bounds];
                charLabel.text = [firstChar uppercaseString];
                charLabel.textColor = [UIColor whiteColor];
                charLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
                charLabel.textAlignment = NSTextAlignmentCenter;
                [avatar addSubview:charLabel];
                
                UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, cellW, 20)];
                nameLabel.text = displayName;
                nameLabel.font = [UIFont systemFontOfSize:10];
                nameLabel.textColor = [UIColor darkGrayColor];
                nameLabel.textAlignment = NSTextAlignmentCenter;
                [cell addSubview:nameLabel];
                
                cell.accessibilityIdentifier = wxid;
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(handleTap:)];
                [cell addGestureRecognizer:tap];
                
                [scroll addSubview:cell];
                x += cellW + 10;
            }
            
            scroll.contentSize = CGSizeMake(x, 80);
            container.frame = CGRectMake(0, 0, myView.frame.size.width, 120);
            
            [myView addSubview:container];
            
            // 调整 TableView
            for (UIView *subview in myView.subviews) {
                if ([subview isKindOfClass:[UITableView class]]) {
                    CGRect frame = subview.frame;
                    frame.origin.y = 125;
                    frame.size.height -= 125;
                    subview.frame = frame;
                    break;
                }
            }
        }
        
        showDebugAlert(@"WeChatTagGroup v21", info);
    });
}

%end

#pragma mark - Cell点击

@interface UIView (TagGroupTapV21)
- (void)handleTap:(UITapGestureRecognizer *)tap;
@end

@implementation UIView (TagGroupTapV21)
- (void)handleTap:(UITapGestureRecognizer *)tap {
    @try {
        NSString *wxid = self.accessibilityIdentifier;
        if (!wxid || [wxid length] == 0) return;
        
        // 打开聊天
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        if (!serviceCenterClass) return;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id serviceCenter = [serviceCenterClass performSelector:@selector(defaultCenter)];
        if (!serviceCenter) return;
        
        Class msgMgrClass = NSClassFromString(@"CMessageMgr");
        if (!msgMgrClass) return;
        
        id msgMgr = [serviceCenter performSelector:@selector(getService:) withObject:msgMgrClass];
        if (!msgMgr) return;
        
        SEL openSel = NSSelectorFromString(@"openChatViewControllerWithUsername:");
        if ([msgMgr respondsToSelector:openSel]) {
            [msgMgr performSelector:openSel withObject:wxid];
        }
        #pragma clang diagnostic pop
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] handleTap error: %@", e);
    }
}
@end

%ctor {
    NSLog(@"[WeChatTagGroup] v21调试版已加载");
}