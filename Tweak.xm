/**
 * WeChat Tag Group - v22 功能版
 * 在搜索栏下方添加标签切换栏
 * [全部] [客户] [其他标签]
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *kTargetTagName = @"客户";

#pragma mark - 全局变量

static NSArray *g_tabNames = nil;
static void (^g_tabCallback)(NSInteger) = nil;

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
    
    UIFont *font = [UIFont systemFontOfSize:14];
    CGFloat totalW = padding;
    NSMutableArray *btnWidths = [NSMutableArray array];
    for (NSString *name in tabNames) {
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 24;
        [btnWidths addObject:@(w)];
        totalW += w + 8;
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
        
        objc_setAssociatedObject(btn, "tabIndex", @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(btn, "tabCallback", onSelect, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:nil action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [scroll addSubview:btn];
        x += w + 8;
    }
    
    scroll.contentSize = CGSizeMake(x + padding, tabH);
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
    
    UIView *existingBar = [parentView viewWithTag:202422];
    if (existingBar) return;
    
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
    
    __weak typeof(self) weakSelf = self;
    UIView *tabBar = createTagTabBar(tabNames, 0, ^(NSInteger index) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        objc_setAssociatedObject(strongSelf, "selectedTabIndex", @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        UITableView *tv = nil;
        for (UIView *sub in strongSelf.view.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tv = (UITableView *)sub;
                break;
            }
        }
        if (tv) {
            [tv reloadData];
        }
        
        UIView *bar = [strongSelf.view viewWithTag:202422];
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
    
    NSLog(@"[WeChatTagGroup] v22 标签栏已添加");
}

%new
- (NSInteger)currentTabIndex {
    NSNumber *idx = objc_getAssociatedObject(self, "selectedTabIndex");
    return idx ? [idx integerValue] : 0;
}

%new
- (NSString *)currentTabName {
    NSInteger idx = [self currentTabIndex];
    if (idx == 0) return @"全部";
    if (g_tabNames && idx < (NSInteger)g_tabNames.count) {
        return g_tabNames[idx];
    }
    return @"全部";
}

%new
- (NSArray *)currentTagWxids {
    NSInteger idx = [self currentTabIndex];
    if (idx == 0) return nil;
    return getWxidsForTagWithFallback([self currentTabName]);
}

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
        
        SEL sel = NSSelectorFromString(@"getSessionInfoByUsrName:");
        if ([sm respondsToSelector:sel]) {
            id session = [sm performSelector:sel withObject:wxid];
            return session != nil;
        }
        return NO;
        #pragma clang diagnostic pop
    } @catch (NSException *e) { return NO; }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *wxids = [self currentTagWxids];
    if (wxids && wxids.count > 0) {
        NSInteger count = 0;
        for (NSString *wxid in wxids) {
            if ([self hasSessionForWxid:wxid]) {
                count++;
            }
        }
        return count > 0 ? count : 1; // 至少返回1，否则崩溃
    }
    return %orig;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *wxids = [self currentTagWxids];
    if (wxids && wxids.count > 0) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *wxid in wxids) {
            if ([self hasSessionForWxid:wxid]) {
                [filtered addObject:wxid];
            }
        }
        
        if (indexPath.row < (NSInteger)filtered.count) {
            NSString *wxid = filtered[indexPath.row];
            TagContact *contact = getContactDetail(wxid);
            
            static NSString *cellId = @"TagGroupChatCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
            }
            
            cell.textLabel.text = contact.remark ?: contact.nickName ?: wxid;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"@%@", wxid];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = nil;
            cell.imageView.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            cell.imageView.layer.cornerRadius = 25;
            cell.imageView.layer.masksToBounds = YES;
            
            objc_setAssociatedObject(cell, "chatWxid", wxid, OBJC_ASSOCIATION_COPY_NONATOMIC);
            
            return cell;
        }
        // 没有匹配的联系人
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EmptyCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"EmptyCell"];
            cell.textLabel.text = @"暂无聊天";
            cell.textLabel.textColor = [UIColor grayColor];
        }
        return cell;
    }
    return %orig;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSArray *wxids = [self currentTagWxids];
    if (wxids && wxids.count > 0) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *wxid in wxids) {
            if ([self hasSessionForWxid:wxid]) {
                [filtered addObject:wxid];
            }
        }
        
        if (indexPath.row < (NSInteger)filtered.count) {
            NSString *wxid = filtered[indexPath.row];
            openChat(wxid);
            return;
        }
    }
    %orig;
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v22功能版已加载 - 标签: %@", kTargetTagName);
}