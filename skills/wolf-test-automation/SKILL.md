---
name: wolf-test-automation
description: "Build automated test coverage beyond unit tests: Playwright end-to-end, contract tests (Pact/Spring Cloud Contract), performance (k6/JMeter), and WeChat mini-program automation. Use when a feature needs E2E, contract, or performance coverage, or when setting up the test harness. Do not use for writing a single unit test (see wolf-tdd-loop)."
---

# 测试自动化（E2E / 契约 / 性能 / 小程序）

> **委托上游**：Playwright E2E 用 `webapp-testing`（`REQUIRED SUB-SKILL`）。本技能负责上游未覆盖的**领域测试**——k6/JMeter 性能、Pact/Spring Cloud Contract 契约、微信小程序自动化、P0 场景清单。

在单元测试之上补齐自动化：Playwright E2E（委托 webapp-testing）、契约测试（Pact/Spring Cloud Contract）、性能（k6/JMeter）、微信小程序自动化。
单元测试归属 [wolf-tdd-loop](../wolf-tdd-loop/SKILL.md)。门禁阈值以 [`../../docs/_conventions.md`](../../docs/_conventions.md) 第 2.4 节为准。

## 何时使用

- 新功能需要 E2E 覆盖（P0 场景）、契约验证、性能回归。
- 搭建/维护测试 harness（`tests/e2e`、`tests/performance`、`tests/contract`、`tests/fixtures`）。
- 客户侧小程序 P0 场景自动化。

不适用于：写单个单元测试（用 wolf-tdd-loop）。

## 前置条件

- 测试目录结构按 `_conventions.md` 第 4 节：`tests/e2e`、`tests/performance`、`tests/contract`、`tests/fixtures`。
- Playwright 已安装；k6 已安装；miniprogram-automator 依赖微信开发者工具 CLI。
- 契约测试默认 **Spring Cloud Contract**（服务端契约），前端配合 stub 验证。

## 工作流（分阶段，带门禁）

### 阶段 1：P0 场景清单（门禁 G0）

维护 `tests/e2e/p0-scenarios.md`（模板见 [`reference/p0-scenarios.md`](reference/p0-scenarios.md)）。
**G0**：P0 清单无"未自动化"场景；新增功能同步登记 P0 场景。

### 阶段 2：Playwright E2E（门禁 G1）

```ts
// tests/e2e/orders/order-submit.spec.ts
import { test, expect } from '@playwright/test';
test('P0-ORDER-01 客户下单生成工单', async ({ page }) => {
  await page.goto('/customer/orders');
  await page.getByRole('button', { name: '新建订单' }).click();
  await page.getByLabel('数量').fill('1000');
  await page.getByRole('button', { name: '提交' }).click();
  await expect(page.getByText('下单成功')).toBeVisible();
});
```

运行：

```bash
pnpm --filter e2e playwright test
# 生成 HTML 报告
pnpm --filter e2e playwright show-report
```

**G1**：P0 场景 100% 自动化且 CI 全绿；失败即阻塞发布。

### 阶段 3：契约测试（门禁 G2）

后端从服务端生成契约与 stub，前端用 stub 跑契约验证：

```bash
# 后端生成 stub
./gradlew :erp-server:verifierStubsJar
# 前端契约验证（消费端）
pnpm --filter customer-portal test:contract
```

**G2**：契约漂移 = 阻塞；任何 DTO 变更必须同步契约并重新验证（与 [wolf-api-contract](../wolf-api-contract/SKILL.md) 联动）。

### 阶段 4：性能测试（门禁 G3）

k6 脚本（查询类接口）：

```js
import http from 'k6/http';
import { check } from 'k6';
export const options = {
  thresholds: {
    http_req_duration: ['p(95)<500'], // 查询 < 500ms
    http_req_failed: ['rate<0.01'],
  },
};
export default function () {
  const res = http.get('http://localhost:8080/api/v1/orders?page=1&size=20');
  check(res, { 'status 200': (r) => r.status === 200 });
}
```

运行：`k6 run tests/performance/orders-query.js`。
复杂报表/批处理用 JMeter（阈值 P95 < 2s）。**G3**：阈值达标 0 违反。

### 阶段 5：小程序自动化（门禁 G4）

用 miniprogram-automator 驱动微信开发者工具：

```js
const automator = require('miniprogram-automator');
automator.launch({ cliPath: 'path/to/cli', projectPath: 'apps/customer-mini' })
  .then(async (miniProgram) => {
    const page = await miniProgram.reLaunch('/pages/orders/index');
    await page.waitFor(1000);
    // 断言元素、触发下单事件
  })
  .finally(() => automator.close());
```

**G4**：客户侧小程序 P0 场景自动化通过（覆盖下单/查进度/验货/对账）。

### 阶段 6：报告与失败处置（门禁 G5）

- 报告归档：Playwright HTML report、k6 JSON summary、契约 verify 日志、小程序截图。
- 失败处置：flaky 用例限期修复；真实失败阻塞 PR；性能回退定位到 commit 并回滚。

**G5**：报告可回溯，每个失败有 owner 与期限。

## 产物

- `tests/e2e/p0-scenarios.md` + Playwright 用例。
- `tests/contract/` 契约定义与验证脚本。
- `tests/performance/*.js` k6 脚本 + 阈值配置（报表用 JMeter `.jmx`）。
- 小程序自动化脚本；测试报告与失败处置记录。

## 校验

- `pnpm playwright test` 全绿；P0 清单 100% 自动化。
- 契约 verify 通过；`./gradlew verifierStubsJar` 生成成功。
- `k6 run` 阈值 0 违反；报告归档、失败有 owner 与期限。

## 常见失败与处置

| 现象 | 处置 |
| --- | --- |
| E2E 偶发失败（flaky） | 用 `retries` 区分 flaky 与真失败；定位时序问题，禁止无限重试掩盖。 |
| 契约验证失败 | 以服务端契约为准，更新前端 stub 或后端契约；禁止前端改 stub 绕过。 |
| k6 阈值超限 | 定位慢查询/缺索引，优化后重跑；性能回退记入 ADR。 |
| 小程序 automator 连不上 | 检查微信开发者工具「服务端口」开启、CLI 路径与版本匹配。 |
| 测试数据污染 | 每个 P0 场景用独立 fixture + 前后清理，禁用共享可变数据。 |

## 验收清单

- [ ] P0 场景清单完整，E2E 100% 自动化，CI 全绿。
- [ ] 契约漂移 0，性能阈值 0 违反，小程序 P0 自动化通过。
- [ ] 报告归档，失败可追溯（owner + 期限）。
