/**
 * WeChat Tag Group - v22 功能版
 * 在搜索框下方添加标签切换栏
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

#pragma mark - 获取所有标签名称

static NSArray *getAllTagNames() {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return @[];
        
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
        if (!tm) return @[];
        
        // 方法1: GetContactLabelItemsFromFile - 返回标签对象列表
        SEL sel1 = NSSelectorFromString(@"GetContactLabelItemsFromFile");
        if ([tm respondsToSelector:sel1]) {
            id items = safeCallNoArg(tm, sel1);
            if (items && [items isKindOfClass:[NSArray class]]) {
                NSMutableArray *names = [NSMutableArray array];
                for (id item in items) {
                    // 尝试获取标签名
                    for (NSString *m in @[@"getLabelName", @"LabelName", @"name"]) {
                        id name = safeCallNoArg(item, NSSelectorFromString(m));
                        if (name && [name isKindOfClass:[NSString class]] && [(NSString*)name length] > 0) {
                            [names addObject:name];
                            break;
                        }
                    }
                }
                if (names.count > 0) return names;
            }
        }
        
        // 方法2: getDicOfUserNameAndTagNames - 从返回值提取所有标签名
        SEL sel2 = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
        if ([tm respondsToSelector:sel2]) {
            id dic = safeCallNoArg(tm, sel2);
            if (dic && [dic isKindOfClass:[NSDictionary class]]) {
                NSMutableSet *nameSet = [NSMutableSet set];
                for (id tags in [dic allValues]) {
                    if ([tags isKindOfClass:[NSArray class]]) {
                        for (id tag in tags) {
                            if ([tag isKindOfClass:[NSString class]] && [(NSString*)tag length] > 0) {
                                [nameSet addObject:tag];
                            }
                        }
                    } else if ([tags isKindOfClass:[NSString class]] && [(NSString*)tags length] > 0) {
                        [nameSet addObject:tags];
                    }
                }
                if (nameSet.count > 0) return [nameSet allObjects];
            }
        }
        
    } @catch (NSException *e) {}
    return @[];
}

#pragma mark - 获取标签联系人

static NSArray *getWxidsForTag(NSString *tagName) {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return @[];
        
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
        if (!tm) return @[];
        
        SEL sel = NSSelectorFromString(@"getContactsForTagName:");
        if ([tm respondsToSelector:sel]) {
            id result = safeCall(tm, sel, tagName);
            if (result && [result isKindOfClass:[NSArray class]]) return result;
        }
        
        // 备用: getDicOfUserNameAndTagNames
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

#pragma mark - 创建标签栏

static UIView *createTagTabBarView(NSArray *tabNames, NSInteger selectedIndex, void (^onSelect)(NSInteger), CGFloat width) {
    CGFloat tabH = 50;
    CGFloat padding = 15;
    CGFloat btnH = 32;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    
    // 分隔线
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, tabH - 0.5, width, 0.5)];
    line.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    [container addSubview:line];
    
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    NSMutableArray *btns = [NSMutableArray array];
    
    CGFloat x = padding;
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 28;
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
        objc_setAssociatedObject(btn, "tabButtons", btns, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "containerView", container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [btn addTarget:btn action:@selector(tabBtnTap:) forControlEvents:UIControlEventTouchUpInside];
        
        [container addSubview:btn];
        [btns addObject:btn];
        x += w + 10;
    }
    
    container.frame = CGRectMake(0, 0, width, tabH);
    
    return container;
}

@interface UIButton (TabBtn)
- (void)tabBtnTap:(UIButton *)sender;
@end

@implementation UIButton (TabBtn)
- (void)tabBtnTap:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "tabIndex");
    if (!idx) return;
    
    NSInteger newIndex = [idx integerValue];
    
    // 更新按钮样式
    NSArray *btns = objc_getAssociatedObject(sender, "tabButtons");
    UIView *container = objc_getAssociatedObject(sender, "containerView");
    
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
    
    // 回调
    void (^callback)(NSInteger) = objc_getAssociatedObject(sender, "tabCallback");
    if (callback) {
        callback(newIndex);
    }
}
@end

#pragma mark - Hook

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIViewController *vc = (UIViewController *)self;
        UIView *rootView = vc.view;
        if (!rootView) return;
        
        UITableView *tableView = nil;
        UIView *existingBar = nil;
        
        for (UIView *sub in rootView.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tableView = (UITableView *)sub;
            }
            if (sub.tag == 202422) {
                existingBar = sub;
            }
        }
        
        if (!tableView || existingBar) return;
        
        // 获取所有标签
        NSArray *allTags = getAllTagNames();
        NSLog(@"[WeChatTagGroup] 获取到的标签: %@", allTags);
        
        if (allTags.count == 0) {
            // 如果没有标签，只添加"全部"
            NSLog(@"[WeChatTagGroup] 没有找到标签，使用默认");
        }
        
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:allTags];
        
        __block NSInteger currentTab = 0;
        
        UIView *tabBar = createTagTabBarView(tabNames, currentTab, ^(NSInteger index) {
            currentTab = index;
            // 存储当前tab
            objc_setAssociatedObject(tableView, "currentTabIndex", @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            // 刷新
            [tableView reloadData];
        }, tableView.frame.size.width);
        
        tabBar.tag = 202422;
        objc_setAssociatedObject(tableView, "currentTabIndex", @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tableView, "allTabNames", tabNames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 插入到 tableView 的第一个位置（最上层）
        [tableView insertSubview:tabBar atIndex:0];
        
        // 调整 tableView 内容偏移
        CGFloat tabBarH = 50;
        
        // 获取原始 contentInset
        UIEdgeInsets insets = tableView.contentInset;
        
        // 调整 contentOffset 让内容往下移
        if (tableView.contentOffset.y < tabBarH) {
            [tableView setContentOffset:CGPointMake(0, tabBarH - insets.top) animated:NO];
        }
        
        // 调整 frame 让表格视图往下移
        CGRect frame = tableView.frame;
        frame.origin.y += tabBarH;
        frame.size.height -= tabBarH;
        tableView.frame = frame;
        
        NSLog(@"[WeChatTagGroup] v22 标签栏已添加: %@", tabNames);
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v22功能版已加载");
}