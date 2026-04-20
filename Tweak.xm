/**
 * WeChat Tag Group Tweak
 * 功能：将微信标签好友以分组形式显示在聊天列表顶部
 * 适配：iOS 15+ / 微信 8.0.x
 * 使用：设置标签"置顶好友"，把好友加入该标签，重启微信
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ========== 配置区 ==========
static NSString *const kTargetTagName = @"置顶好友";
static BOOL kEnableFeature = YES;
static BOOL kShowUnreadBadge = YES;
// ==============================

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

@interface NewMainFrameViewController : UIViewController
@property (nonatomic, strong) UITableView *m_tableView;
- (void)reloadSessionData;
// 声明新增的方法
- (void)reloadTagGroupData;
- (NSInteger)calculateUnreadCount;
- (void)openChatSessionWithUsrName:(NSString *)usrName;
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
    if (kEnableFeature) {
        [self reloadTagGroupData];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger originalSections = %orig;
    if (kEnableFeature && _tagGroupSessions.count > 0) {
        return originalSections + 1;
    }
    return originalSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (kEnableFeature && section == 0 && _tagGroupSessions.count > 0) {
        return _isTagGroupExpanded ? _tagGroupSessions.count : 0;
    }
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? section - 1 : section;
    return %orig(tableView, adjustedSection);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (kEnableFeature && section == 0 && _tagGroupSessions.count > 0) {
        WCTagGroupHeaderView *header = [[WCTagGroupHeaderView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 60)];
        header.tagName = kTargetTagName;
        header.onlineCount = _tagGroupSessions.count;
        header.unreadCount = [self calculateUnreadCount];
        header.isExpanded = _isTagGroupExpanded;
        header.onToggle = ^{
            _isTagGroupExpanded = !_isTagGroupExpanded;
            [tableView reloadData];
        };
        return header;
    }
    return %orig(tableView, section);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (kEnableFeature && indexPath.section == 0 && _tagGroupSessions.count > 0) {
        static NSString *cellId = @"WCTagGroupSessionCell";
        WCTagGroupSessionCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[WCTagGroupSessionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        }
        if (indexPath.row < _tagGroupSessions.count) {
            cell.sessionInfo = _tagGroupSessions[indexPath.row];
        }
        return cell;
    }
    return %orig(tableView, indexPath);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (kEnableFeature && indexPath.section == 0 && _tagGroupSessions.count > 0) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (indexPath.row < _tagGroupSessions.count) {
            MMSessionInfo *session = _tagGroupSessions[indexPath.row];
            [self openChatSessionWithUsrName:session.m_nsUsrName];
        }
        return;
    }
    %orig(tableView, indexPath);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (kEnableFeature && section == 0 && _tagGroupSessions.count > 0) {
        return 60;
    }
    return %orig(tableView, section);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (kEnableFeature && indexPath.section == 0 && _tagGroupSessions.count > 0) {
        return 70;
    }
    return %orig(tableView, indexPath);
}

%new
- (void)reloadTagGroupData {
    _tagGroupSessions = [NSMutableArray array];
    WCLabelMgr *labelMgr = [%c(WCLabelMgr) sharedInstance];
    NSArray *contacts = [labelMgr getContactListByLabelName:kTargetTagName];
    if (!contacts || contacts.count == 0) {
        return;
    }
    MMSessionMgr *sessionMgr = [%c(MMSessionMgr) defaultMgr];
    for (WCContactData *contact in contacts) {
        MMSessionInfo *session = [sessionMgr getSessionInfoByUsrName:contact.m_nsUsrName];
        if (session) {
            [_tagGroupSessions addObject:session];
        }
    }
    [_tagGroupSessions sortUsingComparator:^NSComparisonResult(MMSessionInfo *s1, MMSessionInfo *s2) {
        return [@(s2.m_nCreateTime) compare:@(s1.m_nCreateTime)];
    }];
}

%new
- (NSInteger)calculateUnreadCount {
    NSInteger total = 0;
    for (MMSessionInfo *session in _tagGroupSessions) {
        total += session.m_nUnReadCount;
    }
    return total;
}

%new
- (void)openChatSessionWithUsrName:(NSString *)usrName {
    // 打开聊天页面
    Class msgControllerClass = NSClassFromString(@"MessageViewController");
    if (msgControllerClass) {
        UIViewController *msgVC = [[msgControllerClass alloc] init];
        if ([msgVC respondsToSelector:@selector(setValue:forKey:)]) {
            [msgVC setValue:usrName forKey:@"m_nsUsrName"];
        }
        [self.navigationController pushViewController:msgVC animated:YES];
    }
}

%end

%hook MMSessionMgr
- (void)onNewSession:(id)session {
    %orig;
}
%end

%ctor {
    NSLog(@"[WeChatTagGroup] Tweak loaded! Target tag: %@", kTargetTagName);
}