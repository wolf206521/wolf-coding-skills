---
name: wolf-release-versioning
description: Manage releases and versioning: Conventional Commits, Changesets per-app SemVer, changelog generation, git tagging, release branches, database Expand/Contract migrations, and rollback. Use when cutting a release or defining version policy. Do not use for in-progress feature work.
---

# 发布与版本管理

统一"提交 → 变更集 → 版本号 → 标签 → 迁移 → 回滚"全链路，保证制品可追溯、可回滚。对齐 [`../docs/_conventions.md`](../../docs/_conventions.md) 第 3 节：Trunk-based + 短分支、Conventional Commits、Changesets 按端独立 SemVer、`<app>@<version>` 注解标签、Expand/Contract 迁移。部署动作由 `../wolf-cicd-deploy` 承接，本技能只定"版本怎么切、迁移怎么滚"。

## 何时使用

| 触发场景 | 动作 |
| --- | --- |
| 切一个版本/发布窗口 | 阶段 3 打标签 + 发版 |
| 定义/调整版本策略 | 阶段 1 |
| 数据库加列/改列/删列 | 阶段 5 Expand/Contract |
| 上线出问题要回滚 | 阶段 6 |
| 进行中的功能开发（未到发布点） | **不使用本技能** |

## 前置条件

- 分支保护已启用：`main` 禁止直接 push，PR 必须过全部门禁（见 `wolf-cicd-deploy`）。
- 已安装 Changesets（pnpm Monorepo）与 `release-please`（可选）。
- 提交信息遵循 Conventional Commits（CI 强制校验）。

## 工作流（分阶段，带门禁）

### 阶段 1：版本策略与分支模型

**分支模型**：`main`（永远可发布）+ `feat/*` `fix/*` `hotfix/*`（≤ 3 天）+ `release/x.y`（仅 LTS 维护）。**版本策略**：SemVer 2.0.0，按端独立版本号：

| 端 | 版本号示例 | 由谁管理 |
| --- | --- | --- |
| `erp-console`（前端） | `erp-console@1.4.0` | Changesets（单仓多包） |
| `backend`（erp-server） | `backend@1.4.2` | Changesets |
| `ai-service` | `ai-service@0.9.1` | Changesets |

SemVer 规则：`MAJOR.MINOR.PATCH`——破坏性 API 变更升 MAJOR，向后兼容新功能升 MINOR，修复升 PATCH；`0.x` 视为不稳定。

- **门禁 G1（策略落地）**：分支保护开启；每个可部署端都有独立的版本历史；`main` 无直接 push。

### 阶段 2：Conventional Commits

提交格式 `type(scope): subject`，`type ∈ feat|fix|docs|refactor|perf|test|build|ci|chore|revert`。CI 用 `commitlint` 强制：

```bash
# commitlint.config.cjs
module.exports = { extends: ['@commitlint/config-conventional'] };
# husky pre-commit / CI job
npx commitlint --from HEAD~1 --to HEAD
```

破坏性变更用 `feat(scope)!:` 或正文 `BREAKING CHANGE:`，会触发 MAJOR。

- **门禁 G2（提交规范）**：不合规提交被 CI 拦截；`BREAKING CHANGE` 与 MAJOR 版本升位一一对应。

### 阶段 3：Changesets 按端 SemVer + CHANGELOG

开发时每次变更补一个 changeset（`.changeset/*.md`），发布时由 Changesets 汇总：

```bash
pnpm changeset          # 选择影响的包 + 变更类型（patch/minor/major）+ 说明
pnpm changeset version  # 计算并写入各包新版本号 + 生成 CHANGELOG.md
pnpm changeset tag      # 打标签 <pkg>@<version>（如 backend@1.4.2）
```

`CHANGELOG.md` 由 changeset 自动汇总生成（按版本倒序：New Features / Bug Fixes / Breaking Changes）。发布说明由 commit 自动汇总，不再手写。

- **门禁 G3（版本可追溯）**：`package.json` 各端版本号与 CHANGELOG、git 标签一致；标签为**注解标签**（`git tag -a backend@1.4.2 -m "..."`）；镜像 tag 与 Helm chart version 均等于该标签（见 `wolf-cicd-deploy`）。

### 阶段 4：打标签与发布（release-please 可选）

两种方式：**Changesets 打标签**（上一步）或 **release-please**（基于 Conventional Commits 自动提 Release PR、自动 bump、自动生成 CHANGELOG 与 tag）。发布节奏：双周迭代，每周三发布窗口；hotfix 随时，**24h 内回灌 `main`**：

