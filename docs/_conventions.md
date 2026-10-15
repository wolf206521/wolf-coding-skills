# 基线约定（Baseline Conventions）

> 本文件是本能力仓库的**唯一事实源（Single Source of Truth）**。
> `docs/` 下所有专项方案、`skills/` 下所有技能、`templates/` 下所有模板，都必须与本文一致。
> 若需变更，先改本文件，再改下游产物。

---

## 0. 术语表

| 术语 | 含义 |
| --- | --- |
| **能力仓库** | 即本仓库 `wolf-coding-skills`，沉淀"大型软件项目全过程开发"的可复用 Skills 与模板 |
| **目标项目** | 使用本能力仓库开展的实际工程。本文档的示例目标项目为「印刷行业生成型 ERP」（代号 `P-ERP`） |
| **ERP 后台** | 企业内部使用者（业务员、工艺、生产、仓库、财务、管理员）使用的管理端 |
| **协同端** | 企业外部协作方使用的一端，含 **客户侧 / 供应商侧 / 外协侧** |
| **生成型（Generative）** | 双重含义：①业务侧 AI 原生能力（报价、拼版、预检、排产、问答）；②开发侧 AI 驱动的代码/测试/文档生成流水线 |
| **Skill** | 一个含 `SKILL.md` 的文件夹，Agent 按 `description` 自动挂载执行 |
| **门禁（Gate）** | 流水线中不可跳过的质量/合规检查点 |
| **DoD** | Definition of Done，完成的验收标准 |

---

## 1. 门户与应用拆分决策（已定稿）

### 1.1 结论

**一个 Monorepo（单仓多应用）+ 三个独立构建部署的前端应用 + 一层共享领域内核包。**

| 应用 | 目录 | 使用者 | 端 | 部署单元 |
| --- | --- | --- | --- | --- |
| ERP 后台 | `apps/erp-console` | 企业内部 | Web（PC 优先） | 独立 |
| 客户侧 | `apps/customer-portal` | 客户 | Web + H5 | 独立 |
| 客户侧小程序 | `apps/customer-mini` | 客户 | 微信小程序 | 独立 |
| 供应商侧 | `apps/supplier-portal` | 纸张/油墨/版材等供应商 | Web + H5 | 独立 |
| 外协侧 | `apps/outsourcing-portal` | 外协加工厂（覆膜/烫金/模切/装订等） | Web + H5 | 独立 |
| 共享内核 | `packages/portal-core` | 上述协同三端 | — | 库（不部署） |

### 1.2 为什么"分开，但不分家"

- **必须分开**：三者法律主体不同、权限域不同、发版节奏不同、SLA 不同、数据可见性不同（客户绝不能看到供应商价格）。
- **不能分家**：三端的领域对象（订单、工序、交期、对账、附件）重合度 ≥ 70%，UI 骨架重合度 ≥ 60%。三套独立代码库会导致三倍缺陷、三倍回归、口径漂移。
- **落地方式**：`packages/portal-core` 提供 `认证/权限/请求层/领域类型/业务规则/UI 骨架/单据组件`；三个 app 只写各自**独有的路由与视图**。
- **降级/加速开关**：若一期资源紧张，允许先用 `PORTAL_MODE=supplier|outsourcing` 从同一 app 构建出两侧产物，二期再物理拆分目录。开关定义见 `packages/portal-core/src/mode.ts`。

### 1.3 为什么小程序只做客户侧

- 客户下单/查进度/验货确认/对账 → 高频、移动化诉求真实。
- 供应商/外协 → 低频 + 需要上传文件/工序照片，H5（企业微信内打开）已足够，做小程序 ROI 低。
- 小程序与客户 Web 用同一 `portal-core` + 同一 OpenAPI 生成的 client，保证口径一致。

---

## 2. 技术栈基线（已定稿）

### 2.1 后端主干

