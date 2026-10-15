---
name: wolf-api-contract
description: "Design APIs contract-first: write an OpenAPI 3.1 spec, generate TypeScript and Java clients from it, and enforce breaking-change checks. Use when adding or changing an endpoint, DTO, or cross-app data contract. Do not use for frontend-only styling or internal refactors with no interface change."
---

# 契约优先 API 开发

以 OpenAPI 3.1 为**单一事实源**：先定契约 → 再生成前后端客户端 → 最后实现。
禁止手写前端请求类型，禁止前后端各自维护一份 DTO（口径漂移即缺陷）。
技术栈与命名以 [`../../docs/_conventions.md`](../../docs/_conventions.md) 第 2、4 节为准。

## 何时使用

- 新增或变更 HTTP 接口、DTO、枚举、错误码。
- 跨应用/跨端数据契约（ERP 后台、协同三端、小程序、AI 服务）。
- 前后端接口对齐、OpenAPI 文档与客户端代码再生。

不适用于：纯前端样式调整、无接口变更的内部重构（方法重命名、内部类拆分）。

## 前置条件

- 目标项目按 `_conventions.md` 选型：Java 21 + Spring Boot 3.3（后端）、React 18 + TS 5.5（前端）。
- Node/pnpm 环境；`openapi-typescript`（类型）或 `orval`（带请求函数 client）已加入 `packages/api-client`。
- Maven/Gradle 环境；`openapi-generator-maven-plugin`（Java client，跨服务对接时用）。
- 契约目录：`services/erp-server/src/main/resources/openapi/{module}.yaml`。

## 工作流（分阶段，带门禁）

### 阶段 0：确认契约范围

1. 确认接口归属领域模块（`quotation`、`order`、`crm` …），路径统一 `/api/v1/{domain}/{resource}`，资源复数。
2. 动作型接口用子资源：`POST /api/v1/orders/{id}/submit`；查询分页统一 `page`/`size`/`sort` 参数。
3. 涉及跨端数据时确认脱敏策略：价格/成本对协同端在 DTO 层裁剪，见 `_conventions.md` 第 5 节。

### 阶段 1：编写/修改 OpenAPI 3.1 规范

文件放 `services/erp-server/src/main/resources/openapi/{module}.yaml`。规范要点：

- 固定 `openapi: 3.1.0`（支持 `type: [string, "null"]` 等 3.1 语法）。
- 每个 schema/字段必须有 `description`；枚举给全 `enum` 值并说明含义。
- 请求/响应 DTO 用 `components/schemas`，**禁止内联匿名对象**。
- 错误响应统一引用 `components/responses/Error`（结构见 `reference/error-codes.md`）。
- 时间字段 `format: date-time`（UTC）；货币用 `integer`（单位：分）或 `string`（decimal），**禁止 `float`/`double` 表示金额**。
- `operationId` 全局唯一、动词+资源（`createOrder`、`submitOrder`），它是生成函数名的依据。
- `servers` 只写相对路径或环境变量注入，不写死内网 IP/域名。

示例片段：

```yaml
openapi: 3.1.0
info:
  title: erp-order
  version: 1.0.0
paths:
  /api/v1/orders:
    post:
      summary: 创建销售订单
      operationId: createOrder
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/CreateOrderRequest' }
      responses:
        '201': { $ref: '#/components/responses/OrderCreated' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '409': { $ref: '#/components/responses/Conflict' }
```

### 阶段 2：规范校验（门禁 G1）

```bash
# 结构/规则校验
npx @redocly/cli lint openapi/order.yaml
# 或
openapi-generator validate -i openapi/order.yaml
```

**G1 通过条件**：0 error；`operationId` 唯一；所有 `$ref` 可解析；写接口覆盖 400/401/403/409/422/500，查询覆盖 404。

### 阶段 3：生成客户端（门禁 G2）

TS client（`packages/api-client`，禁止手写）：

```bash
# openapi-typescript：纯类型
pnpm -F api-client exec openapi-typescript \
  ../../services/erp-server/src/main/resources/openapi/order.yaml \
  -o src/generated/order.d.ts
# orval：带请求函数 client（配置见 orval.config.ts）
pnpm -F api-client run orval
```

