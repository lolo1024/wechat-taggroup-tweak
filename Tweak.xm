/**
 * WeChat Tag Group - v29 修复版
 * 修复：列表空白（改进API调用）+ 搜索栏
 * 编译：NSInvocation 方式，无 void* 函数指针转换
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSArray *g_allTags = nil;
static NSInteger g_selectedTab = 0;
static id g_originalDataSource = nil;
static UITableView *g_tableView = nil;

#pragma mark - NSInvocation 调用辅助

static id callSelector(id target, SEL selector) {
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
    } @catch (NSException *e) {}
    return nil;
}

static id callSelector1(id target, SEL selector, id arg1) {
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
    } @catch (NSException *e) {}
    return nil;
}

static NSInteger callSelectorInt(id target, SEL selector) {
    @try {
        if (!target || ![target respondsToSelector:selector]) return 0;
        NSMethodSignature *sig = [target methodSignatureForSelector:selector];
        if (!sig) return 0;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:target];
        [inv setSelector:selector];
        [inv invoke];
        if (strcmp(sig.methodReturnType, "i") == 0 || strcmp(sig.methodReturnType, "l") == 0) {
            long ret = 0;
            [inv getReturnValue:&ret];
            return ret;
        }
    } @catch (NSException *e) {}
    return 0;
}

#pragma mark - 获取服务

static id getService(Class svcClass) {
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        if (!scc) return nil;
        id sc = callSelector(scc, @selector(defaultCenter));
        if (!sc) return nil;
        id svc = callSelector1(sc, @selector(getService:), svcClass);
        return svc ?: [[svcClass alloc] init];
    } @catch (NSException *e) {}
    return nil;
}

#pragma mark - 联系人 API

// 通过标签名获取联系人 wxid 列表
static NSArray *getContactsForTag(NSString *tagName) {
    if (!tagName || [tagName length] == 0) return @[];
    @try {
        id tm = getService(NSClassFromString(@"ContactTagMgr"));
        if (!tm) return @[];
        
        // 方法1: getContactsForTagName:
        id r = callSelector1(tm, NSSelectorFromString(@"getContactsForTagName:"), tagName);
        if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
            return r;
        }
        
        // 方法2: getContactsForLabel:
        r = callSelector1(tm, NSSelectorFromString(@"getContactsForLabel:"), tagName);
        if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
            return r;
        }
    } @catch (NSException *e) {}
    return @[];
}

// 获取联系人显示名
static NSString *displayNameForWxid(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return wxid;
    @try {
        id cm = getService(NSClassFromString(@"CContactMgr"));
        if (!cm) return wxid;
        
        id contact = callSelector1(cm, NSSelectorFromString(@"getContactByName:"), wxid);
        if (!contact) return wxid;
        
        // 备注 > 昵称
        NSArray *props = @[@"m_nsRemark", @"remark", @"m_nsRemarkInfo", @"getRemark",
                           @"m_nsNickName", @"nickName", @"m_nsDisplayName", @"displayName"];
        for (NSString *prop in props) {
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

#pragma mark - 获取标签列表（优先测试已知标签）

static NSArray *getTagList() {
    NSMutableArray *tags = [NSMutableArray array];
    
    // 按优先级测试已知标签
    NSArray *knownTags = @[
        @"客户", @"老师", @"商家", @"家长", @"置顶好友",
        @"商家家长", @"乐器商家", @"鲁岳商会", @"鲁岳商会-客户",
        @"2022-09-27", @"竹绿叶-删除我的", @"达尔"
    ];
    
    for (NSString *tag in knownTags) {
        NSArray *contacts = getContactsForTag(tag);
        if (contacts.count > 0) {
            [tags addObject:tag];
            NSLog(@"[WeChatTagGroup] v29 找到标签'%@' → %lu个联系人", tag, (unsigned long)contacts.count);
        }
    }
    
    if (tags.count > 0) return tags;
    
    // 备用：getDicOfUserNameAndTagNames
    @try {
        id tm = getService(NSClassFromString(@"ContactTagMgr"));
        if (tm) {
            id dic = callSelector(tm, NSSelectorFromString(@"getDicOfUserNameAndTagNames"));
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
                NSLog(@"[WeChatTagGroup] v29 备用标签(来自字典): %@", tags);
            }
        }
    } @catch (NSException *e) {}
    
    return tags;
}

#pragma mark - Tab Bar

@interface TagTabBar29 : UIView
@property (nonatomic, strong) NSArray *tabNames;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation TagTabBar29

- (instancetype)initWithFrame:(CGRect)frame tabNames:(NSArray *)names {
    self = [super initWithFrame:frame];
    if (self) {
        _tabNames = names;
        _buttons = [NSMutableArray array];
        _selectedIndex = 0;
        self.backgroundColor = [UIColor whiteColor];
        
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 2)];
        line.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
        [self addSubview:line];
        
        [self rebuildButtons];
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];
    }
    return self;
}

- (void)rebuildButtons {
    for (UIButton *b in self.buttons) [b removeFromSuperview];
    [self.buttons removeAllObjects];
    
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    CGFloat x = 15, btnH = 30;
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
        x += bw + 10;
    }
}

- (void)setSelectedIndex:(NSInteger)idx {
    if (_selectedIndex == idx) return;
    _selectedIndex = idx;
    
    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        b.backgroundColor = (i == idx)
            ? [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0]
            : [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
        [b setTitleColor:(i == idx) ? [UIColor whiteColor] : [UIColor darkGrayColor] forState:UIControlStateNormal];
    }
    
    g_selectedTab = idx;
    NSLog(@"[WeChatTagGroup] v29 点击标签 idx=%ld name='%@'", (long)idx, tagNameForIndex(idx) ?: @"全部");
    
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
            } @catch (NSException *e) {}
        }
        return 0;
    }
    
    NSArray *wxids = getContactsForTag(tagName);
    NSLog(@"[WeChatTagGroup] v29 标签'%@' → %lu个联系人", tagName, (unsigned long)wxids.count);
    return wxids.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *tagName = tagNameForIndex(g_selectedTab);
    
    if (!tagName) {
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
    
    NSArray *wxids = getContactsForTag(tagName);
    if ((NSInteger)indexPath.row >= (NSInteger)wxids.count) {
        return [[UITableViewCell alloc] init];
    }
    
    NSString *wxid = wxids[indexPath.row];
    NSString *showName = displayNameForWxid(wxid);
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TagCell29"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"TagCell29"];
    }
    cell.textLabel.text = showName;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"🏷 %@", tagName];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
    
    NSLog(@"[WeChatTagGroup] v29 cell[%ld]='%@' wxid=%@", (long)indexPath.row, showName, wxid);
    
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
        NSLog(@"[WeChatTagGroup] v29 dataSource=%@", NSStringFromClass([g_originalDataSource class]));
        
        // 获取标签
        g_allTags = getTagList();
        NSLog(@"[WeChatTagGroup] v29 最终标签: %@", g_allTags);
        
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:g_allTags];
        
        CGFloat searchH = 55, tabH = 50;
        CGFloat w = tv.frame.size.width;
        
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, searchH + tabH)];
        header.backgroundColor = [UIColor whiteColor];
        
        // 搜索栏
        UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, searchH)];
        sb.placeholder = @"搜索";
        sb.searchBarStyle = UISearchBarStyleMinimal;
        [header addSubview:sb];
        
        // 标签栏
        TagTabBar29 *tabBar = [[TagTabBar29 alloc]
            initWithFrame:CGRectMake(0, searchH, w, tabH)
                  tabNames:tabNames];
        [header addSubview:tabBar];
        
        tv.tableHeaderView = header;
        
        if (!g_ds) g_ds = [[WeChatTagGroupDS alloc] init];
        tv.dataSource = g_ds;
        
        [tv reloadData];
        NSLog(@"[WeChatTagGroup] v29 初始化完成");
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v29 已加载");
}
