---
name: wolf-tdd-loop
description: "Drive test-driven development with a strict red-green-refactor loop, unit and integration tests, coverage gates, and mutation testing for core domain logic. Use when implementing or changing behavior. Do not use for documentation, configuration-only changes, or pure styling."
---

# TDD 循环（红-绿-重构）

> **委托上游**：RED-GREEN-REFACTOR 循环与 TDD 方法论用 `test-driven-development`（`REQUIRED SUB-SKILL`）。本技能只保留**印刷 ERP 领域门禁阈值**（核心域覆盖率 ≥85%、变异杀死率 ≥60%）与"何时跳过 TDD"的领域裁量。

用严格的 Red-Green-Refactor 循环驱动行为实现；单元/集成测试分层；覆盖率与变异测试门禁兜底。
**核心域逻辑必须 TDD**；其余行为改动默认 TDD，允许显式标注跳过（见「何时跳过 TDD」）。
门禁阈值以 [`../../docs/_conventions.md`](../../docs/_conventions.md) 第 2.4 节为准。

## 何时使用

- 实现新功能或修改既有行为（后端领域逻辑、应用服务、前端业务逻辑）。
- 修复 bug：先写能复现失败的测试再修。

不适用于：文档、纯配置改动、纯样式（CSS/主题令牌）、生成物/脚手架（可选标注跳过）。

## 前置条件

- 后端：JUnit 5 + AssertJ + Mockito；集成用 Testcontainers（PG/Redis/RocketMQ）。
- 前端：Vitest + Testing Library。
- 门禁：行覆盖 ≥ 70%，核心域 ≥ 85%；核心域 PIT 变异杀死率 ≥ 60%。
- 架构守卫：ArchUnit（跨模块直接依赖内部包 = 阻塞）。

## 工作流（分阶段，带门禁）

### 阶段 1：写失败测试（RED）

1. 先写最小失败用例，命名 `should_<行为>_when_<条件>`。
2. 运行并确认**失败原因与预期一致**（断言失败），而不是编译错误或 NPE 误报——误报不算 RED。

JUnit 5 骨架：

```java
class PaperCostCalculatorTest {
    @Test
    void should_apply_waste_rate_when_calculating_paper_cost() {
        var calc = new PaperCostCalculator();
        BigDecimal cost = calc.cost(1000, new WasteRate("3%"));
        assertThat(cost).isEqualByComparingTo("1030.00");
    }
}
```

Vitest 骨架：

```ts
import { describe, it, expect } from 'vitest';
describe('calcWaste', () => {
  it('should apply waste rate to paper cost', () => {
    expect(calcWaste(1000, 0.03)).toBe(1030);
  });
});
```

### 阶段 2：最小实现（GREEN）

只写让测试通过的最少代码，禁止一步到位写"终极实现"。

**门禁 G1**：`./gradlew test`（后端）/ `pnpm vitest run`（前端）全绿。

### 阶段 3：重构（REFACTOR）

测试全绿前提下消除重复、改善命名、拆分方法，**不改行为**。

**门禁 G2**：重构后测试仍全绿；ArchUnit 规则不降级。

### 阶段 4：集成测试（门禁 G3）

核心链路用 Testcontainers 起真实依赖，覆盖持久化/事务/消息（RocketMQ 事务消息、订单-库存-工单一致性）：

```java
@SpringBootTest
@Testcontainers
class OrderSubmissionIT {
    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16");

    @Test
    void should_deduct_stock_and_create_work_order_when_order_submitted() {
        // 起 Redis/RocketMQ 容器；提交订单；断言库存扣减 + 工单生成 + 消息投递
    }
}
```

**G3 通过条件**：核心链路 100% 覆盖；CI 中 Testcontainers 用例全绿。单测与集成测试分 task 并行，避免拖慢流水线。

### 阶段 5：覆盖率与变异测试（门禁 G4）

```bash
# 覆盖率（JaCoCo 聚合报告）
./gradlew jacocoTestReport
# 核心域变异测试（PIT，只跑领域包，控制耗时）
./gradlew pitest \
  -Dpitest.targetClasses='com.wolf.perp.quotation.domain.*,com.wolf.perp.aps.domain.*'
```

**G4 通过条件**：行覆盖 ≥ 70%、核心域 ≥ 85%；核心域 PIT 杀死率 ≥ 60%。未达标 → 补测试，**不降门禁**。

### 何时跳过 TDD（必须显式标注）

以下情况可在 PR 描述标注 `[skip-tdd]` 并说明理由，其余一律不允许：

- 纯文档、配置（`application.yml`、`compose.yaml`）、样式（CSS/设计令牌）。
- 自动生成物（OpenAPI 生成 client、迁移脚本样板）。
- 一次性 spike/原型（后续必须补测试或删除）。

**跳过不等于无测试**：配置/迁移仍需一条冒烟测试证明可加载。

## 产物

- 红→绿→重构可追溯的提交记录（测试先于实现）。
- 单元测试 + 集成测试代码。
- 覆盖率报告（JaCoCo/Vitest coverage）、PIT 报告（核心域）。

## 校验

- `./gradlew test` / `pnpm vitest run` 全绿。
- JaCoCo 报告满足阈值；PIT 杀死率 ≥ 60%。
- 无未标注的 TDD 跳过；测试命名符合 `should_*_when_*` / `it('should ...')`。

## 常见失败与处置

| 现象 | 处置 |
| --- | --- |
| 测试因编译错误"失败" | 先补实现桩（空方法返回 null），再跑测试；编译错误不算 RED。 |
| 覆盖率卡在 83% | 补边界用例（空值、越界、状态流转），禁止用 `@Generated` 或排除来刷数。 |
| Testcontainers 起不来 | 检查 Docker 可用性、镜像 tag（postgres:16）、端口冲突；CI 用 Ryuk 自动回收。 |
| PIT 杀死率低 | 换更强断言；删除只覆盖不验证的测试；对等价类补变异。 |
| 集成测试拖慢 CI | 单测/集成分 task 并行，集成用 `@Testcontainers(parallel = true)`。 |

## 验收清单

- [ ] 每个行为改动都有先于实现存在的失败测试。
- [ ] 门禁 G1~G4 全部通过，核心域覆盖率 ≥ 85%、PIT 杀死率 ≥ 60%。
- [ ] 无未标注的 TDD 跳过；配置/迁移有冒烟测试兜底。
