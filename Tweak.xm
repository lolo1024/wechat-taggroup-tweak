/**
 * WeChat Tag Group Tweak
 * 功能：将微信标签好友以分组形式显示在聊天列表顶部
 * 
 * 适配微信版本：8.0.x (iOS 15+)
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
 [self setupUI];
 }
 return self;
}

- (void)setupUI {
 UIImageView *arrow = [[UIImageView alloc] initWithFrame:CGRectMake(15, 20, 20, 20)];
 arrow.image = [UIImage systemImageNamed:@"chevron.right"];
 arrow.tintColor = [UIColor grayColor];
 arrow.tag = 100;
 [self addSubview:arrow];
 
 UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 8, 200, 22)];
 titleLabel.font = [UIFont boldSystemFontOfSize:16];
 titleLabel.tag = 101;
 [self addSubview:titleLabel];
 
 UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 32, 150, 18)];
 countLabel.font = [UIFont systemFontOfSize:12];
 countLabel.textColor = [UIColor grayColor];
 countLabel.tag = 102;
 [self addSubview:countLabel];
 
 UILabel *badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.bounds.size.width - 35, 20, 20, 20)];
 badgeLabel.font = [UIFont boldSystemFontOfSize:12];
 badgeLabel.textColor = [UIColor whiteColor];
 badgeLabel.backgroundColor = [UIColor redColor];
 badgeLabel.layer.cornerRadius = 10;
 badgeLabel.layer.masksToBounds = YES;
 badgeLabel.textAlignment = NSTextAlignmentCenter;
 badgeLabel.hidden = YES;
 badgeLabel.tag = 103;
 [self addSubview:badgeLabel];
 
 UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
 [self addGestureRecognizer:tap];
}

- (void)handleTap {
 if (self.onToggle) {
 self.onToggle();
 }
}

- (void)layoutSubviews {
 [super layoutSubviews];
 [self updateUI];
}

- (void)updateUI {
 UIImageView *arrow = [self viewWithTag:100];
 UILabel *titleLabel = [self viewWithTag:101];
 UILabel *countLabel = [self viewWithTag:102];
 UILabel *badge = [self viewWithTag:103];
 
 titleLabel.text = self.tagName ?: @"标签分组";
 countLabel.text = [NSString stringWithFormat:@"%ld人", (long)self.onlineCount];
 
 [UIView animateWithDuration:0.25 animations:^{
 arrow.transform = self.isExpanded ? CGAffineTransformMakeRotation(M_PI_2) : CGAffineTransformIdentity;
 }];
 
 badge.frame = CGRectMake(self.bounds.size.width - 35, 20, 20, 20);
 
 if (kShowUnreadBadge && self.unreadCount > 0) {
 badge.hidden = NO;
 badge.text = self.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)self.unreadCount];
 } else {
 badge.hidden = YES;
 }
}

@end

@interface WCTagGroupSessionCell : UITableViewCell
@property (nonatomic, strong) MMSessionInfo *sessionInfo;
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
 UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(15, 10, 50, 50)];
 avatar.layer.cornerRadius = 25;
 avatar.layer.masksToBounds = YES;
 avatar.backgroundColor = [UIColor lightGrayColor];
 avatar.tag = 200;
 [self.contentView addSubview:avatar];
 
 UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(77, 10, 180, 22)];
 nameLabel.font = [UIFont boldSystemFontOfSize:16];
 nameLabel.tag = 201;
 [self.contentView addSubview:nameLabel];
 
 UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.contentView.bounds.size.width - 80, 12, 65, 18)];
 timeLabel.font = [UIFont systemFontOfSize:12];
 timeLabel.textColor = [UIColor grayColor];
 timeLabel.textAlignment = NSTextAlignmentRight;
 timeLabel.tag = 202;
 [self.contentView addSubview:timeLabel];
 
 UILabel *contentLabel = [[UILabel alloc] initWithFrame:CGRectMake(77, 35, 200, 20)];
 contentLabel.font = [UIFont systemFontOfSize:14];
 contentLabel.textColor = [UIColor grayColor];
 contentLabel.tag = 203;
 [self.contentView addSubview:contentLabel];
 
 UILabel *badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.contentView.bounds.size.width - 35, 38, 20, 20)];
 badgeLabel.font = [UIFont boldSystemFontOfSize:12];
 badgeLabel.textColor = [UIColor whiteColor];
 badgeLabel.backgroundColor = [UIColor redColor];
 badgeLabel.layer.cornerRadius = 10;
 badgeLabel.layer.masksToBounds = YES;
 badgeLabel.textAlignment = NSTextAlignmentCenter;
 badgeLabel.hidden = YES;
 badgeLabel.tag = 204;
 [self.contentView addSubview:badgeLabel];
}

- (void)layoutSubviews {
 [super layoutSubviews];
 
 UIView *timeLabel = [self.contentView viewWithTag:202];
 UIView *badgeLabel = [self.contentView viewWithTag:204];
 
 timeLabel.frame = CGRectMake(self.contentView.bounds.size.width - 80, 12, 65, 18);
 badgeLabel.frame = CGRectMake(self.contentView.bounds.size.width - 35, 38, 20, 20);
}

- (void)setSessionInfo:(MMSessionInfo *)sessionInfo {
 UILabel *nameLabel = [self.contentView viewWithTag:201];
 UILabel *contentLabel = [self.contentView viewWithTag:203];
 UILabel *timeLabel = [self.contentView viewWithTag:202];
 UILabel *badgeLabel = [self.contentView viewWithTag:204];
 UIImageView *avatar = [self.contentView viewWithTag:200];
 
 nameLabel.text = sessionInfo.m_nsNickName ?: sessionInfo.m_nsUsrName;
 contentLabel.text = sessionInfo.m_nsContent ?: @"";
 
 if (sessionInfo.m_nCreateTime > 0) {
 NSDate *date = [NSDate dateWithTimeIntervalSince1970:sessionInfo.m_nCreateTime];
 NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
 fmt.dateFormat = @"HH:mm";
 timeLabel.text = [fmt stringFromDate:date];
 }
 
 if (sessionInfo.m_nUnReadCount > 0) {
 badgeLabel.hidden = NO;
 badgeLabel.text = sessionInfo.m_nUnReadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%lld", sessionInfo.m_nUnReadCount];
 } else {
 badgeLabel.hidden = YES;
 }
 
 if (sessionInfo.m_image) {
 avatar.image = sessionInfo.m_image;
 }
}

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
 
 __weak typeof(self) weakSelf = self;
 header.onToggle = ^{
 _isTagGroupExpanded = !_isTagGroupExpanded;
 [tableView reloadData];
 };
 return header;
 }
 NSInteger adjustedSection = _tagGroupSessions.count > 0 ? section - 1 : section;
 return %orig(tableView, adjustedSection);
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
 NSInteger adjustedSection = _tagGroupSessions.count > 0 ? indexPath.section - 1 : indexPath.section;
 NSIndexPath *adjustedPath = [NSIndexPath indexPathForRow:indexPath.row inSection:adjustedSection];
 return %orig(tableView, adjustedPath);
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
 NSInteger adjustedSection = _tagGroupSessions.count > 0 ? indexPath.section - 1 : indexPath.section;
 NSIndexPath *adjustedPath = [NSIndexPath indexPathForRow:indexPath.row inSection:adjustedSection];
 %orig(tableView, adjustedPath);
}

- (CGFloat)tableView:(UITableView *)tabl
...(truncated)...
