<#
.SYNOPSIS
  安装本能力仓库的 Skills 到 DSH / Claude Code 的用户技能目录。

.DESCRIPTION
  将 scripts 上级目录的 skills\* 复制（默认）到：
    - $HOME\.dsh\skills\        (DeepSeek Harness)
    - $HOME\.claude\skills\     (Claude Code)
  幂等：已存在的同名目录会被覆盖（用 -Backup 保留旧副本）。
  不影响其它已安装技能。

.PARAMETER Uninstall
  从上述两个目录删除本仓库安装过的技能。

.PARAMETER Target
  覆盖安装目标目录（默认 $HOME\.dsh\skills）。可多次指定。

.PARAMETER Backup
  覆盖前将旧目录重命名为 <name>.bak-<timestamp>。

.EXAMPLE
  .\scripts\install.ps1
  .\scripts\install.ps1 -Uninstall
  .\scripts\install.ps1 -Target "$HOME\.trae\skills" -Backup
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Uninstall,
    [string[]]$Target,
    [switch]$Backup
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SkillsSrc = Join-Path $RepoRoot 'skills'

if (-not (Test-Path $SkillsSrc)) {
    throw "未找到技能源目录：$SkillsSrc"
}

# 默认目标：DSH 与 Claude Code
$Targets = @()
if ($Target.Count -eq 0) {
    $Targets += Join-Path $HOME '.dsh\skills'
    $Targets += Join-Path $HOME '.claude\skills'
} else {
    foreach ($t in $Target) { $Targets += $t }
}

$skillDirs = Get-ChildItem -Path $SkillsSrc -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }

if ($skillDirs.Count -eq 0) {
    Write-Warning "skills 目录下未找到任何含 SKILL.md 的技能。"
    exit 0
}

foreach ($dest in $Targets) {
    Write-Host "== 目标：$dest" -ForegroundColor Cyan
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }

    foreach ($skill in $skillDirs) {
        $name = $skill.Name
        $dstPath = Join-Path $dest $name

        if ($Uninstall) {
            if (Test-Path $dstPath) {
                if ($PSCmdlet.ShouldProcess($dstPath, '删除已安装技能')) {
                    Remove-Item -Recurse -Force $dstPath
                    Write-Host "  - 卸载 $name" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  - $name 未安装，跳过"
            }
            continue
        }

        # 备份旧版本
        if ($Backup -and (Test-Path $dstPath)) {
            $bak = "$dstPath.bak-" + (Get-Date -Format 'yyyyMMddHHmmss')
            Rename-Item -Path $dstPath -NewName (Split-Path $bak -Leaf)
            Write-Host "  - 备份旧版本 -> $bak"
        }

        if ($PSCmdlet.ShouldProcess($dstPath, "安装技能 $name")) {
            if (Test-Path $dstPath) { Remove-Item -Recurse -Force $dstPath }
            Copy-Item -Recurse -Force $skill.FullName $dstPath
            Write-Host "  + 安装 $name" -ForegroundColor Green
        }
    }
}

if ($Uninstall) {
    Write-Host "`n卸载完成。" -ForegroundColor Green
} else {
    Write-Host "`n安装完成。重新开启 Agent 会话后，描述任务即可自动触发对应技能。" -ForegroundColor Green
}
