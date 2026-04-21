/**
 * WeChat Tag Group - v22 功能版
 * 在搜索栏下方添加标签切换栏
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *kTargetTagName = @"客户";

#pragma mark - 全局变量

static NSArray *g_tabNames = nil;

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

#pragma mark - 获取标签联系人wxid列表

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
        return @[];
    } @catch (NSException *e) { return @[]; }
}

static NSArray *getWxidsForTagWithFallback(NSString *tagName) {
    NSArray *result = getWxidsForTag(tagName);
    if (result.count > 0) return result;
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        id tm = sc ? safeCall(sc, @selector(getService:), tmc) : nil;
        if (!tm) tm = [[tmc alloc] init];
        if (!tm) return @[];
        SEL sel = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
        if ([tm respondsToSelector:sel]) {
            id dic = safeCallNoArg(tm, sel);
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

#pragma mark - 创建标签栏

static UIView *createTagTabBar(NSArray *tabNames, NSInteger selectedIndex, void (^onSelect)(NSInteger)) {
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat tabH = 40;
    CGFloat padding = 12;
    CGFloat btnH = 30;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    
    UIFont *font = [UIFont systemFontOfSize:14];
    CGFloat x = padding;
    NSMutableArray *btns = [NSMutableArray array];
    
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 24;
        BOOL isSelected = (i == selectedIndex);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = font;
        
        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        
        btn.layer.cornerRadius = btnH / 2;
        btn.frame = CGRectMake(x, (tabH - btnH) / 2, w, btnH);
        
        objc_setAssociatedObject(btn, "tabIndex", @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "tabCallback", onSelect, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:nil action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [container addSubview:btn];
        [btns addObject:btn];
        x += w + 8;
    }
    
    objc_setAssociatedObject(container, "tabButtons", btns, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    container.frame = CGRectMake(0, 0, screenW, tabH + 10);
    
    return container;
}

#pragma mark - Tab按钮点击

@interface UIButton (TagTabClick)
@end

@implementation UIButton (TagTabClick)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL original = @selector(tabButtonTapped:);
        SEL swizzled = @selector(swizzled_tabButtonTapped:);
        Method m1 = class_getInstanceMethod([UIButton class], original);
        Method m2 = class_getInstanceMethod([UIButton class], swizzled);
        if (m1 && m2) {
            method_exchangeImplementations(m1, m2);
        }
    });
}

- (void)swizzled_tabButtonTapped:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "tabIndex");
    if (idx) {
        void (^callback)(NSInteger) = objc_getAssociatedObject(sender, "tabCallback");
        if (callback) {
            callback([idx integerValue]);
        }
    }
    [self swizzled_tabButtonTapped:sender];
}

@end

#pragma mark - Hook NewMainFrameViewController

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIViewController *vc = (UIViewController *)self;
        UIView *parentView = vc.view;
        if (!parentView) return;
        
        UIView *existingBar = [parentView viewWithTag:202422];
        if (existingBar) return;
        
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
        
        g_tabNames = tabNames;
        
        // 选中的tab索引存储
        __block NSInteger selectedIndex = 0;
        
        UIView *tabBar = createTagTabBar(tabNames, selectedIndex, ^(NSInteger index) {
            selectedIndex = index;
            
            // 更新按钮样式
            NSArray *btns = objc_getAssociatedObject(tabBar, "tabButtons");
            for (NSInteger i = 0; i < btns.count; i++) {
                UIButton *btn = btns[i];
                if (i == index) {
                    btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                } else {
                    btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
                    [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                }
            }
            
            // 刷新列表
            for (UIView *sub in parentView.subviews) {
                if ([sub isKindOfClass:[UITableView class]]) {
                    [(UITableView *)sub reloadData];
                    break;
                }
            }
        });
        
        tabBar.tag = 202422;
        [parentView addSubview:tabBar];
        
        // 调整 TableView 位置
        for (UIView *sub in parentView.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                CGRect frame = sub.frame;
                if (frame.origin.y < 100) {
                    frame.origin.y = 55;
                    frame.size.height -= 55;
                    sub.frame = frame;
                }
                break;
            }
        }
        
        NSLog(@"[WeChatTagGroup] v22 标签栏已添加: %@", tabNames);
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 全部标签
    return %orig;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return %orig;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v22功能版已加载");
}