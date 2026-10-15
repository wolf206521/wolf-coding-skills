---
name: wolf-domain-modeling
description: "Run DDD domain modeling: bounded contexts, aggregates, entities, value objects, domain events, and a ubiquitous language glossary, grounded in real workflows. Use when modeling a complex business domain (e.g. printing, manufacturing) before coding. Do not use for pure CRUD or trivial features."
---

# 领域建模（Wolf Domain Modeling）

用 DDD 方法对复杂业务域建模：限界上下文（Bounded Context）、聚合（Aggregate）、实体（Entity）、值对象（Value Object）、领域事件（Domain Event），并产出统一语言词汇表（Ubiquitous Language）。以真实工作流为地基（领域故事风暴），最终映射到 Spring Modulith 模块与 monorepo 包。

## 何时使用

- 为一个复杂业务域建模（如印刷、制造），在写码之前把概念与边界理清。
- 需要统一前后端、业务与开发的术语口径（报价、拼版、排产等）。

**不用于**：纯 CRUD、琐碎功能（直接走 `wolf-project-kickoff`）。

## 前置条件

- 已走 `wolf-project-kickoff` 拿到需求条目与真实工作流（否则先澄清，避免凭空建模）。
- 已读取 `_conventions.md` 第 4 节（模块清单 `quotation/order/prepress/craft/aps/...` 与命名）。
- 有领域专家或一线业务人员可访谈；无则用 master-plan §4 的印刷行业样例数据驱动。

## 工作流（分阶段，带门禁）

### 阶段 0：领域故事风暴（EventStorming 简化版）

1. 召集领域专家，按**时间线**贴出"命令 → 事件 → 聚合"三色便签：
   - 橙色 **命令**（动词，如"提交订单"）、蓝色 **事件**（过去式，如 `order.sales-order.submitted`）、黄色 **聚合**（名词）。
2. 用真实工作流串起主线（报价 → 接单 → 印前 → 工艺 → 排产 → 生产 → 质检 → 仓储 → 发运 → 对账），再补异常与旁路（外协、退货、加急）。
3. 标记争议点与术语歧义，记录在词汇表待办。

印刷行业主线示例：

```text
业务员提交报价单 → Quotation.created → 客户确认 → SalesOrder.submitted
→ CraftSheet.generated → Imposition.planned → WorkOrder.scheduled
→ WorkOrder.started → QualityCheck.passed → Shipment.shipped → Statement.issued
```

旁路/异常事件（同样贴到时间线上）：

```text
OutsourcingOrder.created（外协旁路）· QualityCheck.failed（质检异常）
· SalesOrder.urgent-requested（加急）· Shipment.returned（退货）
```

**门禁 Gate 0**：主线工作流端到端贴通，每个事件都有触发的命令与来源聚合。

### 阶段 1：限界上下文与模块边界

1. 按业务能力与语言边界切限界上下文，映射到 Spring Modulith 模块（对齐 `_conventions.md` §4 模块清单）。
2. 上下文间只通过**公开接口/事件**通信；明确哪些概念同名但含义不同（如"订单"在 `order` 与 `outsourcing` 不同）。
3. 每个上下文写一句话职责声明，标注所有权与依赖方向（禁止环依赖）。

模块职责样例：

| 模块 | 职责 | 依赖方向 |
| --- | --- | --- |
| quotation | 报价方案与价格计算 | → craft（取工艺规则） |
| order | 销售订单全生命周期 | → quotation、crm |
| craft | 工艺卡/BOM/损耗规则 | 无（基础域） |
| outsourcing | 外协单 | → order、supplier |

**门禁 Gate 1**：模块边界与 `_conventions.md` 模块清单一致；依赖无环（可用 ArchUnit 兜底）。

### 阶段 2：聚合与实体设计

聚合设计规则：

- **一次事务改一个聚合**；跨聚合一致性用领域事件（对齐 §2.1 RocketMQ 事务消息）。
- 聚合根是唯一入口；外部只能通过根引用内部实体（用 ID 引用其它聚合，不持对象引用）。
- 不变量写在聚合内（如"订单金额 = 各明细合计"），禁止外部直接改内部状态。
- 聚合大小宁小勿大；`SalesOrder` / `Quotation` / `WorkOrder` / `CraftSheet` 是典型聚合根（见 master-plan §4.1）。

`SalesOrder` 聚合样例：

```text
SalesOrder（根）
├── SalesOrderId（ID，引用聚合身份）
├── CustomerId（ID 引用 CRM 聚合）
├── 明细 SalesOrderLine[]（内部实体）
├── 金额 Money（值对象）
└── 不变量：金额 = Σ 明细小计；已提交后不可改明细
```

