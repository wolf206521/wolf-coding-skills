# 印刷行业生成型 ERP —— 完整开发方案（Master Plan）

> 代号 **P-ERP**（Printing ERP）。
> 本文是总纲。专项细节见同目录 `01`～`11` 号文档；可复用能力沉淀见 `../skills/`。
> 所有技术选型、门户拆分、命名约定以 [`_conventions.md`](./_conventions.md) 为唯一事实源。

---

## 0. 一句话定位

面向**书刊/包装/商务印刷**企业的**AI 原生（生成型）**一体化 ERP：把"报价—接单—印前—工艺—排产—生产—质检—仓储—发运—对账"全链路数字化，把"报价、拼版、文件预检、排产、客服、报表问答"等高频智力劳动交给生成式 AI 助手，同时用**一套可复用的 Skills 工程能力**支撑本项目（以及未来任何大型项目）的全过程开发、测试、交付与演进。

---

## 1. 现状与目标

### 1.1 已知约束（来自需求方的口头输入）

- 需求文档与原型页面在**另一个项目**中维护，尚未交付 → 本方案先建立"工程能力"，需求就绪后按流程接入。
- 代码必须**前后端分离**。
- 门户必须**分开**：ERP 后台、客户侧、供应商侧、外协侧。
- 端形态包含 **Web 端**与**小程序端**。
- 最终要把开发过程沉淀成**自己的 Skills 能力**，上传 **GitHub**，供其它工程/平台复用。

### 1.2 目标（DoD 级别）

1. 一套可运行的目标项目脚手架（Monorepo），四门户 + 小程序 + 后端 + AI 服务。
2. 一条从需求 → 代码 → 测试 → 发布 → 观测 → 迭代的**闭环流水线**，门禁全自动。
3. 一套**印刷行业领域模型与核心引擎**（报价、拼版、排产）的骨架与样例数据。
4. 一套**可移植的 Skills 能力包**（本仓库），脱离 P-ERP 仍能驱动任何大型项目。
5. GitHub 公开仓库 + 持续维护的说明与示例。

---

## 2. 门户与端形态的拆分决策

> 决策细节与 ADR 见 [`02-多端与门户拆分.md`](./02-多端与门户拆分.md)。

**结论：一个 Monorepo（单仓多应用）+ 三/四个独立构建部署的前端应用 + 一个共享领域内核包。**

| 端 | 应用目录 | 使用者 | 形态 | 独立部署 |
| --- | --- | --- | --- | --- |
| ERP 后台 | `apps/erp-console` | 企业内部全员 | Web（PC） | 是 |
| 客户侧 | `apps/customer-portal` | 客户 | Web + H5 | 是 |
| 客户侧小程序 | `apps/customer-mini` | 客户 | 微信小程序 | 是 |
| 供应商侧 | `apps/supplier-portal` | 供应商 | Web + H5 | 是 |
| 外协侧 | `apps/outsourcing-portal` | 外协加工厂 | Web + H5 | 是 |

**为什么"分开但同一仓库"**：三侧外部主体法律隔离、权限隔离、发版节奏不同，故**必须分应用**；但领域对象与 UI 骨架重合度 ≥ 70%，故**共享 `packages/portal-core`**，避免三倍代码与口径漂移。

**为什么小程序只做客户侧**：客户侧高频移动场景（下单/查进度/验货/对账）ROI 高；供应商/外协低频且需传文件，用 H5（企业微信内）即可。

---

## 3. 总体架构

