# 第三方技能来源与许可证（Vendor Attribution）

本目录除自研 `wolf-*` 技能外，集成了以下**真实、成熟**的第三方技能仓库内容（逐字原文抓取，非改写）。
来源、许可证与抓取信息如下，供合规与溯源使用。

> 抓取方式：通过 GitHub raw 内容接口逐文件抓取，未做改写。
> 二进制与大文件（字体/图片/超长脚本）按需跳过，跳过项见各技能的 `NOTICE.md`（如有）。

| 技能目录 | 上游仓库 | 许可证 | 抓取内容 |
| --- | --- | --- | --- |
| `skill-creator` | [anthropics/skills](https://github.com/anthropics/skills) `skills/skill-creator` | 见该目录 LICENSE | SKILL.md + reference/scripts |
| `frontend-design` | [anthropics/skills](https://github.com/anthropics/skills) `skills/frontend-design` | 见该目录 LICENSE | SKILL.md |
| `webapp-testing` | [anthropics/skills](https://github.com/anthropics/skills) `skills/webapp-testing` | 见该目录 LICENSE | SKILL.md + scripts/examples |
| `mcp-builder` | [anthropics/skills](https://github.com/anthropics/skills) `skills/mcp-builder` | 见该目录 LICENSE | SKILL.md + reference/scripts |
| `brainstorming` 等 12 个 | [obra/superpowers](https://github.com/obra/superpowers) `skills/*` | MIT（见仓库 LICENSE） | SKILL.md + reference |
| `security-code-review` | [Artais-Security/claude-skills-security-code-review](https://github.com/Artais-Security/claude-skills-security-code-review) | MIT | SKILL.md + references/* |
| `karpathy-guidelines` | [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)（原 forrestchang） | 见仓库 | SKILL.md + CLAUDE.md/CURSOR.md/EXAMPLES.md |

## 与自研 wolf-* 技能的关系

| 能力域 | 自研（编排层） | 上游（原版能力） |
| --- | --- | --- |
| 立项/计划 | `wolf-project-kickoff` | `brainstorming`、`writing-plans` |
| 子 Agent 开发 | `wolf-monorepo-scaffold` | `subagent-driven-development`、`dispatching-parallel-agents`、`executing-plans` |
| TDD | `wolf-tdd-loop` | `test-driven-development` |
| 调试 | （无） | `systematic-debugging` |
| 测试 | `wolf-test-automation` | `webapp-testing` |
| 安全 | `wolf-security-review` | `security-code-review`（更全，建议优先） |
| 元技能 | `wolf-meta-skill-creator` | `skill-creator`、`writing-skills` |
| 前端 | （无） | `frontend-design` |
| 交付校验 | （无） | `verification-before-completion` |
| 行为准则 | （内嵌） | `karpathy-guidelines` |

**用法建议**：日常任务直接让上游技能生效；`wolf-*` 作为“把上游能力串成大型项目全流程”的编排层与领域落地（印刷 ERP）适配层。

## 集成完整度（已 100% 补齐文本文件）

本次集成**逐字原文**抓取了 4 个上游仓库在 scope 内技能的**全部文本文件**（SKILL.md + reference + scripts + examples + LICENSE + prompt 模板 + HTML/JS/dot 等），共 **162 个文件**：

- **obra/superpowers**：12 个技能的全部子文件（含 `subagent-driven-development` 的 3 个 prompt 模板 + 3 个 scripts、`brainstorming` 的 2 个 prompt + 5 个 scripts、`systematic-debugging` 的 10 个参考/测试文件、`writing-skills` 的 6 个子文件、`using-superpowers` 的 7 个 references、`executing-plans` 的 2 个 scripts、`test-driven-development` 的 writing-good-tests.md 等）。
- **anthropics/skills**：4 个技能的全部子文件（含 `skill-creator` 的 17 个子文件——agents/references/scripts/eval-viewer/assets、`mcp-builder` 的 4 个 reference + 4 个 scripts、`webapp-testing` 的 3 个 examples + with_server.py、以及各技能 LICENSE.txt）。
- **Artais-Security**：SKILL.md + README + LICENSE + 36 个 references（全量）。
- **multica-ai**：karpathy-guidelines 全量 6 文件。

**未集成（有意排除）**：上游仓库中与本项目无关的其他技能目录（如 anthropics 的 canvas-design/pptx/xlsx/pdf 等含字体/图片资产、superpowers 的 diagnosing-superpowers 等元技能）不在本次集成范围；其二进制资产（.ttf/.png）本就不属于"文本能力"。

抓取方式：`raw.githubusercontent.com` 本机直连不可达，全程经 `ghproxy.net`/`ghfast.top` 镜像 + `api.github.com` 交叉核对，逐字写入，未翻译/改写。

## 合规注意

- 上游内容版权归原作者所有，遵循其各自许可证（多为 MIT / Anthropic 条款）。
- 重新分发前请核对各技能目录内的 `LICENSE`/`LICENSE.txt` 文件。
- anthropics/skills 的整体第三方声明见上游 `THIRD_PARTY_NOTICES.md`（未随附，需时自行下载）。
- **一处有意改动**：`security-code-review` 的 frontmatter `name` 由上游 `security-review` 改为 `security-code-review`，以与本仓库目录名一致（避免与通用"安全审查"概念混淆）；其余内容逐字未改。
