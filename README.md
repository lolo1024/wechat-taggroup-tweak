# 微信标签分组插件 (WeChatTagGroup)

将微信标签好友以分组形式显示在聊天列表顶部。

## 功能特性

- ✅ 将指定标签的好友以折叠卡片形式显示在聊天列表最顶部
- ✅ 点击展开/折叠分组
- ✅ 显示未读消息角标（汇总）
- ✅ 按最近消息时间排序
- ✅ 点击直接进入聊天界面

## 环境要求

- iOS 15.0+
- 巨魔 / 越狱环境
- 微信 8.0.x

## 安装方法

### 方法一：使用 GitHub Actions 自动编译（推荐）

1. 将此项目 Fork 到你自己的 GitHub 账号
2. 进入 Actions 页面，运行 workflow
3. 编译完成后，在 Releases 或 Artifacts 中下载 `.deb` 文件
4. 使用巨魔安装器安装

### 方法二：本地编译（需要 Mac）

```bash
# 1. 安装 Theos
brew install ldid
git clone --recursive https://github.com/theos/theos.git ~/theos

# 2. 设置环境变量
export THEOS=~/theos

# 3. 编译
cd wechat-taggroup-tweak
make package
```

编译完成后，`.deb` 文件在 `packages/` 目录下。

## 配置说明

打开 `Tweak.xm`，修改以下配置项：

```objc
static NSString *const kTargetTagName = @"置顶好友";  // 目标标签名称
static BOOL kEnableFeature = YES;                     // 是否启用功能
static BOOL kShowUnreadBadge = YES;                   // 是否显示未读角标
```

**使用步骤：**
1. 在微信中创建一个标签（如"置顶好友"）
2. 将需要置顶的好友添加到该标签
3. 安装插件后重启微信

## 免责声明

本插件仅供学习研究使用，请勿用于商业用途。
使用本插件产生的一切后果由使用者自行承担。
本插件不收集任何用户数据。

## 常见问题

### Q: 安装后不生效？
A: 
1. 确认微信版本是否兼容（目前支持 8.0.x）
2. 确认标签名称是否正确
3. 尝试完全退出微信后重新打开

### Q: 编译失败？
A: 
1. 确认 Theos 安装正确
2. 运行 `git submodule update --init --recursive` 更新 Theos 子模块
3. 检查是否有编译错误信息

### Q: 如何查看日志？
A: 使用 Console.app 或设备日志查看 `[WeChatTagGroup]` 开头的日志

## License

MIT License