```
                         ┌──────────────────────────── 前端 Monorepo ────────────────────────────┐
  微信小程序(客户) ──────► │ apps/customer-mini (Taro+React)                                       │
  Web/H5(客户) ──────────► │ apps/customer-portal        ──┐                                        │
  Web/H5(供应商) ────────► │ apps/supplier-portal        ──┼──► packages/portal-core (共享内核)     │
  Web/H5(外协) ──────────► │ apps/outsourcing-portal     ──┘      ├─ 认证/权限/租户                │
  Web/PC(内部) ──────────► │ apps/erp-console (AntD Pro)          ├─ api-client (OpenAPI 生成)     │
                         │        ▲ packages/api-client/domain-types/business-rules/ui-tokens      │
                         └────────┼────────────────────────────────────────────────────────────────┘
                                  │ HTTPS + OpenAPI 3.1（契约优先）
                         ┌────────▼──────────────────────────── 后端 ──────────────────────────────┐
  外部系统 ─────────────► │ API 网关（Spring Cloud Gateway / APISIX）                               │
  (JDF/JMF、财税、       │   │ 认证(JWT/租户/合作方) · 限流 · 审计                                  │
   TMS/WMS、AI平台)      │   ▼                                                                     │
                         │ services/erp-server（Spring Boot 3.3 + Spring Modulith 模块化单体）      │
                         │   报价│订单│印前│工艺│APS│生产│物料│供应商│外协│质量│仓储│财务│CRM│IAM│AI   │
                         │   ───────────────────────────── DDD 四层 ─────────────────────────────  │
                         │ services/ai-service（Python FastAPI + LangGraph + RAG）                  │
                         └───┬──────────┬──────────┬──────────┬──────────┬─────────────┬──────────┘
                             ▼          ▼          ▼          ▼          ▼             ▼
                         PostgreSQL   Redis    RocketMQ   Elasticsearch  MinIO    pgvector/Milvus
                        (pgvector)  (缓存/锁)  (事件/事务消息) (检索)   (文件)      (AI 向量)
```

**关键架构决策（ADR 摘要）**：

1. **模块化单体起步，不拆微服务**：边界用 Spring Modulith 强制校验；单点事务、运维成本低；拆服务是"被指标逼出来"的结果，不是起点。详见 `01-架构设计.md`。
2. **契约优先（API-First）**：后端出 OpenAPI 3.1 → 自动生成 TS client + Java client + 文档；前后端永不手工对齐类型。详见 `03-开发流程.md`。
3. **AI 服务独立进程**：Python 生态（LangGraph/RAG/评测）与 Java 主干解耦，避免阻塞主链路；敏感数据走私有化 vLLM。详见 `08-AI能力.md`。
4. **多租户 + 合作方数据隔离三层防线**：`tenant_id` + `partner_id`（RLS + 拦截器）+ 字段级脱敏。详见 `02-多端与门户拆分.md`。

---

## 4. 印刷行业领域模型与核心引擎

> 完整建模见 `09-领域模型与业务流程.md`。

### 4.1 核心聚合

`报价单 Quotation`、`销售订单 SalesOrder`、`生产工单 WorkOrder`、`工艺卡 CraftSheet`（工艺路线+工序）、`拼版方案 Imposition`、`纸张库存 PaperStock`、`外协单 OutsourcingOrder`、`采购单 PurchaseOrder`、`质检单 QualityCheck`、`发运单 Shipment`、`对账单 Statement`、`成本单 CostSheet`。

### 4.2 印刷行业三大硬骨头（一期必须啃下）

| 引擎 | 难点 | 方案 | AI 增强 |
| --- | --- | --- | --- |
| **报价引擎** | 开数/拼版/放损/纸张克重价/印工/后道工序的组合定价 | 规则引擎（Drools/Aviator）外置规则 + 历史成交价回归 | AI 报价助手：给定产品图 → 推荐工艺 + 价格区间，误差 ≤ 3% |
| **拼版/开纸** | 尺寸、咬口、出血、开数最大化、纸张利用率 | 排样算法（启发式 + 约束优化），G6 可视化 | AI 拼版建议：从成品尺寸直接给出拼版与开纸方案 |
| **APS 排产** | 机台产能、换版/换纸时间、交期、颜色组、外协依赖 | 约束满足 + 遗传/局部搜索，甘特图 | AI 排产建议 + 交期风险预测 |

