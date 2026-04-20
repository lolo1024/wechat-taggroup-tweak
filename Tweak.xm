/**
 * WeChat Tag Group Tweak
 * 功能：将微信标签好友以分组形式显示在聊天列表顶部
 * 
 * 适配微信版本：8.0.x (iOS 15+)
 * 
 * 免责声明：本插件仅供学习研究使用，请勿用于商业用途
 * 使用本插件产生的一切后果由使用者自行承担
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ========== 配置区 ==========
static NSString *const kTargetTagName = @"置顶好友";  // 目标标签名称，可在设置中修改
static BOOL kEnableFeature = YES;                     // 是否启用功能
static BOOL kShowUnreadBadge = YES;                   // 是否显示未读角标
// ==============================

// ========== 微信类声明（通过 class-dump 获取）==========
// 聊天会话模型
@interface MMSessionInfo : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;      // 对方微信号/wxid
@property (nonatomic, copy) NSString *m_nsNickName;     // 昵称
@property (nonatomic, copy) NSString *m_nsContent;      // 最后一条消息内容
@property (nonatomic, assign) long long m_nUnReadCount; // 未读消息数
@property (nonatomic, assign) long long m_nStatus;      // 状态
@property (nonatomic, assign) long long m_nCreateTime;  // 创建时间
@property (nonatomic, assign) long long m_nChatType;    // 聊天类型
@property (nonatomic, strong) UIImage *m_image;         // 头像
@end

// 联系人模型
@interface WCContactData : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, copy) NSString *m_nsRemark;
@property (nonatomic, strong) NSArray *m_labelArr;      // 标签数组
@end

// 会话管理器
@interface MMSessionMgr : NSObject
+ (instancetype)defaultMgr;
- (NSArray *)m_arrSession;                              // 所有会话数组
- (MMSessionInfo *)getSessionInfoByUsrName:(NSString *)usrName;
- (void)sortSessionList;
@end

// 联系人管理器
@interface WCContactLogic : NSObject
+ (instancetype)defaultLogic;
- (WCContactData *)getContactWithUsrName:(NSString *)usrName;
- (NSArray *)getAllContacts;
@end

// 标签管理器
@interface WCLabelMgr : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)getContactListByLabelName:(NSString *)labelName;
- (NSArray *)getAllLabels;
@end

// 聊天列表视图控制器
@interface BaseMsgContentViewController : UIViewController
@end

@interface NewMainFrameViewController : UIViewController
@property (nonatomic, strong) UITableView *m_tableView;
@property (nonatomic, strong) NSArray *m_arrSession;
- (void)reloadSessionData;
@end

// 聊天列表Cell
@interface MMTableViewCell : UITableViewCell
@property (nonatomic, strong) MMSessionInfo *sessionInfo;
@end

// ========== 自定义分组视图 ==========
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
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // 箭头图标
    UIImageView *arrow = [[UIImageView alloc] init];
    arrow.tag = 100;
    arrow.image = [UIImage systemImageNamed:@"chevron.right"];
    arrow.tintColor = [UIColor grayColor];
    [self addSubview:arrow];
    [arrow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(15);
        make.centerY.equalTo(self);
        make.size.mas_equalTo(CGSizeMake(20, 20));
    }];
    
    // 标签名
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.tag = 101;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textColor = [UIColor blackColor];
    [self addSubview:titleLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(arrow.mas_right).offset(10);
        make.top.equalTo(self).offset(8);
    }];
    
    // 统计信息
    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.tag = 102;
    countLabel.font = [UIFont systemFontOfSize:12];
    countLabel.textColor = [UIColor grayColor];
    [self addSubview:countLabel];
    [countLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleLabel);
        make.top.equalTo(titleLabel.mas_bottom).offset(2);
    }];
    
    // 未读角标
    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.tag = 103;
    badgeLabel.font = [UIFont boldSystemFontOfSize:12];
    badgeLabel.textColor = [UIColor whiteColor];
    badgeLabel.backgroundColor = [UIColor redColor];
    badgeLabel.layer.cornerRadius = 10;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.hidden = YES;
    [self addSubview:badgeLabel];
    [badgeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self).offset(-15);
        make.centerY.equalTo(self);
        make.size.mas_equalTo(CGSizeMake(20, 20));
    }];
    
    // 点击手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self addGestureRecognizer:tap];
}

- (void)handleTap {
    if (self.onToggle) {
        self.onToggle();
    }
}

- (void)updateUI {
    UILabel *titleLabel = [self viewWithTag:101];
    UILabel *countLabel = [self viewWithTag:102];
    UIImageView *arrow = [self viewWithTag:100];
    UILabel *badge = [self viewWithTag:103];
    
    titleLabel.text = self.tagName ?: @"标签分组";
    countLabel.text = [NSString stringWithFormat:@"%ld人在线", (long)self.onlineCount];
    
    // 旋转箭头
    [UIView animateWithDuration:0.25 animations:^{
        arrow.transform = self.isExpanded ? CGAffineTransformMakeRotation(M_PI_2) : CGAffineTransformIdentity;
    }];
    
    // 未读角标
    if (kShowUnreadBadge && self.unreadCount > 0) {
        badge.hidden = NO;
        badge.text = self.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)self.unreadCount];
    } else {
        badge.hidden = YES;
    }
}

@end

// ========== 自定义分组Cell ==========
@interface WCTagGroupSessionCell : UITableViewCell
@property (nonatomic, strong) MMSessionInfo *sessionInfo;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@end

@implementation WCTagGroupSessionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // 头像
    _avatarView = [[UIImageView alloc] init];
    _avatarView.layer.cornerRadius = 25;
    _avatarView.layer.masksToBounds = YES;
    _avatarView.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:_avatarView];
    [_avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(15);
        make.centerY.equalTo(self.contentView);
        make.size.mas_equalTo(CGSizeMake(50, 50));
    }];
    
    // 昵称
    _nameLabel = [[UILabel alloc] init];
    _nameLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.contentView addSubview:_nameLabel];
    [_nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(_avatarView.mas_right).offset(12);
        make.top.equalTo(self.contentView).offset(10);
    }];
    
    // 时间
    _timeLabel = [[UILabel alloc] init];
    _timeLabel.font = [UIFont systemFontOfSize:12];
    _timeLabel.textColor = [UIColor grayColor];
    [self.contentView addSubview:_timeLabel];
    [_timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-15);
        make.centerY.equalTo(_nameLabel);
    }];
    
    // 消息预览
    _contentLabel = [[UILabel alloc] init];
    _contentLabel.font = [UIFont systemFontOfSize:14];
    _contentLabel.textColor = [UIColor grayColor];
    _contentLabel.numberOfLines = 1;
    [self.contentView addSubview:_contentLabel];
    [_contentLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(_nameLabel);
        make.top.equalTo(_nameLabel.mas_bottom).offset(5);
        make.right.equalTo(self.contentView).offset(-80);
    }];
    
    // 未读角标
    _badgeLabel = [[UILabel alloc] init];
    _badgeLabel.font = [UIFont boldSystemFontOfSize:12];
    _badgeLabel.textColor = [UIColor whiteColor];
    _badgeLabel.backgroundColor = [UIColor redColor];
    _badgeLabel.layer.cornerRadius = 10;
    _badgeLabel.layer.masksToBounds = YES;
    _badgeLabel.textAlignment = NSTextAlignmentCenter;
    _badgeLabel.hidden = YES;
    [self.contentView addSubview:_badgeLabel];
    [_badgeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-15);
        make.top.equalTo(_timeLabel.mas_bottom).offset(8);
        make.size.mas_equalTo(CGSizeMake(20, 20));
    }];
}

- (void)setSessionInfo:(MMSessionInfo *)sessionInfo {
    _sessionInfo = sessionInfo;
    
    _nameLabel.text = sessionInfo.m_nsNickName ?: sessionInfo.m_nsUsrName;
    _contentLabel.text = sessionInfo.m_nsContent ?: @"";
    
    // 时间格式化
    if (sessionInfo.m_nCreateTime > 0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:sessionInfo.m_nCreateTime];
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        NSDate *today = [NSDate date];
        if ([[fmt stringFromDate:today] isEqualToString:[fmt stringFromDate:date]]) {
            fmt.dateFormat = @"HH:mm";
        } else {
            fmt.dateFormat = @"MM-dd";
        }
        _timeLabel.text = [fmt stringFromDate:date];
    }
    
    // 未读数
    if (sessionInfo.m_nUnReadCount > 0) {
        _badgeLabel.hidden = NO;
        _badgeLabel.text = sessionInfo.m_nUnReadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%lld", sessionInfo.m_nUnReadCount];
    } else {
        _badgeLabel.hidden = YES;
    }
    
    // 头像（如果本地有缓存）
    if (sessionInfo.m_image) {
        _avatarView.image = sessionInfo.m_image;
    }
}

@end

// ========== Tweak 实现 ==========
static NSMutableArray *_tagGroupSessions = nil;
static BOOL _isTagGroupExpanded = NO;

// Hook 聊天列表控制器
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
        return originalSections + 1;  // 增加一个分组
    }
    
    return originalSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 如果是第一个section且分组展开
    if (kEnableFeature && section == 0 && _tagGroupSessions.count > 0) {
        return _isTagGroupExpanded ? _tagGroupSessions.count : 0;
    }
    
    // 其他section调用原方法
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? section - 1 : section;
    return %orig(tableView, adjustedSection);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    // 第一个section显示分组头部
    if (kEnableFeature && section == 0 && _tagGroupSessions.count > 0) {
        WCTagGroupHeaderView *header = [[WCTagGroupHeaderView alloc] initWithFrame:CGRectMake(0, 0, tableView.width, 60)];
        header.tagName = kTargetTagName;
        header.onlineCount = _tagGroupSessions.count;
        header.unreadCount = [self calculateUnreadCount];
        header.isExpanded = _isTagGroupExpanded;
        
        __weak typeof(self) weakSelf = self;
        header.onToggle = ^{
            _isTagGroupExpanded = !_isTagGroupExpanded;
            [tableView reloadData];
        };
        
        [header updateUI];
        return header;
    }
    
    // 其他section调用原方法
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? section - 1 : section;
    return %orig(tableView, adjustedSection);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 第一个section显示分组内的会话
    if (kEnableFeature && indexPath.section == 0 && _tagGroupSessions.count > 0) {
        static NSString *cellId = @"WCTagGroupSessionCell";
        WCTagGroupSessionCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        if (!cell) {
            cell = [[WCTagGroupSessionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        }
        
        if (indexPath.row < _tagGroupSessions.count) {
            MMSessionInfo *session = _tagGroupSessions[indexPath.row];
            cell.sessionInfo = session;
        }
        
        return cell;
    }
    
    // 其他section调用原方法
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? indexPath.section - 1 : indexPath.section;
    NSIndexPath *adjustedPath = [NSIndexPath indexPathForRow:indexPath.row inSection:adjustedSection];
    return %orig(tableView, adjustedPath);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 第一个section点击处理
    if (kEnableFeature && indexPath.section == 0 && _tagGroupSessions.count > 0) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        if (indexPath.row < _tagGroupSessions.count) {
            MMSessionInfo *session = _tagGroupSessions[indexPath.row];
            // 打开对应的聊天界面
            [self openChatSessionWithUsrName:session.m_nsUsrName];
        }
        return;
    }
    
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? indexPath.section - 1 : indexPath.section;
    NSIndexPath *adjustedPath = [NSIndexPath indexPathForRow:indexPath.row inSection:adjustedSection];
    %orig(tableView, adjustedPath);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (kEnableFeature && section == 0 && _tagGroupSessions.count > 0) {
        return 60;
    }
    
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? section - 1 : section;
    return %orig(tableView, adjustedSection);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (kEnableFeature && indexPath.section == 0 && _tagGroupSessions.count > 0) {
        return 70;
    }
    
    NSInteger adjustedSection = _tagGroupSessions.count > 0 ? indexPath.section - 1 : indexPath.section;
    NSIndexPath *adjustedPath = [NSIndexPath indexPathForRow:indexPath.row inSection:adjustedSection];
    return %orig(tableView, adjustedPath);
}

%new
- (void)reloadTagGroupData {
    _tagGroupSessions = [NSMutableArray array];
    
    // 获取标签下的联系人
    WCLabelMgr *labelMgr = [%c(WCLabelMgr) sharedInstance];
    NSArray *contacts = [labelMgr getContactListByLabelName:kTargetTagName];
    
    if (!contacts || contacts.count == 0) {
        HBLogDebug(@"[WeChatTagGroup] 未找到标签: %@", kTargetTagName);
        return;
    }
    
    // 获取这些联系人的会话信息
    MMSessionMgr *sessionMgr = [%c(MMSessionMgr) defaultMgr];
    
    for (WCContactData *contact in contacts) {
        MMSessionInfo *session = [sessionMgr getSessionInfoByUsrName:contact.m_nsUsrName];
        if (session) {
            [_tagGroupSessions addObject:session];
        }
    }
    
    // 按最近消息时间排序
    [_tagGroupSessions sortUsingComparator:^NSComparisonResult(MMSessionInfo *s1, MMSessionInfo *s2) {
        return [@(s2.m_nCreateTime) compare:@(s1.m_nCreateTime)];
    }];
    
    HBLogDebug(@"[WeChatTagGroup] 加载了 %ld 个会话", (long)_tagGroupSessions.count);
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
    // 通过微信内部方法打开聊天界面
    Class msgVCClass = %c(BaseMsgContentViewController);
    BaseMsgContentViewController *msgVC = [[msgVCClass alloc] init];
    
    // 设置聊天对象
    if ([msgVC respondsToSelector:@selector(setM_nsUsrName:)]) {
        [msgVC setValue:usrName forKey:@"m_nsUsrName"];
    }
    
    [self.navigationController pushViewController:msgVC animated:YES];
}

%end

// ========== 监听消息更新，刷新分组数据 ==========
%hook MMSessionMgr

- (void)onNewSession:(id)session {
    %orig;
    
    if (kEnableFeature) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NewMainFrameViewController *mainVC = [self getCurrentMainViewController];
            if (mainVC && [mainVC respondsToSelector:@selector(reloadTagGroupData)]) {
                [mainVC reloadTagGroupData];
                [mainVC.m_tableView reloadData];
            }
        });
    }
}

%new
- (NewMainFrameViewController *)getCurrentMainViewController {
    UIWindow *keyWindow = nil;
    
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    if (!keyWindow) return nil;
    
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        UIViewController *topVC = [(UINavigationController *)rootVC topViewController];
        if ([topVC isKindOfClass:%c(NewMainFrameViewController)]) {
            return (NewMainFrameViewController *)topVC;
        }
    }
    
    if ([rootVC isKindOfClass:%c(NewMainFrameViewController)]) {
        return (NewMainFrameViewController *)rootVC;
    }
    
    return nil;
}

%end

// ========== 构造函数 ==========
%ctor {
    HBLogDebug(@"[WeChatTagGroup] Tweak loaded!");
    HBLogDebug(@"[WeChatTagGroup] Target tag: %@", kTargetTagName);
}
