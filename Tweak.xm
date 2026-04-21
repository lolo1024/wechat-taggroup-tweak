/**
 * WeChat Tag Group - v22 功能版
 * 在搜索栏下方添加标签切换栏
 * [全部] [客户] [其他标签]
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
    
    // 备用：从 getDicOfUserNameAndTagNames 过滤
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
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

#pragma mark - 获取联系人详情

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

#pragma mark - 打开聊天

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

static UIView *createTagTabBar(NSArray *tabNames, NSInteger selectedIndex, void (^onSelect)(NSInteger)) {
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat tabH = 40;
    CGFloat padding = 12;
    CGFloat btnH = 30;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    
    // 计算总宽度
    CGFloat totalW = padding;
    NSMutableArray *btnWidths = [NSMutableArray array];
    UIFont *font = [UIFont systemFontOfSize:14];
    for (NSString *name in tabNames) {
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 24; // 左右padding
        [btnWidths addObject:@(w)];
        totalW += w + 8; // 按钮之间间距
    }
    
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.frame = CGRectMake(0, 5, screenW, tabH);
    [container addSubview:scroll];
    
    CGFloat x = padding;
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGFloat w = [btnWidths[i] floatValue];
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
        
        // 保存索引
        objc_setAssociatedObject(btn, "tabIndex", @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [btn addTarget:nil action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        // 关联回调
        if (onSelect) {
            objc_setAssociatedObject(btn, "tabCallback", onSelect, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        
        [scroll addSubview:btn];
        x += w + 8;
    }
    
    scroll.contentSize = CGSizeMake(x + padding, tabH);
    container.frame = CGRectMake(0, 0, screenW, tabH + 10);
    
    return container;
}

// Tab按钮点击处理
static void (^g_tabCallback)(NSInteger);
static NSArray *g_tabNames;

%new
void setTabCallback(void (^callback)(NSInteger)) {
    g_tabCallback = [callback copy];
}

%new
void setTabNames(NSArray *names) {
    g_tabNames = names;
}

#pragma mark - Hook NewMainFrameViewController

@class NewMainFrameViewController;

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self setupTagTabBar];
    });
}

%new
- (void)setupTagTabBar {
    UIViewController *vc = (UIViewController *)self;
    UIView *parentView = vc.view;
    if (!parentView) return;
    
    // 查找是否已有标签栏
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
            // 尝试获取所有标签名
            id allTags = safeCallNoArg(tm, NSSelectorFromString(@"getAllTagNames"));
            if (allTags && [allTags isKindOfClass:[NSArray class]]) {
                [tabNames addObjectsFromArray:allTags];
            }
        }
    }
    
    setTabNames(tabNames);
    
    // 创建标签栏
    UIView *tabBar = createTagTabBar(tabNames, 0, ^(NSInteger index) {
        // 切换标签
        objc_setAssociatedObject(self, "selectedTabIndex", @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 刷新列表
        UITableView *tv = nil;
        for (UIView *sub in ((UIViewController *)self).view.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tv = (UITableView *)sub;
                break;
            }
        }
        if (tv) {
            [tv reloadData];
            [tv scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
        
        // 更新按钮样式
        UIView *bar = [((UIViewController *)self).view viewWithTag:202422];
        if (bar) {
            for (UIView *sub in bar.subviews) {
                if ([sub isKindOfClass:[UIScrollView class]]) {
                    UIScrollView *scroll = (UIScrollView *)sub;
                    NSInteger idx = 0;
                    for (UIView *btn in scroll.subviews) {
                        if ([btn isKindOfClass:[UIButton class]]) {
                            if (idx == index) {
                                btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                            } else {
                                btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
                                [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                            }
                            idx++;
                        }
                    }
                }
            }
        }
    });
    
    tabBar.tag = 202422;
    [parentView addSubview:tabBar];
    
    // 调整 TableView 位置
    for (UIView *sub in parentView.subviews) {
        if ([sub isKindOfClass:[UITableView class]]) {
            CGRect frame = sub.frame;
            if (frame.origin.y < 100) { // 在导航栏下面
                frame.origin.y = 55; // 移到标签栏下方
                frame.size.height -= 55;
                sub.frame = frame;
            }
            break;
        }
    }
    
    NSLog(@"[WeChatTagGroup] v22 标签栏已添加");
}

// 获取当前选中的标签索引
%new
- (NSInteger)currentTabIndex {
    NSNumber *idx = objc_getAssociatedObject(self, "selectedTabIndex");
    return idx ? [idx integerValue] : 0;
}

// 获取当前标签名
%new
- (NSString *)currentTabName {
    NSInteger idx = [self currentTabIndex];
    if (idx == 0) return @"全部";
    
    NSArray *tabs = g_tabNames;
    if (tabs && idx < (NSInteger)tabs.count) {
        return tabs[idx];
    }
    return @"全部";
}

// 获取当前标签的wxid列表
%new
- (NSArray *)currentTagWxids {
    NSInteger idx = [self currentTabIndex];
    if (idx == 0) return nil; // "全部"返回nil表示不过滤
    
    NSString *tagName = [self currentTabName];
    return getWxidsForTagWithFallback(tagName);
}

// Hook tableView numberOfRowsInSection
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *wxids = [self currentTagWxids];
    if (wxids) {
        // 过滤模式：只显示标签联系人
        NSInteger count = 0;
        for (NSString *wxid in wxids) {
            // 检查是否有会话
            if ([self hasSessionForWxid:wxid]) {
                count++;
            }
        }
        if (count > 0) return count;
    }
    return %orig;
}

// 检查是否有该联系人的会话
%new
- (BOOL)hasSessionForWxid:(NSString *)wxid {
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
        
        // 尝试 getSessionInfoByUsrName:
        SEL sel = NSSelectorFromString(@"getSessionInfoByUsrName:");
        if ([sm respondsToSelector:sel]) {
            id session = [sm performSelector:sel withObject:wxid];
            return session != nil;
        }
        return NO;
        #pragma clang diagnostic pop
    } @catch (NSException *e) { return NO; }
}

// Hook cellForRowAtIndexPath
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *wxids = [self currentTagWxids];
    if (wxids && wxids.count > 0) {
        // 过滤模式
        NSMutableArray *filteredWxids = [NSMutableArray array];
        for (NSString *wxid in wxids) {
            if ([self hasSessionForWxid:wxid]) {
                [filteredWxids addObject:wxid];
            }
        }
        if (indexPath.row < (NSInteger)filteredWxids.count) {
            NSString *wxid = filteredWxids[indexPath.row];
            TagContact *contact = getContactDetail(wxid);
            if (contact) {
                // 返回一个自定义cell
                static NSString *cellId = @"TagGroupChatCell";
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
                    cell.imageView.layer.cornerRadius = 25;
                    cell.imageView.layer.masksToBounds = YES;
                }
                
                cell.textLabel.text = contact.remark ?: contact.nickName ?: wxid;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"@%@", wxid];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                
                // 头像占位
                cell.imageView.image = nil;
                cell.imageView.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
                
                objc_setAssociatedObject(cell, "chatWxid", wxid, OBJC_ASSOCIATION_COPY_NONATOMIC);
                
                return cell;
            }
        }
        return [[UITableViewCell alloc] init]; // 空cell
    }
    return %orig;
}

// Hook didSelectRowAtIndexPath
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSArray *wxids = [self currentTagWxids];
    if (wxids && wxids.count > 0) {
        NSMutableArray *filteredWxids = [NSMutableArray array];
        for (NSString *wxid in wxids) {
            if ([self hasSessionForWxid:wxid]) {
                [filteredWxids addObject:wxid];
            }
        }
        if (indexPath.row < (NSInteger)filteredWxids.count) {
            NSString *wxid = filteredWxids[indexPath.row];
            openChat(wxid);
            return;
        }
    }
    %orig;
}

// 高度
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return %orig;
}

%end

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

%ctor {
    NSLog(@"[WeChatTagGroup] v22功能版已加载 - 标签: %@", kTargetTagName);
}