**门禁 Gate 2**：每个聚合有唯一根、明确不变量、与其它聚合的 ID 引用关系；无跨聚合直接对象引用。

### 阶段 3：值对象与领域事件

- **值对象**：无身份、不可变、整体替换（如 `Money`、`PaperSize`、`ColorGroup`、`DueDate`）。识别标准：比较用"相等"而非"同一"。
- **领域事件**：命名 `<domain>.<aggregate>.<past-tense-verb>`（对齐 §4 命名），如 `order.sales-order.submitted`、`craft.craft-sheet.generated`。事件承载 `aggregateId + 关键数据 + 事件时间`，用于解耦与审计。

值对象识别表（印刷行业）：

| 候选概念 | 判定 | 类型 |
| --- | --- | --- |
| 金额/价格 | 相等即同，无身份 | 值对象 `Money` |
| 纸张规格（尺寸/克重） | 相等即同 | 值对象 `PaperSpec` |
| 客户 | 有独立生命周期 | 实体/聚合 `Customer` |
| 报价单号 | 有唯一身份 | 实体/聚合根 `Quotation` |

事件清单样例：

```text
order.sales-order.submitted     ← 命令 SubmitOrder       → 消费者 craft、aps
craft.craft-sheet.generated     ← 命令 GenerateCraftSheet → 消费者 aps、quotation
quality.quality-check.passed    ← 命令 PassCheck          → 消费者 warehouse、shipment
```

**门禁 Gate 3**：值对象不可变且无 ID；每个关键状态变更都有对应领域事件，命名符合规范。

### 阶段 4：统一语言词汇表 + 模块映射

1. 产出词汇表：`中文术语 | 英文标识符 | 定义 | 所属上下文 | 别名/歧义 | 来源`。
2. 把模型映射到代码位置：聚合 → `services/erp-server/.../domain/`，跨端共享类型 → `packages/domain-types`，值对象/规则 → `packages/business-rules`。

模型 → 代码映射样例：

| 模型 | Java 包 | TS 包 |
| --- | --- | --- |
| SalesOrder 聚合 | `com.wolf.perp.order.domain` | `@wolf/domain-types` |
| Money 值对象 | `.../order/domain` 或共享 | `@wolf/business-rules` |
| 报价规则 | `.../quotation/domain` | `@wolf/business-rules` |

**门禁 Gate 4**：词汇表覆盖所有关键术语且前后端口径一致；每个聚合有明确的 Java 包与 TS 包落点。

## 产物

| 产物 | 位置/命名 | 说明 |
| --- | --- | --- |
| 统一语言词汇表 | `docs/<project>/glossary.md` | 术语 + 英文标识符 + 定义 + 上下文 |
| 限界上下文图 | `docs/<project>/bounded-contexts.md` | 上下文 + 职责 + 依赖方向 |
| 聚合清单 | `docs/<project>/aggregates.md` | 根 + 不变量 + 引用关系 |
| 事件清单 | `docs/<project>/domain-events.md` | 事件命名 + 触发命令 + 消费者 |
| 模块映射 | `docs/<project>/model-to-modules.md` | 模型 → Java 包 / TS 包 |

词汇表模板见 [`reference/glossary-template.md`](reference/glossary-template.md)。

## 校验

- [ ] 主线工作流端到端贴通，事件可追溯到命令与聚合。
- [ ] 限界上下文/模块边界与 `_conventions.md` 模块清单一致，依赖无环。
- [ ] 每个聚合有唯一根、不变量、ID 引用关系，无跨聚合对象引用。
- [ ] 值对象不可变无 ID；事件命名符合 `<domain>.<aggregate>.<past-tense-verb>`。
- [ ] 词汇表覆盖关键术语，前后端口径一致。
- [ ] 每个聚合有明确 Java 包与 TS 包落点。

## 常见失败与处置

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| 建模脱离真实流程 | 未做事件风暴 | 回到阶段 0，从真实工作流贴便签再抽象 |
| 术语前后端打架 | 缺统一语言 | 以词汇表为准，代码标识符用英文、文档用中文并互相引用 |
| 聚合过大 | 把整个订单塞一个聚合 | 按"一次事务一个聚合"拆分，用事件解耦 |
| 跨聚合直接引用对象 | 图省事 | 改为 ID 引用 + 仓储加载；ArchUnit 校验 |
| 模块依赖成环 | 边界未定 | 重画依赖方向，共享概念下沉到 `portal-core` / `domain-types` |
