/**
 * WeChat Tag Group - v22 功能版
 * 把标签栏加到 TableView 的 headerView
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *kTargetTagName = @"客户";

#pragma mark - 安全调用

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
    } @catch (NSException *e) { return nil; }
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
    } @catch (NSException *e) { return nil; }
}

#pragma mark - 数据结构

@interface TagContact : NSObject
@property (nonatomic, strong) NSString *wxid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *remark;
@end
@implementation TagContact
@end

#pragma mark - 获取标签联系人

static NSArray *getWxidsForTagWithFallback(NSString *tagName) {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return @[];
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
        if (!tm) return @[];
        
        // 方法1: getContactsForTagName
        SEL sel = NSSelectorFromString(@"getContactsForTagName:");
        if ([tm respondsToSelector:sel]) {
            id result = safeCall(tm, sel, tagName);
            if (result && [result isKindOfClass:[NSArray class]] && [result count] > 0) return result;
        }
        
        // 方法2: getDicOfUserNameAndTagNames
        SEL sel2 = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
        if ([tm respondsToSelector:sel2]) {
            id dic = safeCallNoArg(tm, sel2);
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
    } @catch (NSException *e) {}
    return @[];
}

static TagContact *getContactDetail(NSString *wxid) {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class cmc = NSClassFromString(@"CContactMgr");
        if (!scc || !cmc) return nil;
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        id cm = safeCall(sc, @selector(getService:), cmc);
        if (!cm) return nil;
        id contact = safeCall(cm, NSSelectorFromString(@"getContactByName:"), wxid);
        if (!contact) return nil;
        TagContact *result = [[TagContact alloc] init];
        result.wxid = wxid;
        for (NSString *m in @[@"getNickName", @"nickName", @"m_nsNickName"]) {
            id v = safeCallNoArg(contact, NSSelectorFromString(m));
            if (v && [v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) {
                result.nickName = v; break;
            }
        }
        for (NSString *m in @[@"getRemark", @"m_nsRemark", @"remark"]) {
            id v = safeCallNoArg(contact, NSSelectorFromString(m));
            if (v && [v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0) {
                result.remark = v; break;
            }
        }
        if (!result.remark || [result.remark length] == 0) result.remark = result.nickName;
        return result;
    } @catch (NSException *e) { return nil; }
}

static BOOL hasSessionForWxid(NSString *wxid) {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class smc = NSClassFromString(@"MMSessionMgr");
        if (!scc || !smc) return NO;
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id sc = [scc performSelector:@selector(defaultCenter)];
        if (!sc) return NO;
        id sm = [sc performSelector:@selector(getService:) withObject:smc];
        if (!sm) return NO;
        SEL sel = NSSelectorFromString(@"getSessionInfoByUsrName:");
        if ([sm respondsToSelector:sel]) {
            id session = [sm performSelector:sel withObject:wxid];
            return session != nil;
        }
        return NO;
        #pragma clang diagnostic pop
    } @catch (NSException *e) { return NO; }
}

static void openChat(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return;
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        if (!scc) return;
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id sc = [scc performSelector:@selector(defaultCenter)];
        if (!sc) return;
        Class mmc = NSClassFromString(@"CMessageMgr");
        if (!mmc) return;
        id mm = [sc performSelector:@selector(getService:) withObject:mmc];
        if (!mm) return;
        SEL sel = NSSelectorFromString(@"openChatViewControllerWithUsername:");
        if ([mm respondsToSelector:sel]) {
            [mm performSelector:sel withObject:wxid];
        }
        #pragma clang diagnostic pop
    } @catch (NSException *e) {}
}

#pragma mark - 创建标签栏视图

static UIView *createTagTabBarView(NSArray *tabNames, NSInteger selectedIndex, void (^onSelect)(NSInteger), CGFloat width) {
    CGFloat tabH = 50;
    CGFloat padding = 15;
    CGFloat btnH = 32;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    
    UIFont *font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    NSMutableArray *btns = [NSMutableArray array];
    
    CGFloat x = padding;
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 30;
        BOOL isSelected = (i == selectedIndex);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = font;
        
        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        
        btn.layer.cornerRadius = btnH / 2;
        btn.frame = CGRectMake(x, (tabH - btnH) / 2, w, btnH);
        btn.layer.masksToBounds = YES;
        
        objc_setAssociatedObject(btn, "tabIndex", @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "tabCallback", onSelect, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:btn action:@selector(tabBtnTap:) forControlEvents:UIControlEventTouchUpInside];
        
        [container addSubview:btn];
        [btns addObject:btn];
        x += w + 10;
    }
    
    objc_setAssociatedObject(container, "tabButtons", btns, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(container, "currentIndex", @(selectedIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    container.frame = CGRectMake(0, 0, width, tabH);
    
    return container;
}

@interface UIButton (TabBtn)
- (void)tabBtnTap:(UIButton *)sender;
@end

@implementation UIButton (TabBtn)
- (void)tabBtnTap:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "tabIndex");
    void (^callback)(NSInteger) = objc_getAssociatedObject(sender, "tabCallback");
    if (idx && callback) {
        NSInteger newIndex = [idx integerValue];
        callback(newIndex);
        
        // 更新按钮样式
        UIView *parent = sender.superview;
        if (parent) {
            NSArray *btns = objc_getAssociatedObject(parent, "tabButtons");
            for (NSInteger i = 0; i < btns.count; i++) {
                UIButton *b = btns[i];
                if (i == newIndex) {
                    b.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                } else {
                    b.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.94 alpha:1.0];
                    [b setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                }
            }
            objc_setAssociatedObject(parent, "currentIndex", @(newIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
@end

#pragma mark - Hook

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UITableView *tableView = nil;
        for (UIView *sub in ((UIViewController *)self).view.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tableView = (UITableView *)sub;
                break;
            }
        }
        if (!tableView) return;
        
        // 检查是否已有标签栏
        UIView *existing = objc_getAssociatedObject(tableView, "tagTabBar");
        if (existing) return;
        
        // 获取所有标签
        NSMutableArray *tabNames = [NSMutableArray arrayWithObjects:@"全部", nil];
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (scc && tmc) {
            id sc = safeCallNoArg(scc, @selector(defaultCenter));
            id tm = sc ? safeCall(sc, @selector(getService:), tmc) : nil;
            if (!tm) tm = [[tmc alloc] init];
            if (tm) {
                id allTags = safeCallNoArg(tm, NSSelectorFromString(@"getAllTagNames"));
                if (allTags && [allTags isKindOfClass:[NSArray class]]) {
                    [tabNames addObjectsFromArray:allTags];
                }
            }
        }
        
        NSInteger currentTab = 0;
        
        UIView *tabBar = createTagTabBarView(tabNames, currentTab, ^(NSInteger index) {
            // 切换标签 - 刷新列表
            objc_setAssociatedObject(tableView, "currentTabIndex", @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [tableView reloadData];
        }, tableView.frame.size.width);
        
        objc_setAssociatedObject(tableView, "tagTabBar", tabBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tableView, "currentTabIndex", @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tableView, "allTabNames", tabNames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 设置为 tableHeaderView
        tableView.tableHeaderView = tabBar;
        
        NSLog(@"[WeChatTagGroup] v22 标签栏已添加: %@", tabNames);
    });
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return %orig;
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v22功能版已加载");
}