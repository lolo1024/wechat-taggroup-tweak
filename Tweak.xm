/**
 * WeChat Tag Group - v30 防御性修复版
 * 修复：所有潜在闪退点，增加运行时安全检查
 * 编译：NSInvocation 方式，无 void* 函数指针转换
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSArray *g_allTags = nil;
static NSInteger g_selectedTab = 0;
static id g_originalDataSource = nil;
static UITableView *g_tableView = nil;

#pragma mark - 安全日志

static void safeLog(NSString *fmt, ...) {
#if DEBUG
    va_list args;
    va_start(args, fmt);
    NSLogv([@"[WeChatTagGroup-v30] " stringByAppendingString:fmt], args);
    va_end(args);
#endif
}

#pragma mark - NSInvocation 调用辅助

static id callSelector(id target, SEL selector) {
    if (!target || ![target respondsToSelector:selector]) return nil;
    @try {
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
        safeLog(@"callSelector 异常: %@", e);
    }
    return nil;
}

static id callSelector1(id target, SEL selector, id arg1) {
    if (!target || ![target respondsToSelector:selector]) return nil;
    @try {
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
        safeLog(@"callSelector1 异常: %@", e);
    }
    return nil;
}

#pragma mark - 获取服务（多重保护）

static id getService(Class svcClass) {
    if (!svcClass) return nil;
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        if (!scc) {
            safeLog(@"MMServiceCenter 不存在!");
            return nil;
        }
        
        id sc = nil;
        SEL defaultSel = NSSelectorFromString(@"defaultCenter");
        if ([scc respondsToSelector:defaultSel]) {
            sc = callSelector(scc, defaultSel);
        }
        if (!sc) {
            safeLog(@"MMServiceCenter.defaultCenter 返回 nil");
            return nil;
        }
        
        SEL getSvcSel = @selector(getService:);
        if (![sc respondsToSelector:getSvcSel]) {
            safeLog(@"getService: 方法不存在");
            return nil;
        }
        
        id svc = callSelector1(sc, getSvcSel, svcClass);
        if (!svc) {
            safeLog(@"getService 返回 nil，尝试 alloc init");
            svc = [[svcClass alloc] init];
        }
        return svc;
    } @catch (NSException *e) {
        safeLog(@"getService 异常: %@", e);
    }
    return nil;
}

#pragma mark - 联系人 API

static NSArray *getContactsForTag(NSString *tagName) {
    if (!tagName || [tagName length] == 0) return @[];
    @try {
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!tmc) {
            safeLog(@"ContactTagMgr 不存在!");
            return @[];
        }
        
        id tm = getService(tmc);
        if (!tm) return @[];
        
        // 尝试多个可能的 API
        NSArray *methods = @[
            @"getContactsForTagName:",
            @"getContactsForLabel:",
            @"GetContactsForTagName:",
            @"GetContactsForLabel:"
        ];
        
        for (NSString *m in methods) {
            SEL sel = NSSelectorFromString(m);
            if ([tm respondsToSelector:sel]) {
                id r = callSelector1(tm, sel, tagName);
                if (r && [r isKindOfClass:[NSArray class]] && [r count] > 0) {
                    safeLog(@"getContacts('%@')=%lu via %@", tagName, (unsigned long)[r count], m);
                    return r;
                }
            }
        }
    } @catch (NSException *e) {
        safeLog(@"getContactsForTag 异常: %@", e);
    }
    return @[];
}

static NSString *displayNameForWxid(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return wxid;
    @try {
        Class cmc = NSClassFromString(@"CContactMgr");
        if (!cmc) return wxid;
        
        id cm = getService(cmc);
        if (!cm) return wxid;
        
        SEL sel = NSSelectorFromString(@"getContactByName:");
        if (![cm respondsToSelector:sel]) return wxid;
        
        id contact = callSelector1(cm, sel, wxid);
        if (!contact) return wxid;
        
        // 备注 > 昵称
        NSArray *props = @[
            @"m_nsRemark", @"remark", @"m_nsRemarkInfo",
            @"m_nsNickName", @"nickName", @"m_nsDisplayName"
        ];
        for (NSString *prop in props) {
            @try {
                id val = [contact valueForKey:prop];
                if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                    return val;
                }
            } @catch (NSException *e) {}
        }
    } @catch (NSException *e) {
        safeLog(@"displayNameForWxid 异常: %@", e);
    }
    return wxid;
}

static NSString *tagNameForIndex(NSInteger idx) {
    if (idx == 0) return nil;
    if (idx - 1 < (NSInteger)g_allTags.count) return g_allTags[idx - 1];
    return nil;
}

#pragma mark - 获取标签列表

static NSArray *getTagList() {
    NSMutableArray *tags = [NSMutableArray array];
    
    // 测试已知标签（过滤空结果）
    NSArray *knownTags = @[
        @"客户", @"老师", @"商家", @"家长", @"置顶好友",
        @"商家家长", @"乐器商家", @"鲁岳商会", @"鲁岳商会-客户",
        @"2022-09-27", @"竹绿叶-删除我的", @"达尔"
    ];
    
    safeLog(@"v30 开始探测标签...");
    
    for (NSString *tag in knownTags) {
        @autoreleasepool {
            NSArray *contacts = getContactsForTag(tag);
            if (contacts.count > 0) {
                [tags addObject:tag];
                safeLog(@"  找到标签'%@' → %lu个联系人", tag, (unsigned long)contacts.count);
            }
        }
    }
    
    if (tags.count > 0) {
        safeLog(@"v30 标签探测完成: %@", tags);
        return tags;
    }
    
    // 备用：getDicOfUserNameAndTagNames
    safeLog(@"v30 尝试备用API...");
    @try {
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (tmc) {
            id tm = getService(tmc);
            if (tm) {
                SEL dicSel = NSSelectorFromString(@"getDicOfUserNameAndTagNames");
                if ([tm respondsToSelector:dicSel]) {
                    id dic = callSelector(tm, dicSel);
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
                        safeLog(@"v30 备用字典标签: %@", tags);
                    }
                }
            }
        }
    } @catch (NSException *e) {
        safeLog(@"v30 备用API异常: %@", e);
    }
    
    return tags;
}

#pragma mark - Tab Bar

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
        self.clipsToBounds = YES;
        
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 2)];
        line.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
        line.tag = 999;
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
        btn.userInteractionEnabled = NO; // 让手势统一处理
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
    safeLog(@"v30 点击标签 idx=%ld name='%@'", (long)idx, tagNameForIndex(idx) ?: @"全部");
    
    if (g_tableView) {
        @try {
            [g_tableView reloadData];
        } @catch (NSException *e) {
            safeLog(@"reloadData 异常: %@", e);
        }
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
        // 全部：委托原始 dataSource
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
                safeLog(@"全部联系人数量异常: %@", e);
            }
        }
        return 0;
    }
    
    @try {
        NSArray *wxids = getContactsForTag(tagName);
        safeLog(@"v30 标签'%@' → %lu个联系人", tagName, (unsigned long)wxids.count);
        return wxids.count;
    } @catch (NSException *e) {
        safeLog(@"numberOfRowsInSection 异常: %@", e);
    }
    return 0;
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
            } @catch (NSException *e) {
                safeLog(@"cellForRowAtIndexPath(全部) 异常: %@", e);
            }
        }
        return [[UITableViewCell alloc] init];
    }
    
    @try {
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
        
        return cell;
    } @catch (NSException *e) {
        safeLog(@"cellForRowAtIndexPath 异常: %@", e);
    }
    return [[UITableViewCell alloc] init];
}

@end

static WeChatTagGroupDS *g_ds = nil;

#pragma mark - Hook（带防御性检查）

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    // 延迟 3 秒执行，等待视图完全加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        @try {
            safeLog(@"v30 viewDidLoad 延迟开始");
            
            UIView *rootView = ((UIViewController *)self).view;
            if (!rootView) {
                safeLog(@"v30 rootView 不存在，退出");
                return;
            }
            
            // 找 TableView
            UITableView *tv = nil;
            for (UIView *sub in rootView.subviews) {
                if ([sub isKindOfClass:[UITableView class]]) {
                    tv = (UITableView *)sub;
                    break;
                }
            }
            if (!tv) {
                safeLog(@"v30 找不到 TableView，退出");
                return;
            }
            if (g_tableView) {
                safeLog(@"v30 已初始化，跳过");
                return;
            }
            
            g_tableView = tv;
            g_originalDataSource = tv.dataSource;
            safeLog(@"v30 dataSource=%@", NSStringFromClass([g_originalDataSource class]));
            
            // 获取标签
            g_allTags = getTagList();
            safeLog(@"v30 最终标签: %@", g_allTags);
            
            NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
            [tabNames addObjectsFromArray:g_allTags];
            
            CGFloat searchH = 55, tabH = 50;
            CGFloat w = tv.frame.size.width;
            
            UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, searchH + tabH)];
            header.backgroundColor = [UIColor whiteColor];
            
            // 搜索栏（占位，不干扰原有功能）
            UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, searchH)];
            sb.placeholder = @"搜索";
            sb.searchBarStyle = UISearchBarStyleMinimal;
            sb.userInteractionEnabled = NO;
            [header addSubview:sb];
            
            // 标签栏
            TagTabBar30 *tabBar = [[TagTabBar30 alloc]
                initWithFrame:CGRectMake(0, searchH, w, tabH)
                      tabNames:tabNames];
            [header addSubview:tabBar];
            
            tv.tableHeaderView = header;
            
            if (!g_ds) g_ds = [[WeChatTagGroupDS alloc] init];
            tv.dataSource = g_ds;
            
            [tv reloadData];
            safeLog(@"v30 初始化完成!");
            
        } @catch (NSException *e) {
            safeLog(@"v30 viewDidLoad 异常: %@", e);
        }
    });
}

%end

%ctor {
    // ─── 关键类安全检查 ───
    // 如果这些类在当前微信版本不存在，直接 return 不加载，避免闪退
    Class mainFrameClass = NSClassFromString(@"NewMainFrameViewController");
    Class tagMgrClass    = NSClassFromString(@"ContactTagMgr");
    Class svcCenterClass = NSClassFromString(@"MMServiceCenter");
    
    NSLog(@"[WeChatTagGroup-v30] 安全检查:");
    NSLog(@"  NewMainFrameViewController: %@", mainFrameClass ? @"✅" : @"❌");
    NSLog(@"  ContactTagMgr: %@", tagMgrClass ? @"✅" : @"❌");
    NSLog(@"  MMServiceCenter: %@", svcCenterClass ? @"✅" : @"❌");
    
    if (!svcCenterClass || !tagMgrClass) {
        NSLog(@"[WeChatTagGroup-v30] ⚠️ 核心服务类不存在，跳过加载");
        return;
    }
    
    if (!mainFrameClass) {
        NSLog(@"[WeChatTagGroup-v30] ⚠️ NewMainFrameViewController 不存在，跳过 Hook");
        return;
    }
    
    NSLog(@"[WeChatTagGroup-v30] ✅ 安全检查通过，准备加载");
}
