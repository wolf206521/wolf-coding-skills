---
name: wolf-architecture-blueprint
description: "Produce an architecture blueprint and Architecture Decision Records (ADRs): modular monolith vs microservices, technology stack, deployment topology, capacity, and tradeoffs. Use when designing a new system, choosing a stack, or recording an architectural decision for a large project. Do not use for small bug fixes or pure feature work."
---

# 架构蓝图（Wolf Architecture Blueprint）

为新系统产出架构蓝图与 Architecture Decision Records（ADR），覆盖模块化单体 vs 微服务、技术栈、部署拓扑、容量估算与取舍。默认对齐 [`docs/_conventions.md`](../../docs/_conventions.md) 第 2 节基线，不一致处显式标注"项目级覆盖"。

## 何时使用

- 设计新系统、选型技术栈，或为大型项目记录一个架构决策。
- 需要回答"模块化单体还是微服务"、部署拓扑、容量规划、可演进性。

**不用于**：小 bug 修复、纯功能开发（那是 `wolf-project-kickoff` / `wolf-tdd-loop` 的事）。

## 前置条件

- 已读取 `_conventions.md` 第 1～3 节（门户拆分、技术栈、版本管理）与 `00-master-plan.md` 第 3 节（总体架构）。
- 已有需求/规模输入（用户数、数据量、并发、SLA），否则先走 `wolf-project-kickoff` 澄清。
- 明确决策的**约束边界**：私有化/内网、预算、团队技能、合规（等保）。

## 工作流（分阶段，带门禁）

### 阶段 0：收集约束与目标

列出三类输入，缺一不可：

1. **功能需求**：模块清单（来自领域建模，见 `wolf-domain-modeling`）。
2. **质量属性**：性能、可用性、安全、可扩展、可维护、成本、合规。
3. **约束**：私有化部署、内网 Runner、团队规模、技术栈偏好、遗留系统。

质量属性量化示例：

| 质量属性 | 目标值（对齐 §2.4） |
| --- | --- |
| 性能 | 查询 P95 < 500ms；复杂报表 < 2s |
| 可用性 | 一期 99.5%，二期 99.9% |
| 安全 | 高危漏洞 = 0；审计保留 ≥ 3 年 |
| 一致性 | 订单-库存-工单用事务消息保证最终一致 |

**门禁 Gate 0**：三类输入都有条目；质量属性有量化指标。

### 阶段 1：架构决策（模块化单体优先）

默认结论：**模块化单体起步，不拆微服务**（依据 `_conventions.md` §2.1 Spring Modulith + DDD 四层）。每项决策走 ADR 流程：

1. 背景 → 2. 选项（≥2 个，含现状）→ 3. 决策 → 4. 后果 → 5. 回滚条件。

拆微服务的**触发条件**（被指标逼出来，不是起点）：单模块发布频率冲突、团队并行阻塞、独立扩缩容需求、数据强隔离硬约束。满足之一才评估拆分。

ADR 摘要样例（完整格式见 `reference/adr-template.md`）：

```text
ADR-0001 模块化单体起步
- 背景：一期团队 ≤ 3 人，无独立扩缩容与强隔离诉求。
- 选项：A 微服务 / B 模块化单体（Spring Modulith）。
- 决策：选 B，用 ArchUnit 强制模块边界，AI 服务独立进程特例。
- 后果：单点事务简单、运维成本低；代价是边界纪律要靠测试兜底。
- 回滚：当某模块部署频率持续为整体 2 倍以上且合并阻塞 → 立 ADR 拆该模块。
```

**门禁 Gate 1**：每个关键决策有 ADR；"拆微服务"决策必须给出触发的量化指标与拆分边界（按模块对齐 `_conventions.md` 的模块清单 `quotation/order/prepress/craft/aps/...`）。

### 阶段 2：技术栈落表

按 `_conventions.md` 第 2 节逐层核对，产出"层 → 选型 → 版本 → 用途"表。有偏离时：

- 写明**项目级覆盖**理由（ADR）。
- 标注风险与替代方案（如 ShardingSphere 一期不分片但按分片键设计）。

落表样例（后端主干，完整见 `_conventions.md` §2.1）：

| 层 | 选型 | 版本 | 用途/说明 |
| --- | --- | --- | --- |
| 运行时 | Java | 21 LTS | 虚拟线程用于 IO 密集 |
| 框架 | Spring Boot | 3.3.x | |
| 模块化 | Spring Modulith | 1.2.x | 边界可验证、可拆微服务 |
| 数据库 | PostgreSQL | 16 | + pgvector / PostGIS |
| 消息 | RocketMQ | 5.x | 事务消息、延迟消息 |

