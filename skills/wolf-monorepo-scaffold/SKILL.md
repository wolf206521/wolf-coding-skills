---
name: wolf-monorepo-scaffold
description: "Generate a pnpm+Turborepo multi-app monorepo (web/admin/portal/WeChat mini-program) with shared packages, TypeScript, Vite, Taro, ESLint/Prettier, and CI wiring. Use when creating a new multi-app project or adding a new app/package. Do not use to modify business logic inside an existing app."
---

# Monorepo 脚手架（Wolf Monorepo Scaffold）

生成 pnpm 9 + Turborepo 2 的多应用 monorepo（Web 后台 / 协同门户 / 微信小程序），含共享 packages、TypeScript 5.5、Vite 5、Taro 4、ESLint/Prettier 与 CI 占位。**本技能描述"如何生成"，具体模板文件在 `D:\wolf-coding-skills\templates`（本仓库根目录，相对本文件为 `../../templates`），生成时读取该目录，不在本技能里粘贴大段模板。**

## 何时使用

- 创建新的多应用项目，或向现有 monorepo 新增一个 app / package。
- 需要统一 pnpm workspace、Turborepo 任务编排、ESLint/Prettier、CI 骨架。

**不用于**：修改已有 app 内部的业务逻辑（那是开发类技能的事）。

## 前置条件

- 已读取 `_conventions.md` 第 2.3/4 节（前端选型、目录与命名）与 `00-master-plan.md` 第 2 节（门户拆分）。
- 本机有 pnpm 9 + Node 20+（用 `corepack` 或团队基线锁定版本）。
- 已确认目录结构以 `_conventions.md` §4 为准（`apps/` + `packages/` + `tests/` + `.github/`）。

## 工作流（分阶段，带门禁）

### 阶段 0：读取模板并确定目标

