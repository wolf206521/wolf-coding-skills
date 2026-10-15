---
name: wolf-project-kickoff
description: "Run structured project kickoff: ask targeted clarifying questions before any code, then produce a plan, acceptance criteria, and task breakdown; verify against Definition of Done. Use when starting a new feature or project, when requirements or prototypes are vague or stored elsewhere, or when the user asks for a plan before implementation. Do not use for one-off trivial edits or tasks that are already fully specified."
---

# 项目启动（Wolf Project Kickoff）

> **委托上游**：提问方法论用 `brainstorming`（`REQUIRED SUB-SKILL`）；实现计划用 `writing-plans`（`REQUIRED SUB-SKILL`）。本技能只负责**印刷 ERP 领域适配**——把需求转成可追溯需求条目、注入印刷术语、对齐多门户/多租户口径。

在写任何代码之前，用结构化澄清式提问把模糊需求收敛成**可追溯的需求条目**，再产出计划、验收标准（Acceptance Criteria）与任务拆解，最后按 Definition of Done（DoD）校验。核心原则来自 Karpathy 四原则（先问 / 从简 / 精确 / 目标驱动）与 Superpowers brainstorming（并行 brainstorm → 收敛 → 子 Agent 分工）。

## 何时使用

- 启动新功能或新项目，或需求/原型含糊、仍存放在**另一个项目/文档系统**中尚未交付。
- 用户要求"先出计划再动手"，或需要把口头需求转成可执行的工程任务。
- 需要把工作拆成多个子 Agent 可并行执行的块。

**不用于**：一次性琐碎修改、已完全规格化（已有明确 AC 与实现细节）的任务。

## 前置条件

- 已读取 [`docs/_conventions.md`](../../docs/_conventions.md) 与 [`docs/00-master-plan.md`](../../docs/00-master-plan.md)，明确目标项目基线（示例 P-ERP）。
- 需求来源可访问（原型、文档、对话记录），或明确标注"需求缺失"并走样例数据策略（见 master-plan §6）。
- 明确本次范围边界：只出计划，还是"计划 + 实施"，避免越界写码。

## 工作流（分阶段，带门禁）

### 阶段 0：澄清式提问（先问，不动手）

按 Karpathy 四原则提问，优先用封闭式/选择题，把开放问题收窄。完整问题库见 [`reference/questions.md`](reference/questions.md)。

1. **先问（Ask First）**：在理解问题之前不写任何代码。每个回答未明确的点都追问，直到能复述需求。
2. **从简（Start Simple）**：优先最小方案，把"必须做"与"以后再说"分开；多问"没有它会怎样"。
3. **精确（Be Precise）**：要求具体数值与边界（用户数、并发、数据量、SLA、误差阈值），拒绝"大一点/快一点"。
4. **目标驱动（Goal-driven）**：每个需求回溯到业务目标与可量化指标（如报价误差 ≤ 3%、P95 < 500ms）。

提问示例（对照"模糊 vs 精确"）：

| 模糊说法 | 追问后的精确表述 |
| --- | --- |
| "订单要快" | 提交接口 P95 < 500ms，复杂报表 < 2s（对齐 `_conventions.md` §2.4） |
| "客户能查进度" | 客户在 `customer-portal` 登录后，按 `partner_id` 只见自己的订单，价格/成本字段脱敏（§5） |
| "报价准一点" | AI 报价误差 ≤ 3%，幻觉率 ≤ 2%（§2.4 AI 评测） |

**门禁 Gate 0**：下列字段全部有明确答案或显式标注"待定（有默认值）"，否则停留在阶段 0：

- 用户/角色：谁用？权限边界？是否外部合作方（客户/供应商/外协）？
- 核心流程：入口 → 步骤 → 出口，异常分支。
- 数据：来源、量级、生命周期、是否多租户/隔离。
- 非功能：性能、安全、可用性、审计要求（默认对齐 `_conventions.md` 第 5 节）。
- 验收：什么算"做完"（可测量）。

### 阶段 1：需求条目化（把"在另一个项目"转成可追溯条目）

需求若在另一个项目/原型中，不要复制粘贴，而是**抽取 + 编号 + 溯源**：

1. 每条需求给稳定 ID：`REQ-<领域>-<序号>`（如 `REQ-ORDER-001`）。
2. 每条写"用户故事 + 验收标准"两段式，并附**来源指针**：外部文档路径 + 页码/原型图编号。
3. 标依赖：`前置 / 被依赖`；标风险：`高/中/低`；标优先级：`P0/P1/P2`。
4. 需求未就绪的条目标记 `[待外部确认]`，并用样例数据占位驱动开发（不空转，见 master-plan §6 并行策略）。

条目样例：

```markdown
### REQ-ORDER-001 销售订单提交
- 用户故事：作为业务员，我要提交销售订单，以便触发后续工艺与排产。
- 验收标准：
  - Given 订单草稿已填齐 When 业务员点击提交 Then 状态变为 submitted 且产生 `order.sales-order.submitted` 事件。
  - Given 必填项缺失 When 提交 Then 返回字段级错误且不产生事件。
- 来源：<外部文档路径>#<页码/图编号>
- 依赖：REQ-IAM-001 | 被依赖：REQ-CRAFT-001 | 优先级：P0 | 风险：中 | 状态：已确认
```