**门禁 Gate 2**：技术栈与 `_conventions.md` §2 一致，偏离处有 ADR。

### 阶段 3：部署拓扑与容量

1. **拓扑**：一期 Docker Compose 单机/双机 → 二期 K3s/K8s + Helm + Argo CD（对齐 §2.5）。
2. **容量估算**：按 `峰值 QPS × 单请求资源 × 冗余系数` 估算，给出起步规格与扩容触发点。
3. **数据层**：PostgreSQL（pgvector/PostGIS）+ Redis + RocketMQ + Elasticsearch + MinIO 的角色、连接与备份（pgBackRest PITR）。

拓扑组件表（一期 Compose）：

| 组件 | 角色 | 连接方 |
| --- | --- | --- |
| erp-server | Spring Boot 模块化单体 | PG / Redis / RocketMQ / ES / MinIO |
| ai-service | Python FastAPI + LangGraph | PG(pgvector) / 模型网关 |
| 网关 | 认证(JWT/租户) + 限流 + 审计 | erp-server / ai-service |
| 前端 apps | 各门户/小程序静态产物 | 网关 |

容量估算示例（订单查询，峰值 200 QPS）：

```text
单请求 CPU ≈ 5ms → 1 core 支撑约 200 QPS
峰值 200 QPS × 冗余系数 2 = 400 QPS → 起步 2 core / 4 GiB
扩容阈值：CPU 持续 > 70% 或 P95 > 500ms 持续 15 分钟
存储：日增订单 1 万行 × 2 KiB ≈ 20 MiB/天，保留 3 年 ≈ 22 GiB，PITR 冗余 ×2
```

**门禁 Gate 3**：拓扑可画成一张图（组件 + 数据流 + 边界）；容量表有"起步规格"与"扩容阈值"两列。

### 阶段 4：蓝图与回滚策略

汇总为蓝图文档，并写明：

- 演进路径：模块化单体 → 按需拆微服务的触发指标与步骤。
- 回滚：不可变镜像 + Expand/Contract 数据库迁移，回滚 = 切回上一镜像 tag（对齐 §3）。

演进路径样例：

```text
M0 模块化单体（Spring Modulith + ArchUnit 守边界）
→ M1 AI 服务独立进程（特例拆分）
→ M2 按触发指标拆 quotation / aps 为微服务（仅当指标满足，见 ADR 回滚条件）
```

**门禁 Gate 4**：蓝图含决策记录、拓扑图、容量表、演进路径、回滚策略五要素。

## 产物

| 产物 | 位置/命名 | 说明 |
| --- | --- | --- |
| 架构蓝图 | `docs/<project>/architecture.md` | 组件/拓扑/容量/演进 |
| ADR 记录 | `docs/<project>/adr/NNNN-<title>.md` | 每条决策独立一文件 |
| 容量估算表 | 蓝图内或 `docs/<project>/capacity.md` | 起步规格 + 扩容阈值 |

ADR 模板见 [`reference/adr-template.md`](reference/adr-template.md)。

## 校验

- [ ] 所有选型与 `_conventions.md` 第 2 节一致，偏离处有 ADR 标注"项目级覆盖"。
- [ ] 每个关键决策有 ADR（背景/选项/决策/后果/回滚条件）。
- [ ] 微服务拆分决策给出量化触发指标与拆分边界。
- [ ] 容量表有"起步规格"与"扩容阈值"。
- [ ] 蓝图含决策记录、拓扑图、容量、演进路径、回滚策略五要素。

## 常见失败与处置

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| 直接跳到微服务 | 未评估单体可行性 | 回到阶段 1，先论证模块化单体；拆服务需量化指标触发 |
| 容量拍脑袋 | 无 QPS/数据量输入 | 回 `wolf-project-kickoff` 补数据；给"起步 + 扩容阈值"两档 |
| 选型与基线冲突未标注 | 未走 ADR | 冲突处补 ADR，写明"项目级覆盖"理由与替代方案 |
| 蓝图无法演进 | 只写现状无触发点 | 补演进路径与拆分触发指标（对齐 §11 度量四维度） |
| ADR 散落在聊天里 | 未落盘 | 每条决策落 `docs/<project>/adr/NNNN-*.md`，保留版本历史 |