1. 读取 `D:\wolf-coding-skills\templates\` 下现有模板清单（`monorepo/`、`app-web/`、`app-taro/`、`package/`、`ci/` 等子目录）。
2. 确定目标：整仓生成，还是增量新增 app/package。
3. 确定 app 清单：`erp-console`（Web/PC）、`customer-portal`、`supplier-portal`、`outsourcing-portal`（Web + H5）、`customer-mini`（Taro 小程序），对齐 §1 门户拆分。

**门禁 Gate 0**：模板目录存在且可读；app 清单与 `_conventions.md` §1 一致。

### 阶段 1：生成根骨架

产出根级文件：

- `pnpm-workspace.yaml`：声明 `apps/*` 与 `packages/*`。
- `turbo.json`：定义 `build / dev / lint / test / typecheck` 任务与依赖关系（如 `build` 依赖 `^build`）。
- 根 `package.json`：`packageManager` 锁定 pnpm，脚本 `dev/build/lint/test` 转发 turbo。
- `.npmrc`、`.gitignore`、ESLint/Prettier 根配置（共享到各包）。
- `.github/workflows/ci.yml` 占位：`lint → typecheck → test → build` 阶段骨架（细节由 `wolf-cicd-deploy` 补全）。

关键配置骨架（以 `D:\wolf-coding-skills\templates\monorepo` 为准，此处仅示意）：

```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*"
  - "packages/*"
```

```jsonc
// turbo.json（示意）
{
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "lint": { "dependsOn": ["^lint"] },
    "typecheck": { "dependsOn": ["^typecheck"] },
    "test": { "dependsOn": ["^test"] }
  }
}
```

**门禁 Gate 1**：`pnpm install` 成功；`pnpm turbo run build` 空跑通过（尚无 app 时）。

### 阶段 2：生成 packages 与 apps

按 `_conventions.md` §4 生成：

- `packages/portal-core`（协同三端共享内核：认证/权限/请求/领域类型/UI 骨架）。
- `packages/api-client`（OpenAPI 生成的 client，**占位 + 生成脚本**，禁止手写类型）。
- `packages/domain-types`、`business-rules`、`ui-tokens`、`utils`。
- `apps/erp-console`（Vite + React 18 + Ant Design 5 + ProComponents + Refine/CRUD 引擎）。
- `apps/customer-portal` / `supplier-portal` / `outsourcing-portal`（Vite + React + Ant Design Mobile）。
- `apps/customer-mini`（Taro 4 + React + NutUI-React）。

每个 app/package 含：`package.json`（workspace 依赖用 `workspace:*`）、`tsconfig.json`、ESLint/Prettier 配置继承根、最小 `src/` 与构建配置。

目标目录结构（对齐 `_conventions.md` §4，完整树以 `templates/` 为准）：

```text
<project>/
├── apps/{erp-console, customer-portal, supplier-portal, outsourcing-portal, customer-mini}
├── packages/{portal-core, api-client, domain-types, business-rules, ui-tokens, utils}
├── tests/{e2e, performance, contract, fixtures}
├── .github/workflows/ci.yml
├── pnpm-workspace.yaml · turbo.json · package.json · .npmrc · .gitignore
```

**门禁 Gate 2**：`pnpm install` 后各包 `lint`/`typecheck`/`build` 通过；跨包引用 `workspace:*` 解析正确。

### 阶段 3：新增 app / package（增量标准步骤）

1. 复制对应模板目录到目标路径（app 用 `app-web/` 或 `app-taro/`，包用 `package/`）。
2. 改 `name`（kebab-case，`@wolf/<name>` 作用域可选）、目录名、`turbo.json` 无需改（通配已覆盖）。
3. 声明依赖：用 `pnpm --filter <target> add <dep> --workspace` 添加 workspace 依赖。
4. 跑 `pnpm turbo run build --filter=<target>` 验证；提交时走 Conventional Commits（`feat(scope): ...`）。

命令示例：

```bash
# 新增一个 Web app
cp -r D:/wolf-coding-skills/templates/app-web apps/supplier-portal
# 改 package.json name 后装依赖并验证
pnpm install
pnpm --filter supplier-portal add @wolf/portal-core --workspace
pnpm turbo run build --filter=supplier-portal
```

**门禁 Gate 3**：新 app/package 命名符合 §4 规范；`turbo run build` 全绿；无手写 OpenAPI 类型（只用 `api-client` 生成）。

## 产物

| 产物 | 位置 | 说明 |
| --- | --- | --- |
| 根骨架 | `pnpm-workspace.yaml` / `turbo.json` / `package.json` / `.npmrc` / `.gitignore` | 任务编排与 workspace |
| Lint/Format | 根 ESLint + Prettier 配置 | 各包继承 |
| apps | `apps/<name>` | 5 个应用（按需） |
| packages | `packages/<name>` | 6 个共享包（含 api-client 占位） |
| CI 占位 | `.github/workflows/ci.yml` | lint → typecheck → test → build |
| 生成脚本 | `scripts/`（可选） | 一键生成/新增的可复用脚本 |

命名规范（对齐 `_conventions.md` §4）：

| 类型 | 规则 | 示例 |
| --- | --- | --- |
| app/package 目录 | kebab-case | `erp-console`、`portal-core`、`api-client` |
| package `name` | kebab-case，可加 `@wolf/` 作用域 | `@wolf/portal-core` |
| TS 组件 | PascalCase.tsx | `OrderList.tsx` |
| hook | useXxx.ts | `useAuth.ts` |
| 工具 | kebab-case.ts | `format-money.ts` |

模板源：`D:\wolf-coding-skills\templates\`（相对 `../../templates`）。

## 校验

- [ ] `pnpm install` 与 `pnpm turbo run build` 全绿。
- [ ] 目录结构与 `_conventions.md` §4 一致（`apps/` + `packages/` + `tests/` + `.github/`）。
- [ ] 每个 app/package 的 `name` 为 kebab-case，依赖用 `workspace:*`。
- [ ] `api-client` 是生成占位，无手写类型。
- [ ] ESLint/Prettier 在各包生效（`pnpm lint` 通过）。
- [ ] CI 占位工作流包含 lint/typecheck/test/build 阶段。

## 常见失败与处置

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| `pnpm install` 失败 | pnpm 版本不匹配 | 根 `packageManager` 锁定版本，团队统一 `corepack` |
| `workspace:*` 解析不到 | 包名与目录/`pnpm-workspace.yaml` 不一致 | 对齐 kebab-case 包名与 `apps/*`、`packages/*` 通配 |
| turbo 任务互相污染 | 任务依赖未声明 | 在 `turbo.json` 声明 `build` 依赖 `^build`、`lint` 依赖 `^lint` |
| 小程序构建报错 | Taro 版本/配置不对 | 用 `app-taro` 模板重建，核对 Taro 4 + React 18 基线 |
| 手写 OpenAPI 类型漂移 | 绕过 `api-client` | 删除手写类型，改为 `api-client` 生成脚本（对齐契约优先） |
| 新包命名冲突 | 未走增量步骤 | 回阶段 3，按标准步骤复制模板 + 重命名 + 声明依赖 |
