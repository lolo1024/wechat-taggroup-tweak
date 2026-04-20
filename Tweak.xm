/**
 * WeChat Tag Group - 功能版 v18
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

@interface TagContact : NSObject
@property (nonatomic, strong) NSString *wxid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *remark;
@end

@implementation TagContact
@end

static NSArray<TagContact *> *getContactsForTag(NSString *tagName) {
    NSMutableArray<TagContact *> *result = [NSMutableArray array];
    
    @try {
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
        
        SEL getContactsSel = NSSelectorFromString(@"getContactsForTagName:");
        if (![tagMgr respondsToSelector:getContactsSel]) return result;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSArray *wxidArray = [tagMgr performSelector:getContactsSel withObject:tagName];
        #pragma clang diagnostic pop
        
        if (!wxidArray || ![wxidArray isKindOfClass:[NSArray class]]) return result;
        
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

static void openChatWithContact(NSString *wxid) {
    if (!wxid || [wxid length] == 0) return;
    
    @try {
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

static UIView *createContactCell(TagContact *contact, CGFloat width) {
    UIView *cellView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 80)];
    
    // 头像
    UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake((width - 50) / 2, 5, 50, 50)];
    avatarView.backgroundColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.33 alpha:1.0];
    avatarView.layer.cornerRadius = 25;
    avatarView.layer.masksToBounds = YES;
    avatarView.contentMode = UIViewContentModeCenter;
    
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
    
    return cellView;
}

static UIView *createTagGroupView(NSArray<TagContact *> *contacts, CGFloat viewWidth) {
    if (!contacts || contacts.count == 0) return nil;
    
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
    
    // 水平滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.frame = CGRectMake(0, 35, viewWidth, scrollHeight);
    [container addSubview:scrollView];
    
    // 添加联系人单元格
    CGFloat x = padding;
    for (NSInteger i = 0; i < contacts.count; i++) {
        TagContact *contact = contacts[i];
        UIView *cell = createContactCell(contact, cellWidth);
        cell.frame = CGRectMake(x, 5, cellWidth, 80);
        cell.accessibilityIdentifier = contact.wxid;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(handleTap:)];
        [cell addGestureRecognizer:tap];
        
        [scrollView addSubview:cell];
        x += cellWidth + cellSpacing;
    }
    
    scrollView.contentSize = CGSizeMake(x, scrollHeight);
    
    container.frame = CGRectMake(0, 0, viewWidth, 35 + scrollHeight + 10);
    
    return container;
}

#pragma mark - Cell点击处理

@interface UIView (TagGroupTap)
- (void)handleTap:(UITapGestureRecognizer *)tap;
@end

@implementation UIView (TagGroupTap)

- (void)handleTap:(UITapGestureRecognizer *)tap {
    @try {
        NSString *wxid = self.accessibilityIdentifier;
        if (wxid && [wxid length] > 0) {
            NSLog(@"[WeChatTagGroup] 点击了联系人: %@", wxid);
            openChatWithContact(wxid);
        }
    } @catch (NSException *e) {
        NSLog(@"[WeChatTagGroup] handleTap error: %@", e);
    }
}

@end

#pragma mark - Hook NewMainFrameViewController

// 前向声明
@class NewMainFrameViewController;

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // 使用 id 类型避免前向声明问题
        id _self = self;
        UIView *myView = _self.view;
        if (!myView) return;
        
        // 检查是否已经添加过
        UIView *existingView = [myView viewWithTag:20240421];
        if (existingView) return;
        
        // 获取标签联系人
        NSArray<TagContact *> *contacts = getContactsForTag(kTargetTagName);
        if (!contacts || contacts.count == 0) {
            NSLog(@"[WeChatTagGroup] 没有找到联系人");
            return;
        }
        
        // 创建标签分组视图
        UIView *tagView = createTagGroupView(contacts, myView.frame.size.width);
        if (!tagView) return;
        
        tagView.tag = 20240421;
        [myView addSubview:tagView];
        
        // 调整 tableView 位置
        for (UIView *subview in myView.subviews) {
            if ([subview isKindOfClass:[UITableView class]]) {
                CGRect frame = subview.frame;
                CGFloat tagHeight = tagView.frame.size.height;
                if (frame.origin.y < 100) {
                    frame.origin.y = tagHeight;
                } else {
                    frame.origin.y += tagHeight;
                }
                frame.size.height -= tagHeight;
                subview.frame = frame;
                break;
            }
        }
        
        NSLog(@"[WeChatTagGroup] 已添加标签视图，共 %lu 人", (unsigned long)contacts.count);
    });
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        id _self = self;
        UIView *myView = _self.view;
        if (!myView) return;
        
        UIView *existingView = [myView viewWithTag:20240421];
        if (!existingView) {
            // 重新添加
            NSArray<TagContact *> *contacts = getContactsForTag(kTargetTagName);
            if (contacts && contacts.count > 0) {
                UIView *tagView = createTagGroupView(contacts, myView.frame.size.width);
                if (tagView) {
                    tagView.tag = 20240421;
                    [myView addSubview:tagView];
                    
                    for (UIView *subview in myView.subviews) {
                        if ([subview isKindOfClass:[UITableView class]]) {
                            CGRect frame = subview.frame;
                            frame.origin.y = tagView.frame.size.height;
                            frame.size.height -= tagView.frame.size.height;
                            subview.frame = frame;
                            break;
                        }
                    }
                }
            }
        }
    });
}

%end

%ctor {
    NSLog(@"[WeChatTagGroup] v18功能版已加载 - 标签: %@", kTargetTagName);
}