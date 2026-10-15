# Skills 索引

本目录共 **自研 13 个 + 上游 vendor 18 个 = 31 个技能**。每个目录含 `SKILL.md`（frontmatter `name`/`description` 由 Agent 用于自动挂载）。

- **自研 `wolf-*`（13）**：**编排层/领域层**——印刷 ERP 领域落地 + 把上游串成大型项目全流程 + 补上游没有的工程环节（架构/脚手架/契约/CI-CD/可观测/迭代/发布）。
- **上游 vendor（18）**：**执行层**——真实成熟社区技能，逐字原文集成。来源与许可证见 [`VENDORS.md`](VENDORS.md)。

> 整合规则（两层模型、生命周期映射、委托/废弃清单）见 [`../docs/12-能力整合方案.md`](../docs/12-能力整合方案.md)。
> 格式与写作规范见 [`../docs/_conventions.md`](../docs/_conventions.md) 第 6 节；总纲见 [`../docs/00-master-plan.md`](../docs/00-master-plan.md)。
> 全局行为准则与技能路由见根 [`../CLAUDE.md`](../CLAUDE.md)。

## 生命周期图谱

```
wolf-project-kickoff ─► wolf-architecture-blueprint ─► wolf-domain-modeling
        │                                                        │
        │                                                        ▼
        │                                            wolf-monorepo-scaffold
        │                                                        │
        │                                                        ▼
        │                                              wolf-api-contract
        │                                                        │
        ▼                                                        ▼
   wolf-tdd-loop ◄───────────────────────────────────────────────┘
        │
        ├──► wolf-test-automation
        ├──► wolf-security-review
        │
        ▼
   wolf-cicd-deploy ─► wolf-observability ─► wolf-iteration-evolve ─► wolf-release-versioning
                                                                              │
                                                                              ▼
                                                              wolf-meta-skill-creator（自我进化）
```

## 技能清单

| # | 技能 | 一句话定位 | 目录 |
| --- | --- | --- | --- |
| 1 | `wolf-project-kickoff` | 先澄清、再计划、后拆解 | [wolf-project-kickoff/](wolf-project-kickoff/) |
| 2 | `wolf-architecture-blueprint` | 架构蓝图与 ADR | [wolf-architecture-blueprint/](wolf-architecture-blueprint/) |
| 3 | `wolf-domain-modeling` | DDD 领域建模 | [wolf-domain-modeling/](wolf-domain-modeling/) |
| 4 | `wolf-monorepo-scaffold` | 单仓多应用脚手架 | [wolf-monorepo-scaffold/](wolf-monorepo-scaffold/) |
| 5 | `wolf-api-contract` | API 契约优先 | [wolf-api-contract/](wolf-api-contract/) |
| 6 | `wolf-tdd-loop` | 红-绿-重构（**委托 `test-driven-development`**） | [wolf-tdd-loop/](wolf-tdd-loop/) |
| 7 | `wolf-test-automation` | 性能/契约/小程序测试（**E2E 委托 `webapp-testing`**） | [wolf-test-automation/](wolf-test-automation/) |
| 8 | ~~`wolf-security-review`~~ | **已废弃 → 用 `security-code-review`** | [wolf-security-review/](wolf-security-review/) |
| 9 | `wolf-cicd-deploy` | CI/CD 与部署 | [wolf-cicd-deploy/](wolf-cicd-deploy/) |
| 10 | `wolf-observability` | 可观测性三支柱 | [wolf-observability/](wolf-observability/) |
| 11 | `wolf-iteration-evolve` | 迭代进化与度量 | [wolf-iteration-evolve/](wolf-iteration-evolve/) |
| 12 | `wolf-release-versioning` | 版本管理与发布 | [wolf-release-versioning/](wolf-release-versioning/) |
| 13 | ~~`wolf-meta-skill-creator`~~ | **已降级 → 用 `skill-creator` + `writing-skills`** | [wolf-meta-skill-creator/](wolf-meta-skill-creator/) |

## 上游 vendor 技能清单（18）

| 技能 | 上游 | 定位 |
| --- | --- | --- |
| `skill-creator` | anthropics/skills | 官方元技能（创建/评估技能） |
| `frontend-design` | anthropics/skills | 前端美学锚点，告别 AI 审美疲劳 |
| `webapp-testing` | anthropics/skills | Playwright 端到端测试 |
| `mcp-builder` | anthropics/skills | 构建 MCP 服务器 |
| `brainstorming` | obra/superpowers | 需求头脑风暴 |
| `writing-plans` | obra/superpowers | 制定实现计划 |
| `writing-skills` | obra/superpowers | 编写技能（含 Anthropic 最佳实践） |
| `subagent-driven-development` | obra/superpowers | 子 Agent 驱动开发 |
| `dispatching-parallel-agents` | obra/superpowers | 并行派发子 Agent |
| `executing-plans` | obra/superpowers | 执行计划 |
| `systematic-debugging` | obra/superpowers | 系统化调试 |
| `test-driven-development` | obra/superpowers | 测试驱动开发 |
| `requesting-code-review` | obra/superpowers | 请求代码评审 |
| `receiving-code-review` | obra/superpowers | 接收代码评审 |
| `verification-before-completion` | obra/superpowers | 完成前验证 |
| `using-superpowers` | obra/superpowers | Superpowers 使用入口 |
| `security-code-review` | Artais-Security | 两遍扫描安全审查（含 40+ reference） |
| `karpathy-guidelines` | multica-ai | Karpathy 四原则行为准则 |

## 触发原则

- Agent 按各 `SKILL.md` 的 `description`（含 "Use when ..." / "Do not use for ..."）自动判定。
- 用户可直接点名："用 `wolf-tdd-loop` 实现 XX" 或 "用 `security-code-review` 审查这个 PR"。
- 组合使用：大型项目按**两层整合模型**串联——`wolf-*`（编排/领域）委托上游（执行），完整映射见 [`../docs/12-能力整合方案.md`](../docs/12-能力整合方案.md)；小任务只挂载 1 个即可。
- 能力重叠时以**上游 vendor 技能为准**：`security-code-review` 替代 `wolf-security-review`；`skill-creator`+`writing-skills` 替代 `wolf-meta-skill-creator`；`test-driven-development` 是 `wolf-tdd-loop` 的方法论；`webapp-testing` 是 `wolf-test-automation` 的 E2E 执行。
