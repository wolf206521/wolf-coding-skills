<#
.SYNOPSIS
  将本能力仓库初始化并发布到 GitHub。

.DESCRIPTION
  依次执行（每步都有前置检查，失败即停）：
    1. 若未初始化 git，则 git init
    2. git add -A
    3. git commit（Conventional Commits 风格，可跳过空提交）
    4. 确保分支名为 main
    5. 若不存在 origin 则 git remote add origin <RepoUrl>
    6. git push -u origin main
  凭据：不写死任何密码/Token。优先使用环境变量 GH_TOKEN（会注入临时凭据），
        否则依赖本机已配置的 git 凭据（credential helper / SSH key）。

.PARAMETER RepoUrl
  目标仓库地址，如 https://github.com/you/wolf-coding-skills.git

.PARAMETER CommitMessage
  提交信息（默认 'feat: initialize wolf-coding-skills capability repository'）

.PARAMETER DryRun
  只打印将要执行的命令，不真正执行。

.EXAMPLE
  .\scripts\publish-github.ps1 -RepoUrl https://github.com/you/wolf-coding-skills.git
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoUrl,
    [string]$CommitMessage = 'feat: initialize wolf-coding-skills capability repository',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Invoke-Step {
    param([string]$Display, [scriptblock]$Script)
    Write-Host "» $Display" -ForegroundColor Cyan
    if ($DryRun) { Write-Host "  [dry-run] 跳过执行"; return }
    & $Script
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "步骤失败（exit $LASTEXITCODE）：$Display"
    }
}

# 0. 前置检查
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "未检测到 git，请先安装并加入 PATH。"
}

# 1. 初始化
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
    Invoke-Step 'git init' { git init -b main }
} else {
    Write-Host "» 已存在 .git，跳过 init" -ForegroundColor DarkGray
}

# 2/3. 提交
Invoke-Step 'git add -A' { git add -A }
$hasChanges = git status --porcelain
if ($hasChanges) {
    Invoke-Step "git commit" { git commit -m $CommitMessage }
} else {
    Write-Host "» 无变更，跳过 commit" -ForegroundColor DarkGray
}

# 4. 分支名
$curBranch = git rev-parse --abbrev-ref HEAD
if ($curBranch -ne 'main') {
    Invoke-Step "git branch -M main" { git branch -M main }
}

# 5. remote
$existing = git remote get-url origin 2>$null
if ($existing) {
    Write-Host "» origin 已存在：$existing" -ForegroundColor DarkGray
} else {
    Invoke-Step "git remote add origin $RepoUrl" { git remote add origin $RepoUrl }
}

# 6. push（凭据处理：GH_TOKEN 优先，否则用本机凭据）
if ($env:GH_TOKEN) {
    Write-Host "» 使用 GH_TOKEN 环境变量注入临时凭据（不落盘）" -ForegroundColor DarkGray
    $pushUrl = $RepoUrl -replace '^https://', "https://x-access-token:$env:GH_TOKEN@"
    Invoke-Step 'git push（GH_TOKEN）' { git push -u $pushUrl main } 
} else {
    Invoke-Step 'git push -u origin main' { git push -u origin main }
}

Write-Host "`n✔ 发布完成。若为公开仓库，请到 GitHub 仓库 Settings 确认默认分支为 main，并启用 Actions。" -ForegroundColor Green
