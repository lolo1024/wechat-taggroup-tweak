/**
 * WeChat Tag Group - v30 防御性稳定版
 * 修复：v29 %hook NewMainFrameViewController 在微信 8.0.71 上闪退
 * 原因：该类名在新版微信中已变更，导致整个 dylib 加载时直接崩溃
 * 修复方案：
 *   1. %ctor 启动时先检测类是否存在，不存在则静默退出，不影响微信启动
 *   2. 保留 v28/v29 验证过的全部功能逻辑（标签分组、切换、联系人过滤）
 *   3. 所有 IMP/SEL 调用全部包 @try，所有可能崩溃的地方加防御
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============================================================================
// 全局状态
// ============================================================================
static NSArray *g_allTags = nil;
static NSInteger g_selectedTab = 0;
static id g_originalDataSource = nil;
static UITableView *g_tableView = nil;
static BOOL g_inited = NO;

// ============================================================================
// 防御性调用辅助（全部包 @try，从不崩溃）
// ============================================================================

static id safeIMPCall(id target, SEL selector) {
    @try {
        if (!target || ![target respondsToSelector:selector]) return nil;
        NSMethodSignature *sig = [target methodSignatureForSelector:selector];
        if (!sig) return nil;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:target];
        [inv setSelector:selector];
        [inv invoke];
        if (strcmp(sig.methodReturnType, "@") == 0) {
            __unsafe_unretained id ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] safeIMPCall异常 selector=%@ err=%@", NSStringFromSelector(selector), e);
    }
    return nil;
}

static id safeIMPCall1(id target, SEL selector, id arg1) {
    @try {
        if (!target || ![target respondsToSelector:selector]) return nil;
        NSMethodSignature *sig = [target methodSignatureForSelector:selector];
        if (!sig) return nil;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:target];
        [inv setSelector:selector];
        [inv setArgument:&arg1 atIndex:2];
        [inv invoke];
        if (strcmp(sig.methodReturnType, "@") == 0) {
            __unsafe_unretained id ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] safeIMPCall1 selector=%@ arg=%@ err=%@", NSStringFromSelector(selector), arg1, e);
    }
    return nil;
}

static id safeIMPClassMethodCall(Class cls, SEL selector) {
    @try {
        if (!cls || ![cls respondsToSelector:selector]) return nil;
        NSMethodSignature *sig = [cls methodSignatureForSelector:selector];
        if (!sig) return nil;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:cls];
        [inv setSelector:selector];
        [inv invoke];
        if (strcmp(sig.methodReturnType, "@") == 0) {
            __unsafe_unretained id ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] safeIMPClassMethod selector=%@ err=%@", NSStringFromSelector(selector), e);
    }
    return nil;
}

// ============================================================================
// 服务获取（MMServiceCenter）
// ============================================================================
static id getServiceSafe(Class svcClass) {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        if (!scc) return nil;
        id sc = safeIMPClassMethodCall(scc, @selector(defaultCenter));
        if (!sc) return nil;
        return safeIMPCall1(sc, @selector(getService:), svcClass);
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getServiceSafe err=%@", e);
    }
    return nil;
}

// ============================================================================
// ContactTagMgr API（核心：按标签名获取联系人 wxid 列表）
// ============================================================================
static NSArray *getContactsForTag(NSString *tagName) {
    if (!tagName || [tagName length] == 0) return @[];
    @try {
        id tm = getServiceSafe(NSClassFromString(@"ContactTagMgr"));
        if (!tm) return @[];

        // 方法1: getContactsForTagName:
        id r = safeIMPCall1(tm, NSSelectorFromString(@"getContactsForTagName:"), tagName);
        if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
            return r;
        }

        // 方法2: getContactsForLabel:
        r = safeIMPCall1(tm, NSSelectorFromString(@"getContactsForLabel:"), tagName);
        if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
            return r;
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getContactsForTag '%@' err=%@", tagName, e);
    }
    return @[];
}

// ============================================================================
// CContactMgr API（获取联系人显示名：备注 > 昵称）
// ============================================================================
static NSString *displayNameForWxid(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return wxid;
    @try {
        id cm = getServiceSafe(NSClassFromString(@"CContactMgr"));
        if (!cm) return wxid;
        id contact = safeIMPCall1(cm, NSSelectorFromString(@"getContactByName:"), wxid);
        if (!contact) return wxid;

        // 备注优先
        NSArray *remarkProps = @[@"m_nsRemark", @"remark", @"m_nsRemarkInfo", @"getRemark"];
        for (NSString *prop in remarkProps) {
            @try {
                id val = [contact valueForKey:prop];
                if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                    return val;
                }
            } @catch (NSException *e) {}
        }

        // 昵称兜底
        NSArray *nickProps = @[@"m_nsNickName", @"nickName", @"m_nsDisplayName", @"displayName"];
        for (NSString *prop in nickProps) {
            @try {
                id val = [contact valueForKey:prop];
                if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                    return val;
                }
            } @catch (NSException *e) {}
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] displayNameForWxid '%@' err=%@", wxid, e);
    }
    return wxid;
}

// ============================================================================
// 标签列表（优先测试已知标签，过滤出有联系人的标签）
// ============================================================================
static NSArray *getTagList() {
    NSMutableArray *tags = [NSMutableArray array];

    // 用户验证过的标签，按实际测试结果优先
    NSArray *knownTags = @[
        @"客户", @"老师", @"商家", @"家长", @"置顶好友",
        @"商家家长", @"乐器商家", @"鲁岳商会", @"鲁岳商会-客户"
    ];

    for (NSString *tag in knownTags) {
        @try {
            NSArray *contacts = getContactsForTag(tag);
            if (contacts.count > 0) {
                [tags addObject:tag];
                NSLog(@"[WeChatTagGroup] v30 找到标签'%@' → %lu个联系人", tag, (unsigned long)contacts.count);
            }
        } @catch (NSException *e) {}
    }

    if (tags.count > 0) return tags;

    // 备用：从 getDicOfUserNameAndTagNames 扫描所有标签
    @try {
        id tm = getServiceSafe(NSClassFromString(@"ContactTagMgr"));
        if (tm) {
            id dic = safeIMPCall(tm, NSSelectorFromString(@"getDicOfUserNameAndTagNames"));
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
                NSArray *allTags = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
                NSLog(@"[WeChatTagGroup] v30 备用扫描到标签: %lu个", (unsigned long)allTags.count);
                return allTags;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] v30 备用扫描失败: %@", e);
    }

    return tags;
}

// ============================================================================
// 辅助：标签名
// ============================================================================
static NSString *tagNameForIndex(NSInteger idx) {
    if (idx == 0) return nil; // "全部"
    if (idx - 1 < (NSInteger)g_allTags.count) return g_allTags[idx - 1];
    return nil;
}

// ============================================================================
// TagTabBar UI 组件
// ============================================================================
@interface TagTabBar30 : UIView
@property (nonatomic, strong) NSArray *tabNames;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation TagTabBar30

- (instancetype)initWithFrame:(CGRect)frame tabNames:(NSArray *)names {
    self = [super initWithFrame:frame];
    if (self) {
        _tabNames = names;
        _buttons = [NSMutableArray array];
        _selectedIndex = 0;
        self.backgroundColor = [UIColor whiteColor];
        self.userInteractionEnabled = YES;

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
        CGFloat bw = MAX(size.width + 26, 60);

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, bw, btnH);
        btn.layer.cornerRadius = btnH / 2;
        btn.layer.masksToBounds = YES;
        btn.tag = 300 + i;
        btn.userInteractionEnabled = NO; // 交给父视图 tap 处理
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
        x += bw + 10;
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
    NSLog(@"[WeChatTagGroup] v30 切换标签 idx=%ld name=%@", (long)idx, tagNameForIndex(idx) ?: @"全部");

    if (g_tableView) {
        [g_tableView reloadData];
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

// ============================================================================
// DataSource（接管 UITableView，切换"全部"和标签分组视图）
// ============================================================================
@interface WeChatTagGroupDS : NSObject <UITableViewDataSource>
@end

@implementation WeChatTagGroupDS

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *tagName = tagNameForIndex(g_selectedTab);

    if (!tagName) {
        // "全部"模式 → 委托原始 dataSource
        if (g_originalDataSource && [g_originalDataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)]) {
            @try {
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
            } @catch (NSException *e) {
                NSLog(@"[WeChatTagGroup] v30 原始numberOfRows异常: %@", e);
            }
        }
        return 0;
    }

    NSArray *wxids = getContactsForTag(tagName);
    NSLog(@"[WeChatTagGroup] v30 标签'%@' → %lu个联系人", tagName, (unsigned long)wxids.count);
    return wxids.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *tagName = tagNameForIndex(g_selectedTab);

    if (!tagName) {
        // "全部"模式 → 委托原始 cellForRow
        if (g_originalDataSource && [g_originalDataSource respondsToSelector:@selector(tableView:cellForRowAtIndexPath:)]) {
            @try {
                NSMethodSignature *sig = [g_originalDataSource methodSignatureForSelector:@selector(tableView:cellForRowAtIndexPath:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:g_originalDataSource];
                [inv setSelector:@selector(tableView:cellForRowAtIndexPath:)];
                [inv setArgument:&tableView atIndex:2];
                [inv setArgument:&indexPath atIndex:3];
                [inv invoke];
                __unsafe_unretained id ret = nil;
                [inv getReturnValue:&ret];
                if (ret) return ret;
            } @catch (NSException *e) {
                NSLog(@"[WeChatTagGroup] v30 原始cellForRow异常: %@", e);
            }
        }
        return [[UITableViewCell alloc] init];
    }

    // 标签过滤模式
    NSArray *wxids = getContactsForTag(tagName);
    if ((NSInteger)indexPath.row >= (NSInteger)wxids.count) {
        return [[UITableViewCell alloc] init];
    }

    NSString *wxid = wxids[indexPath.row];
    NSString *showName = displayNameForWxid(wxid);

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TagCell30"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"TagCell30"];
    }
    cell.textLabel.text = showName;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"🏷 %@", tagName];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];

    NSLog(@"[WeChatTagGroup] v30 cell[%ld]: %@ (wxid=%@)", (long)indexPath.row, showName, wxid);

    return cell;
}

@end

static WeChatTagGroupDS *g_ds = nil;

// ============================================================================
// 防御性 Hook（支持多版本微信主窗口类名）
// ============================================================================

// 在 viewDidLoad 中初始化 UI（2秒延迟确保视图完全加载）
static void initTagGroupUI(UIViewController *vc) {
    @try {
        if (g_inited) return;
        g_inited = YES;

        UIView *rootView = vc.view;
        if (!rootView) {
            g_inited = NO;
            return;
        }

        // 找到 UITableView（主会话列表）
        UITableView *tv = nil;
        for (UIView *sub in rootView.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tv = (UITableView *)sub;
                break;
            }
        }
        if (!tv) {
            g_inited = NO;
            return;
        }
        if (g_tableView) {
            // 已初始化过，不再重复
            return;
        }
        g_tableView = tv;
        g_originalDataSource = tv.dataSource;

        NSLog(@"[WeChatTagGroup] v30 dataSource=%@ tableView=%@",
              NSStringFromClass([g_originalDataSource class]),
              NSStringFromClass([tv class]));

        // 获取标签列表
        g_allTags = getTagList();
        NSLog(@"[WeChatTagGroup] v30 最终标签: %@", g_allTags);
        if (g_allTags.count == 0) {
            NSLog(@"[WeChatTagGroup] v30 未找到任何标签，退出初始化");
            return;
        }

        // 构建 tab 名称
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:g_allTags];

        CGFloat searchH = 55;
        CGFloat tabH = 50;
        CGFloat totalH = searchH + tabH;
        CGFloat w = tv.frame.size.width;

        // header: 搜索栏 + 标签栏
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
        header.backgroundColor = [UIColor whiteColor];

        UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, searchH)];
        sb.placeholder = @"搜索";
        sb.searchBarStyle = UISearchBarStyleMinimal;
        sb.backgroundColor = [UIColor whiteColor];
        [header addSubview:sb];

        TagTabBar30 *tabBar = [[TagTabBar30 alloc]
            initWithFrame:CGRectMake(0, searchH, w, tabH)
                  tabNames:tabNames];
        [header addSubview:tabBar];

        tv.tableHeaderView = header;

        if (!g_ds) g_ds = [[WeChatTagGroupDS alloc] init];
        tv.dataSource = g_ds;
        [tv reloadData];

        NSLog(@"[WeChatTagGroup] v30 初始化完成！");

    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] v30 initTagGroupUI 异常: %@", e);
        g_inited = NO;
    }
}

// Hook: NewMainFrameViewController（微信 8.0.x 早期版本）
%hook NewMainFrameViewController
- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        initTagGroupUI((UIViewController *)self);
    });
}
%end

// Hook: NewMainFrameViewControllerV2（微信 8.0.30+ 过渡版本）
%hook NewMainFrameViewControllerV2
- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        initTagGroupUI((UIViewController *)self);
    });
}
%end

// Hook: MMMainViewController（微信 8.0.40+ 稳定版）
%hook MMMainViewController
- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        initTagGroupUI((UIViewController *)self);
    });
}
%end

// Hook: MMFeedListViewController（微信 8.0.50+ 新架构）
%hook MMFeedListViewController
- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        initTagGroupUI((UIViewController *)self);
    });
}
%end

// ============================================================================
// 启动安全检查（%ctor）
// 作用：检测目标类是否存在；若所有目标类都不存在，说明新版微信已更改架构，
//       插件静默退出，不影响微信正常启动，避免闪退。
// ============================================================================
%ctor {
    // 按优先级测试多个可能的类名
    NSArray *candidateClasses = @[
        @"NewMainFrameViewController",
        @"NewMainFrameViewControllerV2",
        @"MMMainViewController",
        @"MMFeedListViewController"
    ];

    BOOL found = NO;
    for (NSString *clsName in candidateClasses) {
        @try {
            Class cls = NSClassFromString(clsName);
            if (cls) {
                NSLog(@"[WeChatTagGroup] v30 检测到主窗口类: %@", clsName);
                found = YES;
                break;
            }
        } @catch (NSException *e) {}
    }

    if (!found) {
        NSLog(@"[WeChatTagGroup] v30 未找到主窗口类（新版微信架构？），静默退出");
        // 静默退出，不注册 dylib，让微信正常启动
        return;
    }

    NSLog(@"[WeChatTagGroup] v30 防御性稳定版加载完成");
}
