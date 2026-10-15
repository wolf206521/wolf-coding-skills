# Monorepo 脚手架模板

本目录是**目标项目（示例 P-ERP）**的 Monorepo 脚手架模板，配合技能 `wolf-monorepo-scaffold` 使用。

## 复制并初始化

```powershell
# 1. 复制模板到目标目录
Copy-Item -Recurse .\templates\monorepo\* D:\p-erp\

# 2. 安装依赖
cd D:\p-erp
pnpm install

# 3. 按需新增 app / package（见下）
```

## 目录约定（与 docs/_conventions.md 第 4 节一致）

```
p-erp/
├── apps/
│   ├── erp-console/        # ERP 后台（Web/PC，React+Vite+AntD Pro）
│   ├── customer-portal/    # 客户侧（Web + H5）
│   ├── customer-mini/      # 客户侧微信小程序（Taro）
│   ├── supplier-portal/    # 供应商侧
│   └── outsourcing-portal/ # 外协侧
├── packages/
│   ├── portal-core/        # 协同三端共享内核（认证/权限/请求/领域类型/骨架）
│   ├── api-client/         # 由 OpenAPI 自动生成，禁止手写
│   ├── domain-types/       # 跨端共享 TS 类型
│   ├── ui-tokens/          # 设计令牌
│   └── business-rules/     # 可复用纯函数业务规则（报价试算/损耗计算）
└── ...（根配置见本目录）
```

## 新增 app / package 的标准步骤

1. 在 `apps/` 或 `packages/` 下创建目录与 `package.json`（`name` 用 `@wolf/<name>` 作用域）。
2. `tsconfig.json` 继承 `../../tsconfig.base.json`。
3. 若需被其它包依赖，在 `package.json` 声明 `exports`。
4. 运行 `pnpm install` 使 workspace 链接生效。
5. 若涉及 API，在 `apps/*` 中 `devDependencies` 加 `@wolf/api-client: workspace:*`，运行 `pnpm gen:client` 生成。

## 各 app 技术栈速览

| app | 栈 |
| --- | --- |
| erp-console | React 18 + Vite 5 + Ant Design 5 + ProComponents + TanStack Query |
| customer-portal / supplier-portal / outsourcing-portal | React 18 + Vite 5 + Ant Design 5 + Ant Design Mobile，依赖 `portal-core` |
| customer-mini | Taro 4（React）+ NutUI-React |

## 占位说明

本模板仅提供骨架与关键配置，不含业务源码。业务代码按 `wolf-project-kickoff → wolf-domain-modeling → wolf-api-contract → wolf-tdd-loop` 流程逐步填充。
