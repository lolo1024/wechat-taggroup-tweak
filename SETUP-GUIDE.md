# WeChatTagGroup 使用指南

## 第一步：创建 GitHub 仓库

1. 打开 https://github.com/new
2. 仓库名填：`wechat-taggroup-tweak`
3. 选择 **Private**（私有）或 Public
4. **不要**勾选 "Add a README file"
5. 点击 **Create repository**

## 第二步：上传代码

### 方法 A：使用 GitHub Desktop（推荐新手）

1. 下载安装 GitHub Desktop：https://desktop.github.com/
2. 打开 GitHub Desktop，登录你的账号
3. File → Add Local Repository
4. 选择文件夹：`C:\Users\86131\.qclaw\workspace\wechat-taggroup-tweak`
5. 点击 "Create a new repository for this project"
6. Publish repository

### 方法 B：使用命令行

打开 PowerShell，执行：

```powershell
cd C:\Users\86131\.qclaw\workspace\wechat-taggroup-tweak

git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/wechat-taggroup-tweak.git
git push -u origin main
```

## 第三步：等待自动编译

1. 代码推送后，GitHub Actions 会自动开始编译
2. 点击仓库页面的 **Actions** 标签查看进度
3. 编译通常需要 3-5 分钟

## 第四步：下载 .deb 文件

编译成功后，有两种方式下载：

### 方式 A：从 Releases 下载
1. 点击仓库右侧的 **Releases**
2. 下载最新的 `.deb` 文件

### 方式 B：从 Artifacts 下载
1. 点击 Actions → 对应的 workflow run
2. 在页面底部 **Artifacts** 区域下载

## 第五步：安装到巨魔

1. 将 `.deb` 文件传到 iPhone（隔空投送/iCloud/微信等）
2. 打开巨魔安装器
3. 选择 `.deb` 文件安装
4. 重启微信

## 第六步：配置标签

1. 打开微信
2. 通讯录 → 标签 → 新建标签
3. 标签名称填：**置顶好友**（或修改代码中的 `kTargetTagName`）
4. 添加需要置顶的好友
5. 返回聊天列表，即可看到分组

## 如何修改标签名？

如果你想用其他标签名（比如"VIP客户"）：

1. 编辑 `Tweak.xm` 文件
2. 找到这行：`static NSString *const kTargetTagName = @"置顶好友";`
3. 改成你想要的标签名
4. Git 提交后，Actions 会自动重新编译

## 需要帮助？

如果遇到问题，告诉我：
1. 具体的错误信息
2. 你的微信版本号
3. iOS 版本

我会帮你调整代码。