### 4.3 行业标准对接（预留）

JDF/JMF（CIP4 印前-印刷-印后数据交换）、与 CTP/印刷机/切纸机的设备数据采集（MES/OEE）。

---

## 5. 生成型（AI）能力蓝图

> 详见 `08-AI能力.md`。

- **面向业务用户**：AI 报价、AI 拼版、AI 文件预检（preflight 报告自动生成）、AI 智能客服、AI 交期问答、AI 排产建议、AI 对账差异解释、ChatBI 报表问答。
- **面向内部运营**：AI 工艺路线推荐、AI 客诉归因、AI 供应商比价、AI 质量异常根因。
- **面向开发过程**：AI 生成领域代码/测试/OpenAPI/文档（本能力仓库的核心价值）。
- **安全红线**：设计稿/客户数据默认不出域；大模型输出必须过"评测门禁 + 人工抽检"；所有 AI 结论标注"AI 建议，供参考"，财务/价格类必须人工确认。

---

## 6. 开发流程（需求 → 交付的闭环）

> 详见 `03-开发流程与工程规范.md`，对应 Skill `wolf-project-kickoff`、`wolf-tdd-loop` 等。

```
需求/原型(外部项目) ─► 澄清式提问 ─► 领域建模 ─► API 契约 ─► TDD 实现 ─► PR + 门禁 ─► 灰度发布 ─► 观测 ─► 迭代
        ▲                                                                            │
        └──────────────────────────── 度量与反馈（进化）──────────────────────────────┘
```

一期需求未就绪时的**并行策略**：先跑通"工程能力"（脚手架、CI、测试、部署、观测），用**行业样例数据 + 假需求**驱动第一版骨架；需求文档到位后按 `wolf-project-kickoff` 增量接入，避免空转。

---

## 7. 自动化测试策略

> 详见 `04-自动化测试策略.md`，对应 Skill `wolf-test-automation`。

**测试金字塔 + 契约测试 + AI 评测**：

| 层 | 工具 | 门禁 |
| --- | --- | --- |
| 单元 | JUnit5 / Vitest | 行覆盖 ≥ 70%，核心域 ≥ 85% |
| 集成 | Testcontainers | 核心链路 100% |
| 架构 | ArchUnit | 跨模块依赖 = 阻塞 |
| 契约 | Spring Cloud Contract / Pact | 契约漂移 = 阻塞 |
| E2E | Playwright / miniprogram-automator | P0 场景 100% |
| 性能 | k6 / JMeter | P95 阈值达标 |
| 安全 | Trivy/Semgrep/ZAP | 高危 = 0 |
| AI 评测 | Ragas + 黄金集 | 报价误差 ≤ 3% |

---

## 8. 版本管理

> 详见 `05-版本管理与分支策略.md`，对应 Skill `wolf-release-versioning`。

**Trunk-based + 短分支 + Conventional Commits + Changesets（按端独立 SemVer）+ 不可变镜像 + Expand/Contract 数据库迁移**。发布节奏：双周迭代，hotfix 24h 回灌 `main`。

---

## 9. CI/CD 与自动化部署

> 详见 `06-CICD与部署.md`、`07-自建与私有化部署.md`，对应 Skill `wolf-cicd-deploy`。

- **一期**：Docker Compose 单机/双机自建；GitHub Actions（自建 Runner，适配印刷厂内网）+ Harbor。
- **二期**：K3s/K8s + Helm + Argo CD（GitOps）。
- **流水线**：`lint → test → build → sbom/scan → artifact → deploy(staging) → e2e → deploy(prod) → observe`，全程门禁，制品不可变、可追溯、可回滚。

---

## 10. 自建（私有化）与安全合规

> 详见 `07-自建与私有化部署.md`。

支持**离线/内网交付**（镜像离线包 + 本地 Harbor + 内网 Runner）；数据不出域；审计保留 ≥ 3 年；备份 PITR；密钥不落库。适配等保 2.0 三级基线（可裁剪）。