```bash
# hotfix 流程
git checkout -b hotfix/backend-1.4.3 main
# ... 修复 + 测试 ...
git checkout main && git merge --no-ff hotfix/backend-1.4.3
git push origin main
pnpm changeset tag && git push --tags
```

- **门禁 G4（发布干净）**：发布标签与 `build-info.json`（commit SHA + 构建号 + SBOM + 签名）一致；hotfix 24h 内回灌 `main` 且 `main` 始终可发布。

### 阶段 5：数据库 Expand/Contract 迁移（向前兼容）

原则：**迁移必须可回滚 = 新旧两个版本能并存**。分三阶段，禁止一步到位删除/改名：

```
Expand   ：只加不改（新列/新表，旧版本代码无感知）
Contract ：代码同时读写新旧，切流量后旧版本停用
Cleanup  ：确认无旧版本实例后，再删旧列/旧表
```

示例：把 `orders.customer` 改名/迁移到 `orders.customer_id`：

```sql
-- Expand（阶段1，可安全上线，旧版本不感知）
ALTER TABLE sales_orders ADD COLUMN customer_id BIGINT;
-- 双写（应用层：写入时同时写 customer 与 customer_id，或触发器回填）
-- Contract（阶段2，读优先新列，验证无差异后旧列只读）
-- Cleanup（阶段3，全量确认后）
ALTER TABLE sales_orders DROP COLUMN customer;
```

完整三阶段剧本见 [`reference/expand-contract-playbook.md`](./reference/expand-contract-playbook.md)。

- **门禁 G5（迁移可回滚）**：每个迁移都有 Expand/Contract 三阶段计划；任一步骤失败都能回退到上一阶段；禁止在同一次发布里"加列又删列"。

### 阶段 6：回滚流程

**回滚 = 切回上一镜像 tag**（镜像不可变 + 数据库向前兼容，无需回滚数据库）：

1. 定级：功能 bug → 向前修复（打 hotfix）；数据/严重故障 → 回滚。
2. 切回上一版本镜像 tag（见 `wolf-cicd-deploy` 阶段 6 的一键回滚命令）。
3. 若迁移处于 Contract 阶段，回滚后旧版本仍可读新列（因为 Expand 已保证兼容）。
4. 回滚记录写 `docs/rollback.log`（时间、版本、原因、恢复耗时）。

- **门禁 G6（回滚可用）**：每个发布都声明"可回滚版本"；季度回滚演练；回滚不触发数据库逆向迁移。

## 产物

- 分支保护 + commitlint 配置 + Changesets/release-please 配置。
- 各端 `CHANGELOG.md` + 注解标签 `<app>@<version>` + `build-info.json`。
- Expand/Contract 迁移脚本（`services/erp-server/src/main/resources/db/migration/`）。
- 回滚日志与季度演练记录。

## 校验

- [ ] `git tag -l` 中每个可部署端都有对应 `<app>@<version>` 注解标签。
- [ ] `package.json` 版本号、CHANGELOG、镜像 tag、Helm chart version 四者一致。
- [ ] 所有数据库迁移均有 Expand/Contract 三阶段脚本，无一步到位的破坏性 DDL。
- [ ] 一次回滚演练实际执行，回滚日志完整。

## 常见失败与处置

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| 版本号与镜像 tag 对不上 | 手工 bump 或漏打 tag | 只用 Changesets/release-please 单点 bump |
| CHANGELOG 为空/乱序 | 未写 changeset、commit 不规范 | 每次变更补 changeset；commitlint 强制 |
| `main` 不可发布 | hotfix 未回灌、功能合入未完成 | 短分支 ≤3 天 + hotfix 24h 回灌 |
| 迁移后回滚报错 | 一步到位删列/改名 | 严格 Expand/Contract 三阶段 |
| 破坏性变更误升 MINOR | 未写 `BREAKING CHANGE` | commitlint + changeset 提示选择 major |

---

## 验收清单

- [ ] 阶段 1–6 走通，六道门禁（G1–G6）有通过记录。
- [ ] 分支模型 + Conventional Commits + Changesets 全链路自动，`main` 无直接 push。
- [ ] 版本号/CHANGELOG/标签/镜像四者一致，可追溯。
- [ ] 所有数据库迁移 Expand/Contract 化，回滚演练通过。
