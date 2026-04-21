/**
 * WeChat Tag Group - v28 修复版
 * 修复：联系人列表空白（改进API调用）+ 搜索栏重建
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSArray *g_allTags = nil;
static NSInteger g_selectedTab = 0;

static id g_originalDataSource = nil;
static UITableView *g_tableView = nil;

#pragma mark - 核心：获取联系人

static NSArray *getContactsForTag_v28(NSString *tagName) {
    if (!tagName || [tagName length] == 0) return @[];
    
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        
        id sc = nil;
        @try {
            SEL defaultSel = NSSelectorFromString(@"defaultCenter");
            if ([scc respondsToSelector:defaultSel]) {
                IMP imp = [scc methodForSelector:defaultSel];
                id (*func)(id, SEL) = (void *)imp;
                sc = func(scc, defaultSel);
            }
        } @catch (NSException *e) {}
        if (!sc) return @[];
        
        // 获取 ContactTagMgr
        id tm = nil;
        @try {
            SEL svcSel = @selector(getService:);
            if ([sc respondsToSelector:svcSel]) {
                IMP imp = [sc methodForSelector:svcSel];
                id (*func)(id, SEL, Class) = (void *)imp;
                tm = func(sc, svcSel, tmc);
            }
        } @catch (NSException *e) {}
        if (!tm) return @[];
        
        // 方法1: getContactsForTagName:
        @try {
            SEL sel = NSSelectorFromString(@"getContactsForTagName:");
            if ([tm respondsToSelector:sel]) {
                IMP imp = [tm methodForSelector:sel];
                id (*func)(id, SEL, NSString *) = (void *)imp;
                id result = func(tm, sel, tagName);
                if (result && [result isKindOfClass:[NSArray class]] && [result count] > 0) {
                    NSLog(@"[WeChatTagGroup] v28 getContactsForTag('%@')=%lu个 via 直接调用", tagName, (unsigned long)[result count]);
                    return result;
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[WeChatTagGroup] v28 方法1异常: %@", e);
        }
        
        // 方法2: getContactsForLabel:
        @try {
            SEL sel = NSSelectorFromString(@"getContactsForLabel:");
            if ([tm respondsToSelector:sel]) {
                IMP imp = [tm methodForSelector:sel];
                id (*func)(id, SEL, NSString *) = (void *)imp;
                id result = func(tm, sel, tagName);
                if (result && [result isKindOfClass:[NSArray class]] && [result count] > 0) {
                    NSLog(@"[WeChatTagGroup] v28 getContactsForLabel('%@')=%lu个", tagName, (unsigned long)[result count]);
                    return result;
                }
            }
        } @catch (NSException *e) {}
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] v28 getContactsForTag异常: %@", e);
    }
    
    return @[];
}

#pragma mark - 获取联系人详情

static NSString *displayNameForWxid(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return wxid;
    
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class cmc = NSClassFromString(@"CContactMgr");
        if (!scc || !cmc) return wxid;
        
        id sc = nil;
        @try {
            IMP imp = [scc methodForSelector:NSSelectorFromString(@"defaultCenter")];
            id (*func)(id, SEL) = (void *)imp;
            sc = func(scc, NSSelectorFromString(@"defaultCenter"));
        } @catch (NSException *e) {}
        if (!sc) return wxid;
        
        id cm = nil;
        @try {
            IMP imp = [sc methodForSelector:@selector(getService:)];
            id (*func)(id, SEL, Class) = (void *)imp;
            cm = func(sc, @selector(getService:), cmc);
        } @catch (NSException *e) {}
        if (!cm) return wxid;
        
        SEL sel = NSSelectorFromString(@"getContactByName:");
        if (![cm respondsToSelector:sel]) return wxid;
        
        IMP imp = [cm methodForSelector:sel];
        id (*func)(id, SEL, NSString *) = (void *)imp;
        id contact = func(cm, sel, wxid);
        if (!contact) return wxid;
        
        // 尝试获取备注 > 昵称
        NSArray *remarkProps = @[@"m_nsRemark", @"remark", @"getRemark", @"m_nsRemarkInfo"];
        for (NSString *prop in remarkProps) {
            @try {
                id val = [contact valueForKey:prop];
                if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                    return val;
                }
            } @catch (NSException *e) {}
        }
        
        NSArray *nickProps = @[@"m_nsNickName", @"nickName", @"getNickName", @"m_nsDisplayName"];
        for (NSString *prop in nickProps) {
            @try {
                id val = [contact valueForKey:prop];
                if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                    return val;
                }
            } @catch (NSException *e) {}
        }
        
    } @catch (NSException *e) {}
    
    return wxid;
}

static NSString *tagNameForIndex(NSInteger idx) {
    if (idx == 0) return nil;
    if (idx - 1 < (NSInteger)g_allTags.count) return g_allTags[idx - 1];
    return nil;
}

#pragma mark - 获取标签列表（优先用已知标签）

static NSArray *getTagListFromTagMgr() {
    NSMutableArray *tags = [NSMutableArray array];
    
    // 优先测试已知标签（这些是 v15 验证过的）
    NSArray *knownTags = @[@"客户", @"老师", @"商家", @"家长", @"置顶好友", @"商家家长", @"乐器商家", @"鲁岳商会", @"鲁岳商会-客户"];
    
    for (NSString *tag in knownTags) {
        NSArray *contacts = getContactsForTag_v28(tag);
        if (contacts.count > 0) {
            [tags addObject:tag];
            NSLog(@"[WeChatTagGroup] v28 找到标签'%@'，%lu个联系人", tag, (unsigned long)contacts.count);
        }
    }
    
    if (tags.count > 0) return tags;
    
    // 备用：从字典获取
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (scc && tmc) {
            IMP imp = [scc methodForSelector:NSSelectorFromString(@"defaultCenter")];
            id (*func)(id, SEL) = (void *)imp;
            id sc = func(scc, NSSelectorFromString(@"defaultCenter"));
            if (sc) {
                IMP imp2 = [sc methodForSelector:@selector(getService:)];
                id (*func2)(id, SEL, Class) = (void *)imp2;
                id tm = func2(sc, @selector(getService:), tmc);
                if (tm) {
                    SEL sel = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
                    if ([tm respondsToSelector:sel]) {
                        IMP imp3 = [tm methodForSelector:sel];
                        id (*func3)(id, SEL) = (void *)imp3;
                        id dic = func3(tm, sel);
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
                            NSLog(@"[WeChatTagGroup] v28 备用字典标签: %@", tags);
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {}
    
    return tags;
}

#pragma mark - Tab Bar

@interface TagTabBar28 : UIView
@property (nonatomic, strong) NSArray *tabNames;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation TagTabBar28

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
        CGFloat w = MAX(size.width + 26, 60);
        
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
    NSLog(@"[WeChatTagGroup] v28 点击标签 idx=%ld name=%@", (long)idx, tagNameForIndex(idx));
    
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

#pragma mark - DataSource

@interface WeChatTagGroupDS : NSObject <UITableViewDataSource>
@end

@implementation WeChatTagGroupDS

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *tagName = tagNameForIndex(g_selectedTab);
    
    if (!tagName) {
        // 全部：调用原始 dataSource
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
                NSLog(@"[WeChatTagGroup] v28 全部联系人: %ld", (long)ret);
                return ret;
            } @catch (NSException *e) {}
        }
        return 0;
    }
    
    // 具体标签
    NSArray *wxids = getContactsForTag_v28(tagName);
    NSLog(@"[WeChatTagGroup] v28 标签'%@'联系人: %ld", tagName, (long)wxids.count);
    return wxids.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *tagName = tagNameForIndex(g_selectedTab);
    
    if (!tagName) {
        // 全部：调用原始
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
            } @catch (NSException *e) {}
        }
        return [[UITableViewCell alloc] init];
    }
    
    // 过滤模式
    NSArray *wxids = getContactsForTag_v28(tagName);
    if ((NSInteger)indexPath.row >= (NSInteger)wxids.count) {
        return [[UITableViewCell alloc] init];
    }
    
    NSString *wxid = wxids[indexPath.row];
    NSString *showName = displayNameForWxid(wxid);
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TagCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"TagCell"];
    }
    cell.textLabel.text = showName;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"🏷 %@", tagName];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
    
    NSLog(@"[WeChatTagGroup] v28 cell[%ld]: %@ (wxid=%@)", (long)indexPath.row, showName, wxid);
    
    return cell;
}

@end

static WeChatTagGroupDS *g_ds = nil;

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
        if (g_tableView) return;
        g_tableView = tv;
        
        g_originalDataSource = tv.dataSource;
        NSLog(@"[WeChatTagGroup] v28 dataSource=%@", NSStringFromClass([g_originalDataSource class]));
        
        // 获取标签（优先测试已知标签是否有联系人）
        g_allTags = getTagListFromTagMgr();
        NSLog(@"[WeChatTagGroup] v28 最终标签列表: %@", g_allTags);
        
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:g_allTags];
        
        // 创建 header：搜索栏 + 标签栏
        CGFloat searchH = 55;
        CGFloat tabH = 50;
        CGFloat totalH = searchH + tabH;
        CGFloat w = tv.frame.size.width;
        
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalH)];
        header.backgroundColor = [UIColor whiteColor];
        
        // 搜索栏（重建，确保可见）
        UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, searchH)];
        sb.placeholder = @"搜索";
        sb.searchBarStyle = UISearchBarStyleMinimal;
        sb.backgroundColor = [UIColor whiteColor];
        [header addSubview:sb];
        
        // 标签栏
        TagTabBar28 *tabBar = [[TagTabBar28 alloc]
            initWithFrame:CGRectMake(0, searchH, w, tabH)
                  tabNames:tabNames];
        tabBar.tag = 202428;
        [header addSubview:tabBar];
        
        tv.tableHeaderView = header;
        
        // 替换 dataSource
        if (!g_ds) g_ds = [[WeChatTagGroupDS alloc] init];
        tv.dataSource = g_ds;
        
        [tv reloadData];
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v28 已加载");
}
