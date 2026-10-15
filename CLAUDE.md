# 行为准则与技能路由（Wolf Coding Skills 全局）

> Agent 每次会话自动加载本文件。它只做两件事：**定行为准则** + **指技能路由**，不重复技能正文。

## 一、行为准则（Karpathy 四原则，全局常驻）

1. **先问，不猜**：需求模糊时先澄清；有多种理解时列出选项让用户选；不确定就停。
2. **从简**：没被要求的功能不写；只用一次的代码不建抽象；不被要求的灵活性不加。
3. **精确编辑**：只改被要求改的部分；匹配已有代码风格；不相关问题只提不改。
4. **目标驱动**：以验收标准（Definition of Done）为准，让它自己跑，而非给步骤。

完整细则见 [`skills/karpathy-guidelines/CLAUDE.md`](skills/karpathy-guidelines/CLAUDE.md)。

## 二、技能路由（两层整合模型）

本仓库有 **31 个技能** = 自研编排层 `wolf-*`（13）+ 上游执行层（18）。规则见 [`docs/12-能力整合方案.md`](docs/12-能力整合方案.md)。

- **通用方法论**（提问/TDD/调试/审查/安全/前端/技能生产）→ 用**上游技能**（`brainstorming`、`test-driven-development`、`systematic-debugging`、`security-code-review`、`frontend-design`、`skill-creator`、`writing-skills` 等）。
- **印刷 ERP 领域 + 大型项目编排**（架构/领域建模/脚手架/API 契约/CI-CD/可观测/迭代/发布）→ 用 `wolf-*` 技能。
- **能力重叠时以 `VENDORS.md` 列出的上游技能为准**；`wolf-security-review`、`wolf-meta-skill-creator` 已被上游替代（见其 SKILL.md 顶部标注）。

## 三、快速定位

| 我要做什么 | 用哪个技能 |
| --- | --- |
| 澄清需求/立项 | `wolf-project-kickoff` → `brainstorming` |
| 定架构/ADR | `wolf-architecture-blueprint` |
| 建印刷领域模型 | `wolf-domain-modeling` |
| 写实现计划 | `writing-plans` |
| 生成多端脚手架 | `wolf-monorepo-scaffold` |
| 定义 API 契约 | `wolf-api-contract` |
| 写代码（TDD） | `test-driven-development` |
| 执行计划（子代理） | `subagent-driven-development` |
| 调试 | `systematic-debugging` |
| E2E 测试 | `webapp-testing` |
| 性能/契约/小程序测试 | `wolf-test-automation` |
| 上线前安全审查 | `security-code-review` |
| 前端设计 | `frontend-design` |
| CI/CD 与部署 | `wolf-cicd-deploy` |
| 可观测 | `wolf-observability` |
| 迭代度量/进化 | `wolf-iteration-evolve` |
| 版本发布 | `wolf-release-versioning` |
| 造/改技能 | `skill-creator` + `writing-skills` |
