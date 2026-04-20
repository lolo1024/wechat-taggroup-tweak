/**
 * WeChat Tag Group - 功能版 v16
 * 在聊天列表顶部显示"客户"标签联系人
 * 点击可快速发起聊天
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 标签名称（可修改）
static NSString *kTargetTagName = @"客户";

#pragma mark - 安全调用方法

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
    } @catch (NSException *e) {
        return nil;
    }
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
    } @catch (NSException *e) {
        return nil;
    }
}

#pragma mark - 获取联系人数据

// 获取联系人信息的结构体
@interface TagContact : NSObject
@property (nonatomic, strong) NSString *wxid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *remark;
@end

@implementation TagContact
@end

// 获取指定标签的联系人列表
static NSArray<TagContact *> *getContactsForTag(NSString *tagName) {
    NSMutableArray<TagContact *> *result = [NSMutableArray array];
    
    @try {
        // 获取服务
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        Class contactMgrClass = NSClassFromString(@"CContactMgr");
        Class tagMgrClass = NSClassFromString(@"ContactTagMgr");
        
        if (!serviceCenterClass || !contactMgrClass || !tagMgrClass) {
            NSLog(@"[WeChatTagGroup] 类不存在");
            return result;
        }
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id serviceCenter = [serviceCenterClass performSelector:@selector(defaultCenter)];
        if (!serviceCenter) return result;
        
        id contactMgr = [serviceCenter performSelector:@selector(getService:) withObject:contactMgrClass];
        id tagMgr = [serviceCenter performSelector:@selector(getService:) withObject:tagMgrClass];
        if (!tagMgr) {
            tagMgr = [[tagMgrClass alloc] init];
        }
        #pragma clang diagnostic pop
        
        if (!contactMgr || !tagMgr) return result;
        
        // 获取该标签的所有联系人wxid
        SEL getContactsSel = NSSelectorFromString(@"getContactsForTagName:");
        if (![tagMgr respondsToSelector:getContactsSel]) return result;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSArray *wxidArray = [tagMgr performSelector:getContactsSel withObject:tagName];
        #pragma clang diagnostic pop
        
        if (!wxidArray || ![wxidArray isKindOfClass:[NSArray class]]) return result;
        
        // 获取每个联系人的详情
        SEL getContactSel = NSSelectorFromString(@"getContactByName:");
        
        for (NSString *wxid in wxidArray) {
            if (![wxid isKindOfClass:[NSString class]]) continue;
            
            TagContact *contact = [[TagContact alloc] init];
            contact.wxid = wxid;
            
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id contactObj = [contactMgr performSelector:getContactSel withObject:wxid];
            #pragma clang diagnostic pop
            
            if (contactObj) {
                // 获取昵称
                for (NSString *method in @[@"getNickName", @"nickName", @"m_nsNickName"]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id val = [contactObj performSelector:NSSelectorFromString(method)];
                    #pragma clang diagnostic pop
                    if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                        contact.nickName = val;
                        break;
                    }
                }
                
                // 获取备注
                for (NSString *method in @[@"getRemark", @"m_nsRemark", @"remark"]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id val = [contactObj performSelector:NSSelectorFromString(method)];
                    #pragma clang diagnostic pop
                    if (val && [val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0) {
                        contact.remark = val;
                        break;
                    }
                }
            }
            
            // 如果没有备注，用昵称代替
            if (!contact.remark || [contact.remark length] == 0) {
                contact.remark = contact.nickName;
            }
            
            [result addObject:contact];
        }
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] getContactsForTag error: %@", e);
    }
    
    return result;
}

#pragma mark - 打开聊天

// 打开与指定联系人的聊天
static void openChatWithContact(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return;
    
    @try {
        // 获取 CMessageMgr
        Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
        if (!serviceCenterClass) return;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id serviceCenter = [serviceCenterClass performSelector:@selector(defaultCenter)];
        #pragma clang diagnostic pop
        
        if (!serviceCenter) return;
        
        Class msgMgrClass = NSClassFromString(@"CMessageMgr");
        if (!msgMgrClass) return;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id msgMgr = [serviceCenter performSelector:@selector(getService:) withObject:msgMgrClass];
        #pragma clang diagnostic pop
        
        if (!msgMgr) return;
        
        // 尝试调用 openChatViewControllerWithUsername: 方法
        SEL openChatSel = NSSelectorFromString(@"openChatViewControllerWithUsername:");
        if ([msgMgr respondsToSelector:openChatSel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [msgMgr performSelector:openChatSel withObject:wxid];
            #pragma clang diagnostic pop
            NSLog(@"[WeChatTagGroup] 打开聊天: %@", wxid);
        }
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] openChatWithContact error: %@", e);
    }
}

#pragma mark - 创建标签分组视图

// 创建联系人头像+名字的视图
static UIView *createContactCell(TagContact *contact, CGFloat width) {
    UIView *cellView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 80)];
    
    // 头像
    UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake((width - 50) / 2, 5, 50, 50)];
    avatarView.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0]; // 微信绿
    avatarView.layer.cornerRadius = 25;
    avatarView.layer.masksToBounds = YES;
    avatarView.contentMode = UIViewContentModeCenter;
    
    // 头像文字（取昵称首字）
    NSString *firstChar = @"?";
    if (contact.nickName && [contact.nickName length] > 0) {
        unichar c = [contact.nickName characterAtIndex:0];
        firstChar = [NSString stringWithCharacters:&c length:1];
    }
    
    UILabel *avatarLabel = [[UILabel alloc] initWithFrame:avatarView.bounds];
    avatarLabel.text = [firstChar uppercaseString];
    avatarLabel.textColor = [UIColor whiteColor];
    avatarLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    avatarLabel.textAlignment = NSTextAlignmentCenter;
    [avatarView addSubview:avatarLabel];
    
    [cellView addSubview:avatarView];
    
    // 名字标签（只显示备注的前6个字）
    NSString *displayName = contact.remark;
    if (!displayName || [displayName length] == 0) {
        displayName = contact.nickName;
    }
    if (!displayName || [displayName length] == 0) {
        displayName = contact.wxid;
    }
    
    if ([displayName length] > 6) {
        displayName = [[displayName substringToIndex:6] stringByAppendingString:@"…"];
    }
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 58, width, 20)];
    nameLabel.text = displayName;
    nameLabel.textColor = [UIColor darkGrayColor];
    nameLabel.font = [UIFont systemFontOfSize:11];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    [cellView addSubview:nameLabel];
    
    // 点击手势
    cellView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:NULL];
    [cellView addGestureRecognizer:tap];
    
    // 关联数据
    objc_setAssociatedObject(tap, "contact", contact, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return cellView;
}

// 创建标签分组视图
static UIView *createTagGroupView(NSArray<TagContact *> *contacts, UIView *parentView) {
    if (!contacts || contacts.count == 0) return nil;
    
    // 主容器（白色背景，有阴影）
    CGFloat cellWidth = 70;
    CGFloat cellSpacing = 10;
    CGFloat padding = 15;
    CGFloat scrollHeight = 90;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.layer.shadowOpacity = 0.1;
    container.layer.shadowRadius = 3;
    
    // 标签头
    UILabel *headerLabel = [[UILabel alloc] init];
    headerLabel.text = [NSString stringWithFormat:@"📋 %@ (%lu)", kTargetTagName, (unsigned long)contacts.count];
    headerLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    headerLabel.textColor = [UIColor darkGrayColor];
    [headerLabel sizeToFit];
    headerLabel.frame = CGRectMake(padding, 10, headerLabel.frame.size.width, 20);
    [container addSubview:headerLabel];
    
    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [closeBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    closeBtn.frame = CGRectMake(parentView.frame.size.width - 35, 8, 25, 25);
    [closeBtn addTarget:nil action:@selector(hideTagGroupView) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:closeBtn];
    
    // 水平滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.frame = CGRectMake(0, 35, parentView.frame.size.width, scrollHeight);
    [container addSubview:scrollView];
    
    // 添加联系人单元格
    CGFloat x = padding;
    for (NSInteger i = 0; i < contacts.count; i++) {
        TagContact *contact = contacts[i];
        UIView *cell = createContactCell(contact, cellWidth);
        cell.frame = CGRectMake(x, 5, cellWidth, 80);
        
        // 点击手势
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:@selector(tagContactTapped:)];
        [cell addGestureRecognizer:tap];
        objc_setAssociatedObject(tap, "wxid", contact.wxid, OBJC_ASSOCIATION_COPY_NONATOMIC);
        
        [scrollView addSubview:cell];
        x += cellWidth + cellSpacing;
    }
    
    scrollView.contentSize = CGSizeMake(x, scrollHeight);
    
    // 设置容器大小
    container.frame = CGRectMake(0, 0, parentView.frame.size.width, 35 + scrollHeight + 10);
    
    return container;
}

#pragma mark - 注入到聊天列表

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self injectTagGroupView];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    
    // 每次显示时刷新标签视图
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self refreshTagGroupView];
    });
}

%new
- (void)injectTagGroupView {
    @try {
        // 检查是否已经添加过
        UIView *existingView = [self.view viewWithTag:20240421];
        if (existingView) return;
        
        // 获取标签联系人
        NSArray<TagContact *> *contacts = getContactsForTag(kTargetTagName);
        if (!contacts || contacts.count == 0) {
            NSLog(@"[WeChatTagGroup] 没有找到联系人");
            return;
        }
        
        // 创建标签分组视图
        UIView *tagView = createTagGroupView(contacts, self.view);
        if (!tagView) return;
        
        // 设置tag以便后续找到
        tagView.tag = 20240421;
        
        // 添加到视图顶部
        tagView.frame = CGRectMake(0, 0, self.view.frame.size.width, tagView.frame.size.height);
        [self.view addSubview:tagView];
        
        // 将tableView往下移动
        [self adjustTableViewForTagView:tagView];
        
        NSLog(@"[WeChatTagGroup] 已添加标签视图，共 %lu 人", (unsigned long)contacts.count);
        
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] injectTagGroupView error: %@", e);
    }
}

%new
- (void)refreshTagGroupView {
    @try {
        UIView *existingView = [self.view viewWithTag:20240421];
        if (!existingView) {
            // 没有就重新添加
            [self injectTagGroupView];
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] refreshTagGroupView error: %@", e);
    }
}

%new
- (void)adjustTableViewForTagView:(UIView *)tagView {
    @try {
        // 查找 UITableView
        for (UIView *subview in self.view.subviews) {
            if ([subview isKindOfClass:[UITableView class]]) {
                CGRect frame = subview.frame;
                CGFloat tagHeight = tagView.frame.size.height;
                
                // 判断是否有导航栏偏移
                if (frame.origin.y < 100) {
                    // 正常情况，tableView从顶部开始
                    frame.origin.y = tagHeight;
                } else {
                    // 有其他偏移，叠加
                    frame.origin.y += tagHeight;
                }
                frame.size.height -= tagHeight;
                subview.frame = frame;
                
                NSLog(@"[WeChatTagGroup] 已调整 TableView");
                break;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] adjustTableViewForTagView error: %@", e);
    }
}

%end

#pragma mark - 全局点击处理

// 让 view controller 响应标签点击
%hook NewMainFrameViewController

%new
- (void)tagContactTapped:(UITapGestureRecognizer *)tap {
    @try {
        NSString *wxid = objc_getAssociatedObject(tap, "wxid");
        if (wxid && [wxid length] > 0) {
            NSLog(@"[WeChatTagGroup] 点击了联系人: %@", wxid);
            openChatWithContact(wxid);
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] tagContactTapped error: %@", e);
    }
}

%new
- (void)hideTagGroupView {
    @try {
        UIView *tagView = [self.view viewWithTag:20240421];
        if (tagView) {
            // 恢复 tableView
            for (UIView *subview in self.view.subviews) {
                if ([subview isKindOfClass:[UITableView class]]) {
                    CGRect frame = subview.frame;
                    frame.origin.y = 0;
                    frame.size.height += frame.origin.y;
                    subview.frame = frame;
                    break;
                }
            }
            [tagView removeFromSuperview];
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] hideTagGroupView error: %@", e);
    }
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v16功能版已加载 - 标签: %@", kTargetTagName);
}