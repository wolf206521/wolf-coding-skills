# 错误码规范（Error Codes）

## 总则

- HTTP 状态码表达语义（4xx 客户端、5xx 服务端），`code` 表达业务错误，`traceId` 用于全链路定位。
- 错误体统一结构（定义于 OpenAPI `components/responses/Error`）：

```json
{
  "code": "ORDER_ALREADY_SUBMITTED",
  "message": "订单已提交，不能重复提交",
  "traceId": "1a2b3c4d5e6f",
  "details": []
}
```

## code 命名

`<MODULE>_<ERROR>`，全大写蛇形。模块与 `_conventions.md` 第 4 节一致：

`QUOTATION`、`ORDER`、`PREPRESS`、`CRAFT`、`APS`、`PRODUCTION`、`MATERIAL`、`SUPPLIER`、
`OUTSOURCING`、`QUALITY`、`WAREHOUSE`、`FINANCE`、`CRM`、`IAM`、`TENANT`、`AUDIT`、`INTEGRATION`、`AI`。

通用（无模块前缀）错误码：

| HTTP | code | 说明 |
| --- | --- | --- |
| 400 | `BAD_REQUEST` | 参数校验失败，`details` 给字段级错误 |
| 401 | `UNAUTHORIZED` | 未认证 / token 失效 |
| 403 | `FORBIDDEN` | 已认证但无权限（含跨合作方越权） |
| 404 | `NOT_FOUND` | 资源不存在 |
| 409 | `CONFLICT` | 状态冲突 / 并发冲突 |
| 422 | `UNPROCESSABLE_ENTITY` | 语义正确但业务不可处理 |
| 429 | `RATE_LIMITED` | 触发限流 |
| 500 | `INTERNAL_ERROR` | 未捕获异常（不暴露堆栈） |

## 字段级校验 details

`details` 为数组，元素结构：`{ "field": "quantity", "reason": "必须为正整数" }`。
前端可据此定位到具体表单控件。

## 约束

- `message` 面向使用者，中文可读；**不得泄露 SQL、堆栈、内部路径、供应商价格**。
- 新增错误码先更新 OpenAPI 规范（`components/responses/Error`）再实现，禁止实现先行。
- 错误码不可变：已发布的 code 不允许改名或改语义，只能新增（破坏性变更检查会拦截）。