| 层 | 选型 | 版本基线 | 说明 |
| --- | --- | --- | --- |
| 语言/运行时 | Java | 21 LTS | 虚拟线程用于 IO 密集 |
| 框架 | Spring Boot | 3.3.x | |
| 模块化 | Spring Modulith | 1.2.x | 模块化单体起步，边界可验证、可拆微服务 |
| 架构风格 | DDD 四层 | — | `interfaces / application / domain / infrastructure` |
| 契约 | OpenAPI 3.1 | — | 契约优先，禁止手写前端请求类型 |
| 数据库 | PostgreSQL | 16 | + `pgvector`（AI 向量）、`PostGIS`（可选） |
| 分片（预留） | Apache ShardingSphere | 5.5.x | 一期不分片，但按分片键设计 |
| 缓存 | Redis | 7.2 | 会话、幂等、分布式锁、热点字典 |
| 消息 | Apache RocketMQ | 5.x | 事务消息（订单-库存-工单一致性）、延迟消息（交期提醒） |
| 搜索 | Elasticsearch | 8.x | 订单/客户/文件全文检索 |
| 对象存储 | MinIO（自建）/ S3 兼容 | — | 印前文件、设计稿、质检图 |
| 定时/批处理 | Spring Batch + XXL-Job | — | 对账、结算、报表跑批 |
| 规则引擎 | Drools / Aviator | — | **报价规则、工艺规则**外置，业务可自助改 |
| 报表 | JimuReport / 自研导出 | — | 印刷行业单据复杂，须支持模板化套打 |
| 状态机 | Spring StateMachine / 自研 | — | 订单、工单、外协单状态流转可审计 |

### 2.2 AI / 生成型服务

| 层 | 选型 | 说明 |
| --- | --- | --- |
| 语言 | Python 3.12 | 独立部署，不侵入 Java 主干 |
| 框架 | FastAPI + Pydantic v2 | 流式 SSE |
| 编排 | LangGraph | 有状态、可中断、可人工介入（Human-in-the-loop） |
| 模型网关 | One-API / LiteLLM | 统一路由、限流、计量、多模型热切换 |
| 模型 | DeepSeek-V3/R1、Qwen2.5、GLM-4（公有云）+ vLLM 私有化 | 敏感数据（客户设计稿）走私有化 |
| 向量库 | pgvector（起步）→ Milvus（规模化） | |
| RAG | 企业知识库（工艺手册、历史报价、客诉案例、设备手册） | |
| 可观测 | Langfuse / Phoenix | Prompt 版本、Token 成本、评测集 |
| 评测 | Ragas + 自建黄金集 | AI 输出必须过评测门禁才可上线 |

### 2.3 前端

| 端 | 选型 | 说明 |
| --- | --- | --- |
| 包管理与编排 | pnpm 9 + Turborepo 2 | 单仓多应用 |
| 框架 | React 18 + TypeScript 5.5 | 全端统一 React，降低认知成本 |
| 构建 | Vite 5 | 小程序用 Taro 4（React） |
| 组件库 | ERP：Ant Design 5 + ProComponents；协同端：Ant Design 5 + Ant Design Mobile；小程序：NutUI-React | |
| CRUD 引擎 | Refine 4（或等价自研元数据驱动框架） | 由 OpenAPI/元数据生成列表-详情-表单 |
| 数据层 | TanStack Query 5 + Zustand 4 | 服务端状态与客户端状态分离 |
| 表单/校验 | React Hook Form + Zod | Zod schema 与后端 JSON Schema 对齐 |
| 图表/可视化 | AntV G2（统计）、G6（工艺路线/拼版/排产甘特） | 拼版可视化必须用图编辑能力 |
| 国际化 | i18next | 中文起步，预留英文 |
| 微前端（可选） | qiankun / Module Federation | 仅在 ERP 后台模块团队并行时启用 |

### 2.4 测试与质量

| 类型 | 工具 | 门禁阈值（一期） |
| --- | --- | --- |
| 后端单测 | JUnit 5 + AssertJ + Mockito | 行覆盖 ≥ 70%，核心域 ≥ 85% |
| 后端集成 | Testcontainers（PG/Redis/RocketMQ） | 核心链路 100% 覆盖 |
| 架构守卫 | ArchUnit | 禁止跨模块直接依赖内部包 |
| 变异测试 | PIT（核心域） | 变异杀死率 ≥ 60% |
| 契约测试 | Spring Cloud Contract / Pact | 前后端契约漂移 = 阻塞 |
| 前端单测 | Vitest + Testing Library | 覆盖 ≥ 60% |
| E2E | Playwright | P0 场景 100% 自动化 |
| 小程序测试 | miniprogram-automator | P0 场景 |
| 性能 | k6（接口）+ JMeter（报表/批处理） | P95 < 500ms（查询）/ < 2s（复杂报表） |
| 安全 | OWASP Dependency-Check、Trivy、Semgrep、ZAP | 高危 0 容忍 |
| 静态质量 | SonarQube（Quality Gate） | 阻断：新增 Blocker/Critical = 0 |
| AI 评测 | Ragas + 黄金集 + 人工抽检 | 报价误差 ≤ 3%，幻觉率 ≤ 2% |

