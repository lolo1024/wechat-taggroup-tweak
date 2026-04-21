/**
 * WeChat Tag Group - v25 功能版
 * 修复：标签栏加到 tableHeaderView，替换搜索栏位置
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSArray *g_allTags = nil;
static NSInteger g_selectedTab = 0;

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

#pragma mark - 获取所有标签

static NSArray *getAllTagNames() {
    if (g_allTags) return g_allTags;
    
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return @[];
        
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
        if (!tm) return @[];
        
        // 从 getDicOfUserNameAndTagNames 提取
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
                    }
                }
                if (nameSet.count > 0) {
                    g_allTags = [nameSet allObjects];
                    return g_allTags;
                }
            }
        }
        
        // 备用: 已知标签
        NSArray *knownTags = @[@"客户", @"老师", @"商家", @"家长", @"置顶好友"];
        for (NSString *tag in knownTags) {
            SEL sel3 = NSSelectorFromString(@"getContactsForTagName:");
            if ([tm respondsToSelector:sel3]) {
                id result = safeCall(tm, sel3, tag);
                if (result && [result isKindOfClass:[NSArray class]] && [result count] > 0) {
                    if (!g_allTags) g_allTags = [NSMutableArray array];
                    [(NSMutableArray *)g_allTags addObject:tag];
                }
            }
        }
        
    } @catch (NSException *e) {}
    return g_allTags ?: @[];
}

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
        
        // 备用
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

#pragma mark - 创建组合 HeaderView（搜索栏+标签栏）

static UIView *createHeaderView(UISearchBar *searchBar, NSArray *tabNames, UITableView *tableView) {
    CGFloat searchH = searchBar ? 55 : 0;
    CGFloat tabH = 50;
    CGFloat totalH = searchH + tabH;
    CGFloat width = tableView.frame.size.width;
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, totalH)];
    container.backgroundColor = [UIColor whiteColor];
    container.tag = 202425;
    
    // 搜索栏
    if (searchBar) {
        searchBar.frame = CGRectMake(0, 0, width, searchH);
        [container addSubview:searchBar];
    }
    
    // 标签栏（紧接搜索栏下方）
    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, searchH, width, tabH)];
    tabBar.backgroundColor = [UIColor whiteColor];
    tabBar.tag = 202426;
    [container addSubview:tabBar];
    
    // 顶部绿色分隔线
    UIView *greenLine = [[UIView alloc] initWithFrame:CGRectMake(0, searchH, width, 2)];
    greenLine.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
    [container addSubview:greenLine];
    
    // 标签按钮
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    CGFloat x = 15;
    NSMutableArray *btns = [NSMutableArray array];
    
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 26;
        BOOL isSelected = (i == g_selectedTab);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = font;
        btn.frame = CGRectMake(x, (tabH - 30) / 2, w, 30);
        btn.layer.cornerRadius = 15;
        btn.layer.masksToBounds = YES;
        btn.userInteractionEnabled = YES;
        
        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        
        btn.tag = 100 + i;
        [tabBar addSubview:btn];
        [btns addObject:btn];
        x += w + 10;
    }
    
    objc_setAssociatedObject(tabBar, "tabButtons", btns, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(container, "tabBar", tabBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 给按钮加点击事件
    for (NSInteger i = 0; i < btns.count; i++) {
        UIButton *btn = btns[i];
        NSInteger index = i;
        
        [btn addTarget:nil action:@selector(tagTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        // 用 associated object 存储索引
        objc_setAssociatedObject(btn, "tabIndexValue", @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return container;
}

@interface UIButton (TagTab25)
@end

@implementation UIButton (TagTab25)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL orig = @selector(tagTabTapped:);
        SEL swiz = @selector(swizzled_tagTabTapped:);
        Method m1 = class_getInstanceMethod([UIButton class], orig);
        Method m2 = class_getInstanceMethod([UIButton class], swiz);
        if (m1 && m2) {
            method_exchangeImplementations(m1, m2);
        }
    });
}

- (void)swizzled_tagTabTapped:(UIButton *)sender {
    NSNumber *num = objc_getAssociatedObject(sender, "tabIndexValue");
    if (!num) {
        [self swizzled_tagTabTapped:sender];
        return;
    }
    
    NSInteger idx = [num integerValue];
    g_selectedTab = idx;
    
    // 更新所有按钮样式
    UIView *tabBar = sender.superview;
    if (tabBar) {
        NSArray *btns = objc_getAssociatedObject(tabBar, "tabButtons");
        for (NSInteger i = 0; i < btns.count; i++) {
            UIButton *b = btns[i];
            if (i == idx) {
                b.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else {
                b.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
                [b setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
            }
        }
    }
    
    NSLog(@"[WeChatTagGroup] 切换到标签: %ld", (long)idx);
    
    [self swizzled_tagTabTapped:sender];
}

@end

#pragma mark - Hook

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIView *rootView = ((UIViewController *)self).view;
        if (!rootView) return;
        
        UITableView *tv = nil;
        for (UIView *sub in rootView.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tv = (UITableView *)sub;
                break;
            }
        }
        if (!tv) return;
        
        // 检查是否已有
        if ([tv.tableHeaderView viewWithTag:202425]) return;
        
        // 获取标签
        NSArray *tags = getAllTagNames();
        NSLog(@"[WeChatTagGroup] v25 获取标签: %@", tags);
        
        // 创建标签列表
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:tags];
        
        // 获取搜索栏
        UISearchBar *searchBar = (UISearchBar *)tv.tableHeaderView;
        if (![searchBar isKindOfClass:[UISearchBar class]]) {
            searchBar = nil;
        }
        
        // 创建组合 headerView
        UIView *header = createHeaderView(searchBar, tabNames, tv);
        
        // 设置为 tableHeaderView
        tv.tableHeaderView = header;
        
        NSLog(@"[WeChatTagGroup] v25 已设置 headerView: %@", NSStringFromCGRect(header.frame));
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v25功能版已加载");
}