Java client（跨服务/外部对接时生成）：

```xml
<plugin>
  <groupId>org.openapitools</groupId>
  <artifactId>openapi-generator-maven-plugin</artifactId>
  <configuration>
    <generatorName>java</generatorName>
    <library>webclient</library>
    <inputSpec>${project.basedir}/src/main/resources/openapi/order.yaml</inputSpec>
  </configuration>
</plugin>
```

**G2 通过条件**：生成产物编译通过；生成目录纳入 `.gitignore` 或在 CI 强制"生成物与规范一致"（重新生成后 `git diff --exit-code`）。

### 阶段 4：破坏性变更检查（门禁 G3）

仅修改既有契约时执行，对照旧规范做 diff：

```bash
npx @openapitools/oasdiff breaking old/order.yaml new/order.yaml
```

**G3 通过条件**：`breaking` 类差异 = 0。以下视为破坏性变更，须走新增 `/api/v2` 或协商兼容：

- 删除/重命名字段、路径、`operationId`。
- 修改字段类型、收缩 `enum`、把必填改可选（影响消费方判空）。
- 修改错误码语义、收紧鉴权要求。

非破坏性（允许直接改）：新增可选字段、新增路径/`enum` 值、放宽响应约束。

### 阶段 5：实现与对齐（门禁 G4）

1. 后端实现 Controller/DTO：路由、状态码、错误体与规范逐项一致。
2. 前端调用 `packages/api-client` 生成物，禁止手写 `fetch`/`axios` 请求函数绕过类型。
3. 契约测试纳入 CI（见 [wolf-test-automation](../wolf-test-automation/SKILL.md) 契约测试节）。

**G4 通过条件**：后端集成测试覆盖该接口；前端 `tsc --noEmit` 无 `any` 逃逸；契约测试通过。

### 版本策略（/api/v1）

- 首个稳定版本挂 `/api/v1`；破坏性变更不升 v1，而是新增 `/api/v2`，v1 保留兼容期（≥ 2 个 Sprint）。
- 兼容期内 v1 只修 bug、不加新功能；废弃接口在规范加 `deprecated: true` 并写迁移说明。
- 每个 `/api/v{n}` 对应一份独立 OpenAPI 文件与生成物，禁止混版本复用 DTO。

## 产物

- `openapi/{module}.yaml`：单一事实源规范。
- `packages/api-client/src/generated/`：TS 类型/client（生成物）。
- Java client 模块（如需要）。
- 更新后的错误码表（见 [`reference/error-codes.md`](reference/error-codes.md)）。

## 校验

- `npx @redocly/cli lint` 0 error；`oasdiff breaking` 0 breaking。
- CI 执行"生成物一致性"：生成后 `git diff --exit-code` 为 0。
- 前端 `tsc --noEmit` 通过，无 `any`。

## 常见失败与处置

| 现象 | 处置 |
| --- | --- |
| 生成物漂移（有人手工改了生成文件） | 删除手写改动，回写规范重新生成；生成目录加 lint 豁免，勿手工编辑。 |
| `oasdiff` 报 breaking | 非必需则回退变更；必需则走 `/api/v2` 并保留 v1 兼容期。 |
| 前后端 DTO 字段不一致 | 规范是唯一来源；禁止后端 `@JsonIgnore` 偷偷裁剪——裁剪要在 DTO 层且写进规范。 |
| 金额用 float 精度丢失 | 改为 `integer`(分) 或 `string`(decimal)，全链路统一。 |
| 生成 Java client 编译失败 | 检查 `library=webclient` 与 Spring Boot 3.3 匹配，升级 openapi-generator 插件版本。 |

## 验收清单

- [ ] 规范文件为唯一事实源，前后端均无手写请求类型。
- [ ] `operationId` 唯一，所有 schema 有 `description`，金额非 float/double。
- [ ] 门禁 G1~G4 全部通过，破坏性变更检查 0 breaking。
- [ ] 错误码符合 [`reference/error-codes.md`](reference/error-codes.md)。