---

## 11. 循环迭代进化

> 详见 `10-迭代进化与度量.md`，对应 Skill `wolf-iteration-evolve`。

**度量四维度**：交付（Lead Time、部署频率、失败率、MTTR）+ 质量（缺陷密度、覆盖率、漏洞）+ 业务（报价命中率、订单周期、设备 OEE）+ AI（误差率、幻觉率、采纳率）。**双周回顾 + ADR 演进 + 技术债看板**，用数据驱动"模块化单体 → 微服务"的拆分时机。

---

## 12. 落地路线图

> 详见 `11-路线图与里程碑.md`。

| 阶段 | 周期 | 目标 | 出口标准 |
| --- | --- | --- | --- |
| M0 能力建设 | 1–2 周 | 本能力仓库成型 + 脚手架 + CI 绿 | `templates` 生成项目一次通过 |
| M1 骨架跑通 | 2–3 周 | 四门户 + 小程序 + 后端 + AI 空跑 | 登录取数、订单 CRUD 全链路 |
| M2 核心域 | 3–4 周 | 报价/拼版/排产引擎 V1 + 样例数据 | 报价误差 ≤ 3% 通过评测 |
| M3 外部协同 | 3–4 周 | 客户/供应商/外协门户 + 对账 | 三侧端到端可演示 |
| M4 生产可用 | 3–4 周 | 质检/仓储/发运/财务 + 观测 + 安全 | P0 E2E 全绿、安全门禁通过 |
| M5 私有化上线 | 持续 | 客户现场部署 + 迭代 | 3 家试点客户稳定运行 |

---

## 13. 能力沉淀与 GitHub 复用

> 仓库结构见 [`../README.md`](../README.md)，技能索引见 `../skills/README.md`。

**核心思想**（提炼自 CSDN《2026 十大 Skills》一文 + 本方案实践）：

1. **Superpowers 的方法论** → 本仓库 `wolf-project-kickoff`（先澄清、再计划、子 Agent 开发）。
2. **Karpathy 四原则** → 写入每个技能与 `wolf-meta-skill-creator`：先问、从简、精确、目标驱动。
3. **Skill Creator 元技能** → `wolf-meta-skill-creator`：本仓库能自我生产新技能。
4. **Webapp Testing / Security Review** → `wolf-test-automation` / `wolf-security-review`。
5. **GSD 的"先动再优"** → 与"先想清楚"互补，用门禁兜底，避免过度分析。

交付物：13 个 Skill（含元技能 `wolf-meta-skill-creator`，用于自我生产新技能）+ 脚手架模板 + CI/部署模板 + 安装/发布脚本 + GitHub Actions 自校验，任何工程执行 `scripts/install.ps1` 即可启用全过程开发能力。

---

## 14. 待用户确认的关键项（不阻塞，均有默认值）

1. **GitHub 仓库名/组织/可见性**（默认：`wolf-coding-skills`，公开）。
2. **后端语言**：Java（默认）还是 .NET / Node？——影响模板主语言。
3. **小程序平台**：微信（默认）是否还需支付宝/抖音？
4. **打印细分**：书刊 / 包装 / 商务 / 标签？——影响领域样例数据。
5. **AI 模型**：纯公有云 DeepSeek/Qwen（默认）还是必须私有化？

---

## 15. 验收清单

- [ ] 本仓库可从零生成 P-ERP 项目脚手架（见 `templates/`）。
- [ ] 13 个 Skill 齐全、frontmatter 合法、交叉链接无死链。
- [ ] CI 工作流能校验所有 Skill 结构与文档链接。
- [ ] 用户拿到后可执行 `scripts/install.ps1` 安装并验证技能被 Agent 识别。
- [ ] GitHub 上传说明与一键发布脚本可用（见 `scripts/publish-github.ps1`）。