### 2.5 基础设施与交付

| 能力 | 选型 |
| --- | --- |
| 容器 | Docker（多阶段构建，distroless/JRE 21 slim） |
| 编排 | 一期 Docker Compose（单机/双机）→ 二期 K3s/K8s + Helm |
| GitOps | Argo CD（K8s 阶段）/ Komodo 或自研（Compose 阶段） |
| CI | GitHub Actions（自建 Runner，印刷厂内网需内网 Runner） |
| 制品 | Harbor（镜像）+ GitHub Packages / Nexus（依赖与包） |
| 密钥 | Vault / SOPS + age / K8s Secret（禁止明文入库） |
| 可观测 | OpenTelemetry Collector → Prometheus + Grafana + Loki + Tempo |
| 日志/审计 | 结构化 JSON 日志 + 全链路 traceId + 业务操作审计表（不可删） |
| 备份 | pgBackRest（PITR）+ MinIO 版本化 + 异地冷备 |

---

## 3. 版本管理基线

| 项 | 约定 |
| --- | --- |
| 分支模型 | **Trunk-based + 短分支**：`main`（永远可发布）+ `feat/*` `fix/*` `hotfix/*`（≤ 3 天）+ `release/x.y`（仅 LTS 维护） |
| 提交规范 | Conventional Commits：`feat|fix|docs|refactor|perf|test|build|ci|chore|revert(scope): subject` |
| 版本号 | SemVer 2.0.0，按端独立版本：`erp-console@1.4.0`、`backend@1.4.2`（Changesets 管理） |
| 变更记录 | Changesets 自动生成 `CHANGELOG.md`；发布说明由 commit 自动汇总 |
| 标签 | 注解标签 `<app>@<version>`，与镜像 tag、Helm chart version 一一对应 |
| 发布节奏 | 双周迭代（Sprint），每周三可发布窗口；hotfix 随时，24h 内必须回灌 `main` |
| 制品可追溯 | 制品元数据写入 `build-info.json`：commit SHA + 构建号 + SBOM + 签名 |
| 回滚 | 镜像不可变 + 数据库向前兼容迁移（Expand/Contract 模式），回滚 = 切回上一镜像 tag |
| 单一事实源 | `main` 分支 + PR 必须过全部门禁；禁止直接 push `main` |

---

## 4. 命名与目录约定（目标项目 Monorepo）

```
p-erp/                                  # 目标项目仓库（由本能力仓库脚手架生成）
├── apps/
│   ├── erp-console/                    # ERP 后台（Web/PC）
│   ├── customer-portal/                # 客户侧（Web + H5）
│   ├── customer-mini/                  # 客户侧微信小程序（Taro）
│   ├── supplier-portal/                # 供应商侧
│   └── outsourcing-portal/             # 外协侧
├── packages/
│   ├── portal-core/                    # 协同三端共享内核（认证/权限/请求/领域类型/骨架）
│   ├── api-client/                     # 由 OpenAPI 自动生成，禁止手写
│   ├── domain-types/                   # 跨端共享 TS 类型（由后端 schema 生成）
│   ├── ui-tokens/                      # 设计令牌（色板/间距/字号/暗色）
│   ├── business-rules/                 # 可前端复用的纯函数业务规则（报价试算/损耗计算）
│   └── utils/
├── services/                           # 后端（模块化单体）
│   ├── erp-server/                     # Spring Boot 主应用
│   │   └── src/main/java/com/wolf/perp/
│   │       ├── interfaces/             # Controller / DTO / Assembler
│   │       ├── application/            # 用例编排 / Command / Query
│   │       ├── domain/                 # 聚合/实体/值对象/领域服务/仓储接口/领域事件
│   │       └── infrastructure/         # 持久化/消息/外部系统/缓存 实现
│   └── ai-service/                     # Python FastAPI + LangGraph
├── platform/                           # 基础设施即代码
│   ├── compose/                        # 一期 Docker Compose
│   ├── helm/                           # 二期 Helm charts
│   ├── argocd/                         # GitOps 应用定义
│   └── observability/                  # OTel/Prometheus/Grafana/Loki 配置
├── tests/
│   ├── e2e/                            # Playwright
│   ├── performance/                     # k6
│   ├── contract/                        # Pact
│   └── fixtures/                        # 印刷行业测试数据（纸张/工艺/订单样例）
├── docs/                               # 项目自身文档（ADR、领域词汇表、接口说明）
├── scripts/                            # 开发/构建/发布/数据初始化脚本
└── .github/workflows/                  # CI/CD
```

