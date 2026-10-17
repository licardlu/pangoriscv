# 添加远端并推送 main 到 GitHub / Gitee（本机无 gh CLI，仓库需先在网页建好）
param(
    [Parameter(Mandatory = $true)]
    [string]$RemoteUrl,
    [string]$RemoteName = 'origin',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

if (-not (Test-Path (Join-Path $root '.git'))) { throw "未找到 .git：$root 不是 git 仓库" }
if ($RemoteUrl -notmatch '^(https://|git@)') { throw "RemoteUrl 应形如 https://github.com/<user>/pangoriscv.git" }

$dirty = git status --porcelain
if ($dirty) {
    Write-Host "工作区存在未提交改动：" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" }
    throw "先提交或 stash 这些改动，再运行本脚本"
}

$existing = git remote
if ($existing -contains $RemoteName) {
    git remote set-url $RemoteName $RemoteUrl
    Write-Host "已更新远端 $RemoteName -> $RemoteUrl"
} else {
    git remote add $RemoteName $RemoteUrl
    Write-Host "已添加远端 $RemoteName -> $RemoteUrl"
}

Write-Host "`n待推送分支：$Branch"
git log --oneline -3

Write-Host "`n推送中（首次会弹出 GitHub 登录窗口）..." -ForegroundColor Cyan
git push -u $RemoteName $Branch
if ($LASTEXITCODE -ne 0) { throw "推送失败（退出码 $LASTEXITCODE），见上方 git 输出" }

Write-Host "`n完成。远端：" -ForegroundColor Green
git remote -v
Write-Host "`n下一步：网页 Settings -> Collaborators -> Add people 邀请同学。" -ForegroundColor Green
