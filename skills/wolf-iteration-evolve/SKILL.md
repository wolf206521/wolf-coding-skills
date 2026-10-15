---
name: wolf-iteration-evolve
description: Run the iteration loop: define DORA and business metrics, run retrospectives, manage technical debt, and drive data-informed evolution such as when to split a modular monolith into services. Use at sprint end or when planning refactors. Do not use for greenfield design.
---

# 迭代循环与度量进化

把"度量 → 回顾 → 还债 → 演进"做成闭环，用数据（而非直觉）驱动架构演进。对齐 [`../docs/00-master-plan.md`](../../docs/00-master-plan.md) 第 11 节四维度度量：交付（DORA）+ 质量 + 业务 + AI。拆分时机由 `wolf-iteration-evolve` 判定，拆分后的交付/部署见 `../wolf-cicd-deploy`，版本见 `../wolf-release-versioning`。

## 何时使用

| 触发场景 | 动作 |
| --- | --- |
| Sprint 结束（双周） | 阶段 2 回顾 + 阶段 1 指标核对 |
| 想拆模块化单体/重构 | 阶段 4 拆分触发阈值 |
| 技术债越积越多 | 阶段 3 分级与偿还 |
| 新项目从零设计架构 | **不使用本技能**（属 greenfield，用 `wolf-project-kickoff`） |

## 前置条件

- 观测体系已上线（`wolf-observability`），能从 Grafana/Prometheus 取到指标。
- CI/CD 能产出 Lead Time、部署频率、失败率、MTTR 的原始事件（`wolf-cicd-deploy` 的流水线日志/制品元数据）。
- 有可写 ADR 目录（`docs/adr/`）与团队回顾习惯。

## 工作流（分阶段，带门禁）

### 阶段 1：定义并采集度量

**DORA 四指标**（交付维度）+ 三补充维度：

| 维度 | 指标 | 采集来源 | 目标（示例） |
| --- | --- | --- | --- |
| 交付 | 部署频率 Deployment Frequency | CI/CD 部署事件 | 每周 ≥ 3 次 |
| 交付 | 变更前置时间 Lead Time | 首提交→上线时间戳 | P85 ≤ 2 天 |
| 交付 | 变更失败率 CFR | 失败部署/总部署 | ≤ 15% |
| 交付 | 平均恢复时间 MTTR | 告警→恢复时间戳 | ≤ 1 小时 |
| 质量 | 缺陷密度 / 覆盖率 / 高危漏洞 | SonarQube / Trivy | 见 `_conventions.md` 第 2.4 节 |
| 业务 | 报价命中率 / 订单周期 / 设备 OEE | 业务表 + 埋点 | 报价误差 ≤ 3% |
| AI | 误差率 / 幻觉率 / 采纳率 | Langfuse / Ragas 评测 | 幻觉率 ≤ 2% |

指标必须**可查询**，给出固化查询而非手工口径。示例：

```promql
# 交付（DORA）—— 部署频率 / 变更失败率（来自 CI/CD 部署事件指标）
sum(increase(perp_deployments_total{env="prod"}[7d]))          # 部署频率
sum(increase(perp_deployments_total{env="prod",result="failed"}[7d]))
  / sum(increase(perp_deployments_total{env="prod"}[7d]))      # 变更失败率

# 业务 —— 报价命中率
sum(increase(perp_quotation_submitted_total{result="ok"}[7d]))
  / sum(increase(perp_quotation_submitted_total[7d]))

# AI —— 幻觉率（来自 Langfuse / Ragas 评测事件）
sum(increase(perp_ai_eval_total{verdict="hallucinated"}[7d]))
  / sum(increase(perp_ai_eval_total[7d]))
```

Lead Time 与 MTTR 来自事件表/制品元数据，用 SQL 聚合：

```sql
-- Lead Time（首提交 → 上线）P85
SELECT percentile_cont(0.85) WITHIN GROUP (ORDER BY deployed_at - first_commit_at)
FROM releases WHERE deployed_at IS NOT NULL;

-- MTTR（告警 → 恢复）均值
SELECT avg(recovered_at - alert_started_at) FROM incidents WHERE recovered_at IS NOT NULL;
```

- **门禁 G1（基线存在）**：上述每个指标都有**自动采集**（非手工汇报）与时间序列；采集脚本/查询固化在 `platform/observability/` 或 `scripts/metrics/`；缺指标的维度要显式标记"本期不可测"。

### 阶段 2：双周回顾（Retrospective）

用「数据先行 + 行动项收敛」模板（完整见 [`reference/retrospective-template.md`](./reference/retrospective-template.md)）：

1. **看数据**：先读 DORA/质量/业务/AI 看板，标出环比变化 >20% 的项。
2. **三问**：做得好（Keep）/ 有问题（Problem）/ 要尝试（Try）。
3. **收敛**：Problem 必须落到**根因**，Try 必须落到**SMART 行动项**（负责人 + 期限 + 可验证产出）。
4. **定债**：把回顾中暴露的技术债送入阶段 3 看板。

- **门禁 G2（行动项可落地）**：每个行动项是 SMART 格式；上一轮行动项闭环率 ≥ 70%（未闭环的说明原因并滚动）；回顾结论回写 ADR 或回顾纪要。

### 阶段 3：技术债分级与偿还

技术债**分级**（按风险 × 影响），决定偿还顺序与节奏：

