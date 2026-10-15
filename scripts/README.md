# scripts 目录

本目录存放能力仓库自身使用的脚本。

| 脚本 | 用途 | 用法 |
| --- | --- | --- |
| `install.ps1` | Windows：安装/卸载技能到 DSH / Claude Code 用户目录 | `.\install.ps1 [-Uninstall] [-Backup] [-Target <dir>]` |
| `install.sh` | Linux/macOS：等价安装脚本 | `./install.sh [--uninstall] [--target <dir>]` |
| `publish-github.ps1` | 初始化并推送本仓库到 GitHub | `.\publish-github.ps1 -RepoUrl <url> [-DryRun]` |
| `validate-skills.mjs` | 校验技能 frontmatter、目录名、文档死链 | `node validate-skills.mjs` |

> 说明：`publish-github.ps1` 不写死任何凭据；优先读环境变量 `GH_TOKEN`，否则依赖本机 git 凭据（credential helper 或 SSH key）。