**后端模块（Spring Modulith module）划分**：`quotation`（报价）、`order`（订单）、`prepress`（印前）、`craft`（工艺/BOM）、`aps`（排产）、`production`（工单/MES）、`material`（纸张物料）、`supplier`（供应商）、`outsourcing`（外协）、`quality`（质量）、`warehouse`（仓储物流）、`finance`（财务/成本）、`crm`（客户）、`ai`（AI 能力网关）、`iam`（认证授权）、`tenant`（多租户）、`audit`（审计）、`integration`（外部系统）。

**命名规范**：
- 数据库：表 `snake_case` 复数（`sales_orders`），字段 `snake_case`，外键 `<table_singular>_id`，时间列 `<verb>_at`，布尔 `is_/has_`。
- Java：包全小写、类 `UpperCamel`、方法 `lowerCamel`、常量 `UPPER_SNAKE`。
- TS：组件 `PascalCase.tsx`、hook `useXxx.ts`、工具 `kebab-case.ts`。
- API：`/api/v1/{domain}/{resource}`，资源复数，动作型用子资源（`POST /orders/{id}/submit`）。
- 事件：`<domain>.<aggregate>.<past-tense-verb>`，如 `order.sales-order.submitted`。
- Git：分支 `feat/PE-123-quotation-engine`（关联需求号）。

---

## 5. 权限与多租户基线

- **主体模型**：`用户 ← 角色 ← 权限点`；协同端用户额外绑定 `合作方（客户/供应商/外协）` 主体。
- **数据隔离三层**：
  1. **租户级**（`tenant_id`）：一套部署服务多法人。
  2. **合作方级**（`partner_id` + `partner_type`）：协同端只能见自己的单据，由 MyBatis/JPA 拦截器 + 行级安全策略（PostgreSQL RLS）双保险。
  3. **字段级**：价格、成本、其他客户信息对协同端永久脱敏（后端 DTO 层面裁剪，不依赖前端隐藏）。
- **认证**：ERP 后台用账密 + 短信/TOTP 二次验证；协同端用手机号验证码 + 微信授权（小程序）；对接企业微信/钉钉可选。
- **授权**：OAuth 2.1 + JWT（短期 access + 轮转 refresh），协同端 token 内嵌 `partner_type/partner_id`，网关校验。
- **审计**：所有写操作与越权尝试写入 `audit_logs`（只增不改），保留 ≥ 3 年（印刷行业对账/税务要求）。

---

## 6. 文档与技能写作规范

所有 `docs/*.md` 与 `skills/*/SKILL.md` 必须满足：

1. **中文正文**（代码、标识符、命令保持英文）；专有名词首次出现给英文对照。
2. **可执行**：每个结论给出命令、目录、配置片段或检查清单，禁止只讲理念。
3. **可验证**：每份文档末尾必须有「验收清单」，条目为可勾选的客观事实。
4. **决策留痕**：架构选择写成 ADR 风格（背景 / 选项 / 决策 / 后果 / 回滚条件）。
5. **不重复造轮子**：引用其他文档用相对链接，不复制大段内容。
6. **Skill frontmatter** 固定格式：

```yaml
---
name: <kebab-case，与目录同名>
description: <英文，1-3 句。说明做什么 + "Use when ..." 触发条件 + "Do not use for ..." 排除条件>
---
```

`SKILL.md` 正文结构：`# 标题` → `## 何时使用` → `## 前置条件` → `## 工作流（分阶段，带门禁）` → `## 产物` → `## 校验` → `## 常见失败与处置`。
技能体积控制：`SKILL.md` ≤ 500 行；细节放 `reference/`，模板放 `assets/`，可执行逻辑放 `scripts/`。

---

## 7. 验收清单

- [ ] 所有 `docs/*.md` 与 `skills/*/SKILL.md` 的技术选型与本文第 2 节一致（不一致处须显式标注为"项目级覆盖"）。
- [ ] 所有门户拆分描述与本文第 1 节一致。
- [ ] 所有 `skills/*/SKILL.md` 的 frontmatter 字段完整，`name` 与目录名一致。
- [ ] 所有文档末尾含「验收清单」。
- [ ] `README.md` 中的技能索引与 `skills/` 实际目录一一对应。
