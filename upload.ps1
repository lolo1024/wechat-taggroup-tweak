# 一键上传到 GitHub 脚本
# 使用方法：在 PowerShell 中运行 .\upload.ps1

$repoPath = "C:\Users\86131\.qclaw\workspace\wechat-taggroup-tweak"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  微信标签分组插件 - GitHub 上传工具" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Git 是否安装
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "[错误] 未检测到 Git，请先安装 Git" -ForegroundColor Red
    Write-Host "下载地址: https://git-scm.com/download/win" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[信息] Git 版本: $(git --version)" -ForegroundColor Green

# 进入项目目录
Set-Location $repoPath

# 检查是否已初始化 Git
if (-not (Test-Path ".git")) {
    Write-Host "[步骤] 初始化 Git 仓库..." -ForegroundColor Yellow
    git init
    git branch -M main
}

# 询问 GitHub 用户名
Write-Host ""
$githubUser = Read-Host "请输入你的 GitHub 用户名"

if ([string]::IsNullOrWhiteSpace($githubUser)) {
    Write-Host "[错误] 用户名不能为空" -ForegroundColor Red
    pause
    exit 1
}

# 设置远程仓库
$remoteUrl = "https://github.com/$githubUser/wechat-taggroup-tweak.git"

Write-Host ""
Write-Host "[步骤] 检查远程仓库..." -ForegroundColor Yellow

# 检查远程仓库是否已存在
$existingRemote = git remote -v 2>$null
if ($existingRemote -match "origin") {
    Write-Host "[信息] 更新远程仓库地址..." -ForegroundColor Yellow
    git remote set-url origin $remoteUrl
} else {
    Write-Host "[信息] 添加远程仓库..." -ForegroundColor Yellow
    git remote add origin $remoteUrl
}

Write-Host "[信息] 远程仓库: $remoteUrl" -ForegroundColor Green

# 添加所有文件
Write-Host ""
Write-Host "[步骤] 添加文件到暂存区..." -ForegroundColor Yellow
git add .

# 检查是否有改动
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "[信息] 没有需要提交的改动" -ForegroundColor Yellow
} else {
    # 提交
    Write-Host "[步骤] 提交更改..." -ForegroundColor Yellow
    git commit -m "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

# 推送
Write-Host ""
Write-Host "[步骤] 推送到 GitHub..." -ForegroundColor Yellow
Write-Host "[提示] 可能需要输入 GitHub 用户名和密码/Token" -ForegroundColor Cyan

try {
    git push -u origin main
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "  ✓ 推送成功！" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "接下来：" -ForegroundColor Cyan
    Write-Host "1. 打开浏览器访问: https://github.com/$githubUser/wechat-taggroup-tweak" -ForegroundColor White
    Write-Host "2. 点击 'Actions' 标签查看编译进度" -ForegroundColor White
    Write-Host "3. 编译完成后在 'Releases' 下载 .deb 文件" -ForegroundColor White
    Write-Host ""
    
    # 尝试打开浏览器
    Start-Process "https://github.com/$githubUser/wechat-taggroup-tweak/actions"
    
} catch {
    Write-Host ""
    Write-Host "[错误] 推送失败" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "常见问题：" -ForegroundColor Yellow
    Write-Host "1. 如果提示需要登录，请使用 GitHub Personal Access Token" -ForegroundColor White
    Write-Host "   创建 Token: https://github.com/settings/tokens" -ForegroundColor White
    Write-Host "2. 如果仓库不存在，请先在 GitHub 创建仓库" -ForegroundColor White
    Write-Host "   创建地址: https://github.com/new" -ForegroundColor White
}

Write-Host ""
pause