**门禁 Gate 1**：每条需求都可通过 ID 追溯到来源；无"无主需求"（无法溯源的口头需求必须补录来源）。

### 阶段 2：产出计划与验收标准

对每条需求产出：

- **验收标准（AC）**：用 Given / When / Then 写成可自动化的断言（如上）。
- **DoD 清单**：`代码 + 测试 + 契约 + 文档 + 门禁全绿`，对齐 `_conventions.md` 第 2.4 节门禁阈值（后端单测 ≥ 70% / 核心域 ≥ 85%、契约漂移=阻塞、高危漏洞=0、P0 E2E 全绿）。
- **范围声明**：明确本期不做（out-of-scope），防止蔓延。

范围声明样例：

```markdown
- in-scope：订单提交、状态流转、领域事件。
- out-of-scope：本期不做拼版可视化、不做供应商比价、不做对账导出。
- 待外部确认：报价规则表（规则引擎专家未交付），先用 Aviator 默认规则占位。
```

**门禁 Gate 2**：AC 可被执行（每条至少对应一个测试用例）；DoD 与 `_conventions.md` 一致。

### 阶段 3：任务拆解

把计划拆成 ≤ 1 天的任务，遵循：

- 每条任务单一行，含 `ID | 依赖 | 产出物 | 校验方式 | 估时`。
- 任务粒度以"一个人 + 一个上下文"可完成为界；> 1 天继续拆。
- 关键路径标出，并行任务明确互斥/共享资源（如共享 `packages/portal-core` 时的冲突）。

```markdown
| ID | 任务 | 依赖 | 产出物 | 校验方式 | 估时(天) |
| --- | --- | --- | --- | --- | --- |
| T1 | 冻结 domain-types | 无 | packages/domain-types | 类型编译 + 契约对齐 | 0.5 |
| T2 | 生成 api-client | T1 | packages/api-client | 生成脚本可重复执行 | 0.5 |
| T3 | 订单提交用例 | T2 | erp-server order 模块 | 单测+集成绿 | 1 |
```

### 阶段 4：子 Agent 分工（Superpowers brainstorming）

1. **并行 brainstorm**：为每个独立任务/子域派一个子 Agent 独立给方案，互不阻塞。
2. **收敛**：主 Agent 汇总、去重、仲裁冲突，输出唯一口径。
3. **分工派发**：按依赖顺序派发，共享资源（领域类型、OpenAPI client）先做并冻结，再并行外围。

```markdown
### Agent-A：报价引擎方案
- 输入：REQ-QUOTATION-*、_conventions.md §2.2/§2.3
- 产出：报价规则表 + 方案 ADR
- 边界：只出方案，不写实现
```

多 Agent 分工样例：

```markdown
### Agent-A：报价引擎方案     ### Agent-B：拼版算法方案
- 输入：REQ-QUOTATION-*       - 输入：REQ-PREPRESS-*
- 产出：报价规则表 + ADR      - 产出：排样算法选型 + ADR
- 边界：只出方案，不写实现    - 边界：只出方案，不写实现
- 依赖：无（可并行）          - 依赖：无（与 A 并行）
```

**门禁 Gate 3**：任务无循环依赖；共享产出物有明确的"先冻结"顺序。

## 产物

| 产物 | 位置/命名 | 说明 |
| --- | --- | --- |
| 需求条目表 | `docs/<project>/requirements.md` | ID + 故事 + AC + 来源 + 依赖 |
| 计划与 DoD | `docs/<project>/plan.md` | 范围 + AC + DoD + 里程碑 |
| 任务拆解 | `docs/<project>/tasks.md` | 任务表 + 依赖图 + 关键路径 |
| 子 Agent 分工 | `docs/<project>/agents.md` | 每个 Agent 的输入/产出/边界 |

模板见 [`reference/templates.md`](reference/templates.md)。

## 校验

- [ ] Gate 0～3 全部通过，无"无主需求"。
- [ ] 每条需求有 ID 且可追溯到外部来源。
- [ ] 每条 AC 用 Given/When/Then 写且对应至少一个测试用例。
- [ ] DoD 与 `_conventions.md` 门禁阈值一致。
- [ ] 任务无循环依赖，共享产出物有冻结顺序。
- [ ] 计划明确标注 out-of-scope 与待外部确认项。

## 常见失败与处置

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| 问了一圈仍写不了代码 | 问题太开放 | 回到阶段 0，改用封闭式选择题；把"必须做"与"以后做"分开 |
| 需求在别处、无法访问 | 外部文档未交付 | 标记 `[待外部确认]`，用样例数据占位，先跑通工程能力 |
| 任务拆完互相阻塞 | 共享资源未冻结 | 先冻结 `domain-types` / `api-client` / `portal-core`，再并行外围 |
| AC 无法自动化 | 写得太主观 | 重写为可测量断言；无明确指标的 AC 打回需求方 |
| 子 Agent 输出互相矛盾 | brainstorm 未收敛 | 主 Agent 汇总仲裁，产出唯一口径后再派发实施 |
