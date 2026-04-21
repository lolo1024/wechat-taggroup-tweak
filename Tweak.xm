/**
 * WeChat Tag Group - v24 功能版
 * 修复：获取标签列表 + 搜索栏位置
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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
    @try {
        Class scc = NSClassFromString(@"MMServiceCenter");
        Class tmc = NSClassFromString(@"ContactTagMgr");
        if (!scc || !tmc) return @[];
        
        id sc = safeCallNoArg(scc, @selector(defaultCenter));
        if (!sc) return @[];
        
        id tm = safeCall(sc, @selector(getService:), tmc);
        if (!tm) { tm = [[tmc alloc] init]; }
        if (!tm) return @[];
        
        // 方法1: 尝试 getAllTagNames
        SEL sel1 = NSSelectorFromString(@"getAllTagNames");
        if ([tm respondsToSelector:sel1]) {
            id result = safeCallNoArg(tm, sel1);
            if (result && [result isKindOfClass:[NSArray class]] && [result count] > 0) {
                NSLog(@"[WeChatTagGroup] getAllTagNames 返回 %lu 个", (unsigned long)[result count]);
                return result;
            }
        }
        
        // 方法2: 从 getDicOfUserNameAndTagNames 提取
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
                    } else if ([tags isKindOfClass:[NSString class]] && [(NSString*)tags length] > 0) {
                        [nameSet addObject:tags];
                    }
                }
                if (nameSet.count > 0) {
                    NSLog(@"[WeChatTagGroup] getDic 提取到 %lu 个标签", (unsigned long)nameSet.count);
                    return [nameSet allObjects];
                }
            }
        }
        
        // 方法3: 尝试已知标签
        NSArray *knownTags = @[@"客户", @"老师", @"商家", @"家长", @"置顶好友"];
        NSMutableArray *existingTags = [NSMutableArray array];
        for (NSString *tag in knownTags) {
            SEL sel3 = NSSelectorFromString(@"getContactsForTagName:");
            if ([tm respondsToSelector:sel3]) {
                id result = safeCall(tm, sel3, tag);
                if (result && [result isKindOfClass:[NSArray class]] && [result count] > 0) {
                    [existingTags addObject:tag];
                }
            }
        }
        if (existingTags.count > 0) {
            NSLog(@"[WeChatTagGroup] 逐个查询找到标签: %@", existingTags);
            return existingTags;
        }
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getAllTagNames error: %@", e);
    }
    return @[];
}

static void showDebug(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (vc.presentedViewController) vc = vc.presentedViewController;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"v24 Debug"
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [vc presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e) {}
    });
}

#pragma mark - 创建标签栏

static UIView *createTagBar(NSArray *tabNames, CGFloat width) {
    CGFloat h = 44;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, h)];
    bar.backgroundColor = [UIColor whiteColor];
    
    UIFont *font = [UIFont systemFontOfSize:14];
    CGFloat x = 15;
    NSMutableArray *btns = [NSMutableArray array];
    
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 24;
        BOOL isSelected = (i == 0);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = font;
        btn.frame = CGRectMake(x, (h - 28) / 2, w, 28);
        
        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        btn.layer.cornerRadius = 14;
        btn.layer.masksToBounds = YES;
        btn.tag = 100 + i;
        
        [bar addSubview:btn];
        [btns addObject:btn];
        x += w + 10;
    }
    
    objc_setAssociatedObject(bar, "tabButtons", btns, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return bar;
}

#pragma mark - Hook

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSMutableString *debug = [NSMutableString string];
        
        UIView *rootView = ((UIViewController *)self).view;
        [debug appendFormat:@"视图层级:\n"];
        
        // 找 TableView
        UITableView *tv = nil;
        for (UIView *sub in rootView.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tv = (UITableView *)sub;
                break;
            }
        }
        
        if (!tv) {
            [debug appendString:@"❌ 没找到 TableView"];
            showDebug(debug);
            return;
        }
        
        [debug appendFormat:@"✅ 找到 TableView: %@\n\n", NSStringFromClass([tv class])];
        
        // 检查是否已有标签栏
        UIView *existingBar = [tv viewWithTag:202424];
        if (existingBar) {
            [debug appendString:@"已有标签栏，跳过"];
            showDebug(debug);
            return;
        }
        
        // 找搜索栏（TableView 的 headerView 或第一个子视图）
        UIView *searchBar = nil;
        CGFloat searchBarBottom = 0;
        
        // 先看 tableHeaderView
        UIView *thv = tv.tableHeaderView;
        if (thv) {
            [debug appendFormat:@"tableHeaderView: %@ frame=%@\n", 
             NSStringFromClass([thv class]), NSStringFromCGRect(thv.frame)];
            searchBar = thv;
            searchBarBottom = thv.frame.origin.y + thv.frame.size.height;
        }
        
        // 看 TableView 的前几个 subviews
        [debug appendFormat:@"TableView subviews:\n"];
        for (NSInteger i = 0; i < tv.subviews.count && i < 6; i++) {
            UIView *sub = tv.subviews[i];
            [debug appendFormat:@"%ld. %@ frame=%@ tag=%ld\n", 
             (long)i, NSStringFromClass([sub class]), 
             NSStringFromCGRect(sub.frame), (long)sub.tag];
        }
        
        // 找搜索栏位置
        for (UIView *sub in tv.subviews) {
            CGRect f = sub.frame;
            if (f.origin.y < 60 && f.size.height > 30 && f.size.height < 80 && f.size.width > 300) {
                searchBar = sub;
                searchBarBottom = f.origin.y + f.size.height;
                [debug appendFormat:@"\n找到搜索栏?: %@ frame=%@\n", 
                 NSStringFromClass([sub class]), NSStringFromCGRect(f)];
                break;
            }
        }
        
        // 获取标签
        NSArray *tags = getAllTagNames();
        [debug appendFormat:@"\n找到标签 (%lu):\n", (unsigned long)tags.count];
        for (NSString *t in tags) {
            [debug appendFormat:@"- %@\n", t];
        }
        
        // 创建标签栏
        NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
        [tabNames addObjectsFromArray:tags];
        
        UIView *tabBar = createTagBar(tabNames, tv.frame.size.width);
        tabBar.tag = 202424;
        
        // 把标签栏插入到搜索栏下方
        if (searchBar) {
            // 把标签栏加到 TableView，然后调整到搜索栏下方
            CGFloat yPos = searchBarBottom;
            tabBar.frame = CGRectMake(0, yPos, tv.frame.size.width, 44);
            [tv addSubview:tabBar];
            [tv bringSubviewToFront:tabBar];
            
            [debug appendFormat:@"\n✅ 标签栏已添加，位置 y=%.0f\n", yPos];
        } else {
            // 没有搜索栏，加到 TableView 顶部
            tabBar.frame = CGRectMake(0, 0, tv.frame.size.width, 44);
            [tv addSubview:tabBar];
            [tv bringSubviewToFront:tabBar];
            
            [debug appendFormat:@"\n✅ 标签栏已添加（无搜索栏），位置 y=0\n"];
        }
        
        showDebug(debug);
        NSLog(@"[WeChatTagGroup] v24: %@", debug);
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v24功能版已加载");
}