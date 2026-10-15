# 产出模板（Plan / Task / Agent）

## 需求条目模板

```markdown
### REQ-ORDER-001 销售订单提交
- 用户故事：作为业务员，我要提交销售订单，以便触发后续工艺与排产。
- 验收标准（Given/When/Then）：
  - Given 订单草稿已填齐 When 业务员点击提交 Then 订单状态变为 submitted 且产生 `order.sales-order.submitted` 事件。
  - Given 必填项缺失 When 提交 Then 返回字段级错误且不产生事件。
- 来源：<外部文档路径>#<页码/图编号>
- 依赖：REQ-IAM-001（登录鉴权）
- 被依赖：REQ-CRAFT-001（工艺卡生成）
- 优先级：P0 | 风险：中 | 状态：[待外部确认] / 已确认
```

## 计划与 DoD 模板

```markdown
# <项目> 计划
- 范围（in-scope）：…
- 范围外（out-of-scope）：…
- 里程碑：M0 骨架 / M1 核心域 / M2 协同 …（对齐 master-plan §12）
- DoD（对齐 _conventions.md §2.4）：
  - 后端单测行覆盖 ≥ 70%，核心域 ≥ 85%
  - 契约测试通过，契约漂移 = 阻塞
  - 高危安全漏洞 = 0
  - P0 E2E 全绿
```

## 任务拆解模板

```markdown
| ID | 任务 | 依赖 | 产出物 | 校验方式 | 估时(天) |
| --- | --- | --- | --- | --- | --- |
| T1 | 冻结 domain-types | 无 | packages/domain-types | 类型编译 + 契约对齐 | 0.5 |
| T2 | 生成 api-client | T1 | packages/api-client | 生成脚本可重复执行 | 0.5 |
| T3 | 订单提交用例 | T2 | erp-server order 模块 | 单测+集成绿 | 1 |
```

## 子 Agent 分工模板

```markdown
### Agent-A：报价引擎方案
- 输入：REQ-QUOTATION-*、_conventions.md §2.2/§2.3
- 产出：报价规则表 + 方案 ADR
- 边界：只出方案，不写实现
```
