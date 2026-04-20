/**
 * WeChat Tag Group Tweak
 * 功能：将微信标签好友以分组形式显示在聊天列表顶部
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kTargetTagName = @"置顶好友";
static BOOL kEnableFeature = YES;
static BOOL kShowUnreadBadge = YES;

@interface MMSessionInfo : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, copy) NSString *m_nsContent;
@property (nonatomic, assign) long long m_nUnReadCount;
@property (nonatomic, assign) long long m_nStatus;
@property (nonatomic, assign) long long m_nCreateTime;
@property (nonatomic, assign) long long m_nChatType;
@property (nonatomic, strong) UIImage *m_image;
@end

@interface WCContactData : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, copy) NSString *m_nsRemark;
@property (nonatomic, strong) NSArray *m_labelArr;
@end

@interface MMSessionMgr : NSObject
+ (instancetype)defaultMgr;
- (NSArray *)m_arrSession;
- (MMSessionInfo *)getSessionInfoByUsrName:(NSString *)usrName;
@end

@interface WCLabelMgr : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)getContactListByLabelName:(NSString *)labelName;
@end

@interface BaseMsgContentViewController : UIViewController
@end

@interface NewMainFrameViewController : UIViewController
@property (nonatomic, strong) UITableView *m_tableView;
- (void)reloadSessionData;
@end

@interface WCTagGroupHeaderView : UIView
@property (nonatomic, copy) NSString *tagName;
@property (nonatomic, assign) NSInteger onlineCount;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, copy) void (^onToggle)(void);
@end

@implementation WCTagGroupHeaderView
- (instancetype)initWithFrame:(CGRect)frame {
 self = [super initWithFrame:frame];
 if (self) {
 self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
 }
 return self;
}
@end

@interface WCTagGroupSessionCell : UITableViewCell
@property (nonatomic, strong) MMSessionInfo *sessionInfo;
@end

@implementation WCTagGroupSessionCell
@end

static NSMutableArray *_tagGroupSessions = nil;
static BOOL _isTagGroupExpanded = NO;

%hook NewMainFrameViewController
- (void)viewDidLoad {
 %orig;
}
%end

%hook MMSessionMgr
- (void)onNewSession:(id)session {
 %orig;
}
%end

%ctor {
 NSLog(@"[WeChatTagGroup] Tweak loaded!");
}
