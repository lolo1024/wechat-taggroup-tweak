/**
 * WeChat Tag Group - v27 功能版
 * 修复：搜索栏功能恢复 + 标签过滤逻辑
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSArray *g_allTags = nil;
static NSInteger g_selectedTab = 0; // 0=全部, 1+=具体标签

// 保存原始的 delegate 和 dataSource
static id g_originalDelegate = nil;
static id g_originalDataSource = nil;
static UITableView *g_tableView = nil;

// 原始方法实现（用 IMP 类型避免 void* 函数指针转换问题）
static IMP orig_numberOfSections_impl = NULL;
static IMP orig_numberOfRowsInSection_impl = NULL;
static IMP orig_cellForRow_impl = NULL;

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

#pragma mark - 获取联系人

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

static NSString *tagNameForIndex(NSInteger idx) {
    if (idx == 0) return nil; // 全部
    if (idx - 1 < g_allTags.count) return g_allTags[idx - 1];
    return nil;
}

#pragma mark - Tab Bar Container View

@interface TagTabBar27 : UIView
@property (nonatomic, strong) NSArray *tabNames;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation TagTabBar27

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
        [self addSubview:line];
        
        [self rebuildButtons];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)rebuildButtons {
    for (UIButton *b in self.buttons) [b removeFromSuperview];
    [self.buttons removeAllObjects];
    
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    CGFloat x = 15;
    CGFloat btnH = 30;
    CGFloat y = (self.frame.size.height - btnH) / 2;
    
    for (NSInteger i = 0; i < self.tabNames.count; i++) {
        NSString *name = self.tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 26;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, w, btnH);
        btn.layer.cornerRadius = btnH / 2;
        btn.layer.masksToBounds = YES;
        btn.tag = 300 + i;
        btn.userInteractionEnabled = NO;
        btn.titleLabel.font = font;
        [btn setTitle:name forState:UIControlStateNormal];
        
        if (i == self.selectedIndex) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        
        [self addSubview:btn];
        [self.buttons addObject:btn];
        x += w + 10;
    }
}

- (void)setSelectedIndex:(NSInteger)idx {
    if (_selectedIndex == idx) return;
    _selectedIndex = idx;
    
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        if (i == idx) {
            b.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            b.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [b setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
    }
    
    g_selectedTab = idx;
    
    if (g_tableView) {
        [g_tableView reloadData];
        NSLog(@"[WeChatTagGroup] v27 刷新列表，标签=%@", tagNameForIndex(idx));
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint pt = [gesture locationInView:self];
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        if (CGRectContainsPoint([self.buttons[i] frame], pt)) {
            self.selectedIndex = i;
            return;
        }
    }
}

@end

#pragma mark - DataSource Hook

@interface WeChatTagGroupDataSource : NSObject <UITableViewDataSource>
@end

@implementation WeChatTagGroupDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (g_selectedTab == 0) {
        if (orig_numberOfSections_impl && g_originalDataSource) {
            NSMethodSignature *sig = [g_originalDataSource methodSignatureForSelector:@selector(numberOfSectionsInTableView:)];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:g_originalDataSource];
            [inv setSelector:@selector(numberOfSectionsInTableView:)];
            [inv setArgument:&tableView atIndex:2];
            [inv invoke];
            NSInteger ret = 0;
            [inv getReturnValue:&ret];
            return ret;
        }
        return 1;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *tagName = tagNameForIndex(g_selectedTab);
    
    if (!tagName) {
        // 全部
        if (orig_numberOfRowsInSection_impl && g_originalDataSource) {
            NSMethodSignature *sig = [g_originalDataSource methodSignatureForSelector:@selector(tableView:numberOfRowsInSection:)];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:g_originalDataSource];
            [inv setSelector:@selector(tableView:numberOfRowsInSection:)];
            [inv setArgument:&tableView atIndex:2];
            [inv setArgument:&section atIndex:3];
            [inv invoke];
            NSInteger ret = 0;
            [inv getReturnValue:&ret];
            return ret;
        }
        return 0;
    }
    
    // 获取该标签的联系人 wxid 列表
    NSArray *wxids = getWxidsForTag(tagName);
    NSLog(@"[WeChatTagGroup] v27 标签'%@'有%lu个联系人", tagName, (unsigned long)wxids.count);
    return wxids.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *tagName = tagNameForIndex(g_selectedTab);
    
    if (!tagName) {
        // 全部: 调用原始
        if (orig_cellForRow_impl && g_originalDataSource) {
            NSMethodSignature *sig = [g_originalDataSource methodSignatureForSelector:@selector(tableView:cellForRowAtIndexPath:)];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:g_originalDataSource];
            [inv setSelector:@selector(tableView:cellForRowAtIndexPath:)];
            [inv setArgument:&tableView atIndex:2];
            [inv setArgument:&indexPath atIndex:3];
            [inv invoke];
            __unsafe_unretained id ret = nil;
            [inv getReturnValue:&ret];
            return ret ?: [[UITableViewCell alloc] init];
        }
        return [[UITableViewCell alloc] init];
    }
    
    // 过滤模式: 获取该标签的联系人
    NSArray *wxids = getWxidsForTag(tagName);
    if (indexPath.row >= wxids.count) return [[UITableViewCell alloc] init];
    
    NSString *wxid = wxids[indexPath.row];
    
    // 获取联系人信息
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class cmc = NSClassFromString(@"CContactMgr");
        if (scc && cmc) {
            id sc = safeCallNoArg(scc, @selector(defaultCenter));
            if (sc) {
                id cm = safeCall(sc, @selector(getService:), cmc);
                if (cm && [cm respondsToSelector:NSSelectorFromString(@"getContactByName:")]) {
                    id contact = safeCall(cm, NSSelectorFromString(@"getContactByName:"), wxid);
                    if (contact) {
                        // 尝试获取昵称
                        NSString *nickName = nil;
                        for (NSString *prop in @[@"m_nsNickName", @"nickName", @"getNickName", @"m_nsDisplayName", @"displayName"]) {
                            id val = [contact valueForKey:prop];
                            if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                                nickName = val;
                                break;
                            }
                        }
                        // 获取备注
                        NSString *remark = nil;
                        for (NSString *prop in @[@"m_nsRemark", @"remark", @"getRemark"]) {
                            id val = [contact valueForKey:prop];
                            if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                                remark = val;
                                break;
                            }
                        }
                        
                        NSString *showName = remark ?: nickName ?: wxid;
                        NSLog(@"[WeChatTagGroup] v27 显示联系人: %@ (wxid=%@)", showName, wxid);
                        
                        // 创建 cell
                        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TagGroupCell"];
                        if (!cell) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"TagGroupCell"];
                        }
                        cell.textLabel.text = showName;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"🏷️ %@", tagName];
                        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                        return cell;
                    }
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] v27 cell error: %@", e);
    }
    
    // fallback: 简单显示
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TagGroupSimple"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TagGroupSimple"];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"👤 %@", wxid];
    return cell;
}

@end

static WeChatTagGroupDataSource *g_dataSource = nil;

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
        if (g_tableView) return; // 防止重复
        g_tableView = tv;
        
        // 保存原始 delegate 和 dataSource
        g_originalDelegate = tv.delegate;
        g_originalDataSource = tv.dataSource;
        
        NSLog(@"[WeChatTagGroup] v27 原始 delegate=%@ dataSource=%@",
              NSStringFromClass([g_originalDelegate class]),
              NSStringFromClass([g_originalDataSource class]));
        
        // 尝试保存原始方法实现
        if (g_originalDataSource) {
            Class cls = [g_originalDataSource class];
            
            SEL s1 = @selector(numberOfSectionsInTableView:);
            if ([g_originalDataSource respondsToSelector:s1]) {
                Method m1 = class_getInstanceMethod(cls, s1);
                if (m1) orig_numberOfSections_impl = method_getImplementation(m1);
            }
            
            SEL s2 = @selector(tableView:numberOfRowsInSection:);
            if ([g_originalDataSource respondsToSelector:s2]) {
                Method m2 = class_getInstanceMethod(cls, s2);
                if (m2) orig_numberOfRowsInSection_impl = method_getImplementation(m2);
            }
            
            SEL s3 = @selector(tableView:cellForRowAtIndexPath:);
            if ([g_originalDataSource respondsToSelector:s3]) {
                Method m3 = class_getInstanceMethod(cls, s3);
                if (m3) orig_cellForRow_impl = method_getImplementation(m3);
            }
        }
        
        // 获取标签
        g_allTags = [(id)self getTagList];
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:g_allTags];
        
        // 获取原有搜索栏
        UIView *origHeader = tv.tableHeaderView;
        CGFloat searchH = 55;
        CGFloat tabH = 50;
        
        UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.frame.size.width, searchH + tabH)];
        headerContainer.backgroundColor = [UIColor whiteColor];
        headerContainer.tag = 202427;
        
        // 方案A: 把原有 tableHeaderView 作为搜索栏（保留原有功能）
        if (origHeader) {
            origHeader.frame = CGRectMake(0, 0, tv.frame.size.width, searchH);
            [headerContainer addSubview:origHeader];
        } else {
            // 没有搜索栏？创建一个
            UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, tv.frame.size.width, searchH)];
            sb.placeholder = @"搜索";
            [headerContainer addSubview:sb];
        }
        
        // 标签栏
        TagTabBar27 *tabBar = [[TagTabBar27 alloc] initWithFrame:CGRectMake(0, searchH, tv.frame.size.width, tabH) tabNames:tabNames];
        tabBar.tag = 20242701;
        [headerContainer addSubview:tabBar];
        
        tv.tableHeaderView = headerContainer;
        
        // 替换 dataSource（保留 delegate 用于滚动等事件）
        if (!g_dataSource) g_dataSource = [[WeChatTagGroupDataSource alloc] init];
        tv.dataSource = g_dataSource;
        
        // 保留原始 delegate（用于滚动、点击等）
        // 警告：delegate 和 dataSource 可能指向同一个对象
        // 如果我们只替换 dataSource 部分方法，其他 delegate 方法仍然走原始 delegate
        
        [tv reloadData];
        NSLog(@"[WeChatTagGroup] v27 设置完成，标签:%@", g_allTags);
    });
}

%new
- (NSArray *)getTagList {
    NSMutableArray *tags = [NSMutableArray array];
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return tags;
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return tags;
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
        if (!tm) return tags;
        
        // 从字典获取
        if ([tm respondsToSelector:NSSelectorFromString(@"getDicOfUserNameAndTagNames")]) {
            id dic = safeCallNoArg(tm, NSSelectorFromString(@"getDicOfUserNameAndTagNames"));
            if (dic && [dic isKindOfClass:[NSDictionary class]]) {
                NSMutableSet *set = [NSMutableSet set];
                for (id arr in [dic allValues]) {
                    if ([arr isKindOfClass:[NSArray class]]) {
                        for (id t in arr) {
                            if ([t isKindOfClass:[NSString class]] && [(NSString *)t length] > 0) {
                                [set addObject:t];
                            }
                        }
                    }
                }
                [tags addObjectsFromArray:[set allObjects]];
            }
        }
        
        // 备用
        if (tags.count == 0) {
            NSArray *known = @[@"客户", @"老师", @"商家", @"家长", @"置顶好友"];
            for (NSString *tag in known) {
                if ([tm respondsToSelector:NSSelectorFromString(@"getContactsForTagName:")]) {
                    id r = safeCall(tm, NSSelectorFromString(@"getContactsForTagName:"), tag);
                    if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
                        [tags addObject:tag];
                    }
                }
            }
        }
    } @catch (NSException *e) {}
    return tags;
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v27功能版已加载");
}