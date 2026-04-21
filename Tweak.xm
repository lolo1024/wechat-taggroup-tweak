/**
 * WeChat Tag Group - v23 调试版
 * 检查 hook 是否触发 + 标签栏位置
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
        
        // getDicOfUserNameAndTagNames
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
                if (nameSet.count > 0) return [nameSet allObjects];
            }
        }
    } @catch (NSException *e) {}
    return @[];
}

static void showDebug(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (vc.presentedViewController) vc = vc.presentedViewController;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"v23 Debug"
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [vc presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e) {}
    });
}

#pragma mark - 创建标签栏

static UIView *createTagBar(NSArray *tabNames, CGFloat width) {
    CGFloat h = 50;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, h)];
    bar.backgroundColor = [UIColor whiteColor];
    
    // 顶部红线
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 1)];
    line.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
    [bar addSubview:line];
    
    UIFont *font = [UIFont systemFontOfSize:14];
    CGFloat x = 15;
    
    for (NSInteger i = 0; i < tabNames.count; i++) {
        NSString *name = tabNames[i];
        CGSize size = [name sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat w = size.width + 24;
        BOOL isSelected = (i == 0);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = font;
        btn.frame = CGRectMake(x, (h - 30) / 2, w, 30);
        
        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0];
            [btn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        }
        btn.layer.cornerRadius = 15;
        btn.layer.masksToBounds = YES;
        
        [bar addSubview:btn];
        x += w + 10;
    }
    
    return bar;
}

#pragma mark - Hook

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    NSLog(@"[WeChatTagGroup] v23 viewDidLoad 触发!");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSMutableString *debug = [NSMutableString string];
        [debug appendString:@"=== v23 Debug ===\n\n"];
        
        UIView *rootView = ((UIViewController *)self).view;
        [debug appendFormat:@"rootView: %@\n", NSStringFromClass([rootView class])];
        [debug appendFormat:@"rootView.frame: %@\n\n", NSStringFromCGRect(rootView.frame)];
        
        // 列出所有 subviews
        [debug appendFormat:@"rootView subviews (%lu):\n", (unsigned long)rootView.subviews.count];
        for (NSInteger i = 0; i < rootView.subviews.count; i++) {
            UIView *sub = rootView.subviews[i];
            [debug appendFormat:@"%ld. %@ frame=%@ tag=%ld\n", 
             (long)i, NSStringFromClass([sub class]), 
             NSStringFromCGRect(sub.frame), (long)sub.tag];
        }
        
        // 查找 UITableView
        UITableView *tv = nil;
        for (UIView *sub in rootView.subviews) {
            if ([sub isKindOfClass:[UITableView class]]) {
                tv = (UITableView *)sub;
                break;
            }
            // 也检查类名
            NSString *className = NSStringFromClass([sub class]);
            if ([className containsString:@"Table"] || [className containsString:@"Session"]) {
                [debug appendFormat:@"\n找到可能Table: %@\n", className];
                if (!tv) tv = (UITableView *)sub;
            }
        }
        
        if (tv) {
            [debug appendFormat:@"\n找到TableView: %@ frame=%@\n", 
             NSStringFromClass([tv class]), NSStringFromCGRect(tv.frame)];
            [debug appendFormat:@"TableView subviews: %lu\n", (unsigned long)tv.subviews.count];
        } else {
            [debug appendString:@"\n没找到 UITableView!\n"];
        }
        
        // 获取标签
        NSArray *tags = getAllTagNames();
        [debug appendFormat:@"\n标签列表 (%lu):\n", (unsigned long)tags.count];
        for (NSString *t in tags) {
            [debug appendFormat:@"- %@\n", t];
        }
        
        // 如果找到TableView，添加标签栏
        if (tv) {
            NSMutableArray *tabNames = [NSMutableArray arrayWithObject:@"全部"];
            [tabNames addObjectsFromArray:tags];
            
            UIView *tabBar = createTagBar(tabNames, tv.frame.size.width);
            tabBar.tag = 202423;
            
            // 加到 TableView 的最上层
            [tv addSubview:tabBar];
            
            // 移到最上层
            [tv bringSubviewToFront:tabBar];
            
            // 调整 TableView frame 往下移
            CGRect frame = tv.frame;
            frame.origin.y += 50;
            frame.size.height -= 50;
            tv.frame = frame;
            
            [debug appendFormat:@"\n✅ 已添加标签栏到 TableView\n"];
            [debug appendFormat:@"tabBar.frame: %@\n", NSStringFromCGRect(tabBar.frame)];
            [debug appendFormat:@"TableView 调整后 frame: %@\n", NSStringFromCGRect(tv.frame)];
        }
        
        showDebug(debug);
        NSLog(@"[WeChatTagGroup] %@", debug);
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v23调试版已加载");
}