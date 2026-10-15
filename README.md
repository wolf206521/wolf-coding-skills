# Wolf Coding Skills 🐺

一套用于**大型企业级软件项目全过程开发**的可复用 AI 能力包（Claude / DSH Skills 集合）。

它把"需求澄清 → 架构 → 领域建模 → 脚手架 → API 契约 → TDD → 测试 → 安全 → CI/CD → 可观测 → 迭代进化 → 版本发布 → 自我生产技能"沉淀为 13 个可自动挂载的 Skill，配套文档模板、脚手架模板、CI/部署模板与安装/发布脚本。任何工程（ERP、MES、WMS、电商、SaaS……）执行一条命令即可启用全过程工程能力。

本仓库的**首个落地示例项目**为「印刷行业生成型 ERP（代号 P-ERP）」，完整方案见 [`docs/00-master-plan.md`](docs/00-master-plan.md)。

---

## 一、它能做什么

| 环节 | 对应能力 |
| --- | --- |
| 需求澄清与立项 | `wolf-project-kickoff` |
| 架构设计与 ADR | `wolf-architecture-blueprint` |
| 领域建模（DDD） | `wolf-domain-modeling` |
| 单仓多应用脚手架 | `wolf-monorepo-scaffold` |
| API 契约优先 | `wolf-api-contract` |
| 测试驱动开发 | `wolf-tdd-loop` |
| 自动化测试（E2E/契约/性能） | `wolf-test-automation` |
| 上线前安全审查 | `wolf-security-review` |
| CI/CD 与部署 | `wolf-cicd-deploy` |
| 可观测性 | `wolf-observability` |
| 迭代进化与度量 | `wolf-iteration-evolve` |
| 版本管理与发布 | `wolf-release-versioning` |
| 自我生产新技能 | `wolf-meta-skill-creator` |

> 方法论来源：吸收自 CSDN《2026 年 AI 编程助手十大实用 Skills 全解析》（Superpowers、Karpathy Guidelines、Skill Creator、Webapp Testing、Security Review、GSD 等）并经本项目实践整合。

**除自研 13 个 `wolf-*` 技能外，本仓库还**逐字原文集成**了 18 个真实上游技能**（`anthropics/skills`、`obra/superpowers`、`Artais-Security` 安全审查、Karpathy 准则），可直接获得原版成熟能力。清单见 [`skills/README.md`](skills/README.md)，来源与许可证见 [`skills/VENDORS.md`](skills/VENDORS.md)。

**两层整合模型**：上游技能 = **执行层**（提问/TDD/调试/审查/安全/前端/技能生产）；`wolf-*` = **编排层/印刷领域层**（架构/领域建模/脚手架/契约/CI-CD/可观测/迭代/发布，并把上游串成全流程）。整合映射与委托/废弃清单见 [`docs/12-能力整合方案.md`](docs/12-能力整合方案.md)，全局行为准则与技能路由见根 [`CLAUDE.md`](CLAUDE.md)。

---

## 二、目录结构

```
wolf-coding-skills/
├── README.md                 # 本文件
├── LICENSE                   # MIT
├── docs/                     # 方案文档（P-ERP 落地示例）
│   ├── _conventions.md       # ★ 唯一事实源：技术栈/门户拆分/命名/版本基线
│   ├── 00-master-plan.md     # ★ 总纲
│   └── 01~11 …               # 架构/门户/流程/测试/版本/CI/自建/AI/领域/迭代/路线
├── skills/                   # ★ 13 个可复用技能（每目录一个 SKILL.md）
├── templates/                # 脚手架 + CI/部署模板（供目标项目复制）
├── scripts/                  # 安装 / 校验 / 发布脚本
└── .github/workflows/        # 本仓库自校验 CI + Release
```

---

## 三、快速开始

### 1. 安装到你的 Agent

**DSH（DeepSeek Harness）/ Claude Code 均支持 `SKILL.md` 目录格式。**

```powershell
# Windows (PowerShell)
.\scripts\install.ps1            # 复制到 ~\.dsh\skills\ 与 ~\.claude\skills\
.\scripts\install.ps1 -Uninstall # 卸载
```

```bash
# Linux / macOS
./scripts/install.sh
```

安装后，向 Agent 描述任务（如"帮我给一个新 ERP 项目做架构设计"），Agent 会按 `SKILL.md` 的 `description` 自动挂载对应技能。也可直接说"用 wolf-project-kickoff 技能"。

### 2. 校验仓库完整性

```bash
node scripts/validate-skills.mjs   # 校验 frontmatter、目录名、文档死链
```

### 3. 用模板生成目标项目

以印刷 ERP 为例，参照 [`templates/monorepo/README.md`](templates/monorepo/README.md) 复制模板，再配合 `wolf-monorepo-scaffold` 技能生成四门户 + 小程序 + 后端 + AI 服务骨架。

---

## 四、目标项目（P-ERP）架构速览

- **一个 Monorepo（单仓多应用）**：ERP 后台、客户侧、供应商侧、外协侧四个 Web/H5 应用 + 客户侧微信小程序，共享 `packages/portal-core` 领域内核。
- **后端**：Java 21 + Spring Boot 3.3 + Spring Modulith（模块化单体，可拆微服务）；独立 Python FastAPI + LangGraph 的 AI 服务。
- **数据**：PostgreSQL 16（pgvector）、Redis、RocketMQ、Elasticsearch、MinIO。
- **交付**：一期 Docker Compose 自建，二期 K8s + Helm + Argo CD（GitOps）。
- **全链路**：契约优先 → TDD → 门禁 → 灰度 → 观测 → 迭代。

详见 [`docs/00-master-plan.md`](docs/00-master-plan.md) 与 [`docs/_conventions.md`](docs/_conventions.md)。

---

## 五、上传到 GitHub

```powershell
.\scripts\publish-github.ps1 -RepoUrl https://github.com/<你>/wolf-coding-skills.git
```

脚本会完成 `git init → add → commit(Conventional Commits) → branch main → remote add → push`，凭据走环境变量 `GH_TOKEN` 或已配置的 git 凭据，不写死任何密码。首次公开仓库建议在 GitHub 页面勾选 MIT License（已内置）。

---

## 六、写给二次使用方（其它工程/平台）

1. 把本仓库 clone 或作为 submodule 引入。
2. 执行 `scripts/install.ps1` 装载技能。
3. 读 `docs/_conventions.md` 决定是否做"项目级覆盖"（如把 Java 换成 .NET）。
4. 从 `docs/00-master-plan.md` 的路线图开始，按里程碑推进。
5. 需要扩展能力时，用 `wolf-meta-skill-creator` 生产你自己的技能，并提交回本仓库或你的私有仓库。

---

## 七、路线图（能力仓库自身）

- [x] 方案文档 00~11 + 13 个技能 + 脚手架/CI/部署模板 + 安装/发布脚本
- [ ] P-ERP 目标项目从模板生成的可运行骨架（需求文档就绪后落地）
- [ ] 报价引擎 / 拼版 / APS 的领域样例代码
- [ ] 更多行业适配包（MES/WMS/电商）

---

## License

[MIT](./LICENSE) © 2026 wolf-coding-skills contributors
