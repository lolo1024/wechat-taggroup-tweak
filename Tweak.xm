/**
 * WeChat Tag Group - v26 功能版
 * 修复：搜索栏显示 + 按钮可点击
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
    if (g_allTags && g_allTags.count > 0) return g_allTags;
    
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return @[];
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) tm = [[tmc alloc] init];
        if (!tm) return @[];
        
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
                if (nameSet.count > 0) g_allTags = [nameSet allObjects];
            }
        }
        
        if (!g_allTags || g_allTags.count == 0) {
            NSArray *known = @[@"客户", @"老师", @"商家", @"家长", @"置顶好友"];
            for (NSString *tag in known) {
                if ([tm respondsToSelector:NSSelectorFromString(@"getContactsForTagName:")]) {
                    id r = safeCall(tm, NSSelectorFromString(@"getContactsForTagName:"), tag);
                    if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
                        if (!g_allTags) g_allTags = [NSMutableArray array];
                        [(NSMutableArray *)g_allTags addObject:tag];
                    }
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
        if (!tm) tm = [[tmc alloc] init];
        if (!tm) return @[];
        
        if ([tm respondsToSelector:NSSelectorFromString(@"getContactsForTagName:")]) {
            id r = safeCall(tm, NSSelectorFromString(@"getContactsForTagName:"), tagName);
            if (r && [r isKindOfClass:[NSArray class]]) return r;
        }
        
        if ([tm respondsToSelector:NSSelectorFromString(@"getDicOfUserNameAndTagNames")]) {
            id dic = safeCallNoArg(tm, NSSelectorFromString(@"getDicOfUserNameAndTagNames"));
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

#pragma mark - Tab Bar Container View

@interface TagTabBarContainer : UIView
@property (nonatomic, strong) NSArray *tabNames;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, weak) UITableView *targetTableView;
@end

@implementation TagTabBarContainer

- (instancetype)initWithFrame:(CGRect)frame tabNames:(NSArray *)names {
    self = [super initWithFrame:frame];
    if (self) {
        _tabNames = names;
        _buttons = [NSMutableArray array];
        _selectedIndex = 0;
        self.backgroundColor = [UIColor whiteColor];
        self.userInteractionEnabled = YES;
        
        // 顶部绿色分隔线
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 2)];
        line.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
        line.tag = 999;
        [self addSubview:line];
        
        // 创建按钮
        [self rebuildButtons];
        
        // 点击手势
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)rebuildButtons {
    // 移除旧按钮
    for (UIButton *b in self.buttons) {
        [b removeFromSuperview];
    }
    [self.buttons removeAllObjects];
    
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    CGFloat x = 15;
    CGFloat btnH = 30;
    CGFloat y = (self.frame.size.height - btnH) / 2;
    
    for (NSInteger i = 0; i < self.tabNames.count; i++) {
        NSString *name = self.tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 26;
        BOOL isSelected = (i == self.selectedIndex);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, w, btnH);
        btn.layer.cornerRadius = btnH / 2;
        btn.layer.masksToBounds = YES;
        btn.tag = 200 + i;
        btn.userInteractionEnabled = NO; // 让手势来处理点击
        
        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        
        btn.titleLabel.font = font;
        [btn setTitle:name forState:UIControlStateNormal];
        
        [self addSubview:btn];
        [self.buttons addObject:btn];
        x += w + 10;
    }
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    if (_selectedIndex == selectedIndex) return;
    _selectedIndex = selectedIndex;
    
    // 更新按钮样式
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        if (i == selectedIndex) {
            b.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            b.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [b setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
    }
    
    // 刷新表格
    if (self.targetTableView) {
        [self.targetTableView reloadData];
    }
    
    NSLog(@"[WeChatTagGroup] 切换到标签: %@", self.tabNames[selectedIndex]);
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint pt = [gesture locationInView:self];
    
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        if (CGRectContainsPoint(b.frame, pt)) {
            self.selectedIndex = i;
            return;
        }
    }
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
        
        // 检查是否已有标签栏
        UIView *existing = [tv viewWithTag:202426];
        if (existing) return;
        
        // 获取标签
        NSArray *tags = getAllTagNames();
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:tags];
        
        // 获取原有搜索栏
        UIView *origHeader = tv.tableHeaderView;
        CGFloat searchH = 0;
        UIView *searchBarCopy = nil;
        
        if (origHeader && [origHeader isKindOfClass:[UISearchBar class]]) {
            // 保留搜索栏高度
            searchH = 55;
            // 创建一个新的搜索栏
            UISearchBar *origSB = (UISearchBar *)origHeader;
            UISearchBar *newSB = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, tv.frame.size.width, searchH)];
            newSB.placeholder = origSB.placeholder;
            newSB.barTintColor = origSB.barTintColor;
            newSB.showsBookmarkButton = origSB.showsBookmarkButton;
            newSB.showsSearchResultsButton = origSB.showsSearchResultsButton;
            searchBarCopy = newSB;
        }
        
        // 创建组合 header
        CGFloat tabBarH = 50;
        CGFloat totalH = searchH + tabBarH;
        
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.frame.size.width, totalH)];
        container.backgroundColor = [UIColor whiteColor];
        container.tag = 202425;
        
        // 添加搜索栏
        if (searchBarCopy) {
            searchBarCopy.frame = CGRectMake(0, 0, tv.frame.size.width, searchH);
            [container addSubview:searchBarCopy];
        }
        
        // 添加标签栏
        TagTabBarContainer *tabBar = [[TagTabBarContainer alloc] 
            initWithFrame:CGRectMake(0, searchH, tv.frame.size.width, tabBarH) 
                  tabNames:tabNames];
        tabBar.tag = 202426;
        tabBar.targetTableView = tv;
        [container addSubview:tabBar];
        
        // 设置为 tableHeaderView
        tv.tableHeaderView = container;
        
        NSLog(@"[WeChatTagGroup] v26 headerView 设置完成: totalH=%.0f", totalH);
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v26功能版已加载");
}