| 级别 | 定义 | 示例 | 处置 |
| --- | --- | --- | --- |
| P0 高危 | 安全隐患、数据可能错/丢、告警天天响 | 明文密钥、无审计、无备份 | 立即偿清，阻塞新功能 |
| P1 蔓延 | 边界被突破、复制粘贴扩散 | 跨模块直接依赖内部包 | 本迭代偿还，ArchUnit 门禁拦截 |
| P2 延迟 | 影响交付速度但暂不致命 | 缺测试、命名漂移 | 按 20% 时间预算持续还 |
| P3 优化 | 理想状态差距 | 微重构、文档补全 | 顺路做，不单独排期 |

- **门禁 G3（债不失控）**：技术债有看板与 owner；P0 存量 = 0；P1 每迭代至少偿清 1 项；新增债必须登记（不登记的债不进入偿还队列）。

### 阶段 4：拆分触发阈值（模块化单体 → 服务）

**原则：拆服务是被指标逼出来的结果，不是起点**（`00-master-plan.md` 第 3 节 ADR-1）。满足以下**至少 2 项、且持续 ≥ 2 个迭代**才启动拆分评估：

| 触发信号 | 阈值 | 数据源 |
| --- | --- | --- |
| 部署耦合 | 一个模块改动拖慢全量部署/回归 | Lead Time 劣化 + 模块变更频率 |
| 独立扩展 | 某模块 CPU/内存峰值远超其他 | Prometheus 资源指标 |
| 故障隔离 | 某模块故障频繁拖垮全局 | 错误率 + MTTR 归因 |
| 团队瓶颈 | 多人频繁改同一模块互相阻塞 | PR 冲突率/等待时长 |
| 独立 SLA | 某模块对可用性/延迟有独立强要求 | SLO 差异 |

评估输出用 ADR 记录：背景 / 选项（保持单体 vs 拆 / 拆哪几个）/ 决策 / 后果 / 回滚条件（拆分后若无法证明收益，回退单体）。

达到阈值后，用**拆分决策记分卡**做最终判定（全部通过才拆）：

| 判定问题 | 若为否的后果 |
| --- | --- |
| 拆分边界清晰（单一聚合/领域、无跨模块频繁共享）？ | 边界模糊会导致分布式事务与数据漂移，慎拆 |
| 数据可独立归属、不跨服务强一致？ | 强一致跨服务需分布式事务，复杂度和故障面激增 |
| 有独立扩展 / 独立 SLA 的硬需求？ | 无则维持单体，收益为负 |
| 团队已具备多服务运维能力（观测/自动化/CI 全覆盖）？ | 运维能力不足先补 `wolf-observability` / `wolf-cicd-deploy` |
| 已排除「模块化单体 + 独立部署」这一更轻的方案？ | 能轻量解决就不该上微服务 |

- **门禁 G4（数据驱动）**：拆分决策必须引用阶段 1 的**量化指标**，并写 ADR；未达阈值不拆；拆分后设**观察期**验证收益（部署更快？故障隔离更好？）。

### 阶段 5：度量看板与反馈闭环

把四维度指标汇成一张**迭代看板**（Grafana Dashboard 或 `docs/metrics.md` 的自动汇总），双周刷新：

- 每指标：当前值 / 环比 / 目标 / 趋势 sparkline。
- 每迭代：行动项闭环率、技术债存量曲线、拆分评估结论。
- 看板趋势反向驱动下一轮：指标劣化 → 下轮回顾重点关注 → 行动项 → 偿还。

- **门禁 G5（闭环生效）**：看板至少连续 3 个迭代有数据且趋势可读；能说出"上一个行动项带来了什么指标变化"（哪怕变化为 0 也是结论）。

## 产物

- `docs/metrics.md` 或 Grafana「迭代看板」：四维度指标 + 目标 + 趋势。
- `docs/adr/`：架构演进 ADR（尤其拆分决策）。
- 回顾纪要 + 技术债看板（P0–P3 分级 + owner + 状态）。

## 校验

- [ ] 四维度指标均有自动采集与时间序列，非手工汇报。
- [ ] 最近一次回顾产出 SMART 行动项，且上轮闭环率 ≥ 70%。
- [ ] 技术债看板分级完整，P0 为 0，P1 有偿还计划。
- [ ] 若发生拆分，有 ADR 且引用了量化阈值指标。

## 常见失败与处置

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| 指标靠人工 Excel 汇报 | 未自动化采集 | 从 CI/CD 事件与 Prometheus 自动取，见 `wolf-cicd-deploy`/`wolf-observability` |
| 回顾沦为吐槽、无行动 | Problem 未挖根因、Try 不 SMART | 强制 SMART + 下轮核闭环率 |
| 技术债越记越多没人还 | 无预算、无 owner、无门禁 | 固定 20% 时间预算；P1 用 ArchUnit/门禁拦截新增 |
| 一拍脑袋就拆微服务 | 未看指标、未到阈值 | 走阶段 4 阈值 + ADR，未达阈值不拆 |
| 拆分后收益无法证明 | 无观察期/基线对比 | 拆前留基线指标，拆后设观察期对比 |

---

## 验收清单

- [ ] 阶段 1–5 走通，五道门禁（G1–G5）有通过记录。
- [ ] 四维度度量自动采集，迭代看板连续 ≥ 3 个迭代可读。
- [ ] 回顾产出 SMART 行动项，闭环率 ≥ 70%。
- [ ] 技术债 P0=0、P1 有计划，拆分决策全部 ADR 留痕且数据驱动。
