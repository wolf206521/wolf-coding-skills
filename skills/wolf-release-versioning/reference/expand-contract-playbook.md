# Expand/Contract 迁移剧本（细节参考）

> 承载 `SKILL.md` 阶段 5 的三阶段完整剧本，含回滚判定。核心口诀：**Expand 只加、Contract 双写双读、Cleanup 后删**。

## 1. 三类常见迁移模板

### 1.1 加列（最安全）

```sql
-- Expand：加可空列 + 默认值，旧版本无感知
ALTER TABLE sales_orders ADD COLUMN urgent BOOLEAN NOT NULL DEFAULT false;
```
无需 Contract/Cleanup（没有旧结构要删）。

### 1.2 改列（重命名/改类型）

```sql
-- Expand：加新列
ALTER TABLE sales_orders ADD COLUMN customer_id BIGINT;
```
应用层双写（写入同时写 `customer` 与 `customer_id`）；触发器回填存量：

```sql
-- 回填存量（分批，避免长事务）
UPDATE sales_orders SET customer_id = customer WHERE customer_id IS NULL AND id BETWEEN ? AND ?;
```
- Contract：读优先 `customer_id`，差异对账为 0 后，旧列 `customer` 只读。
- Cleanup：确认无旧版本实例后 `ALTER TABLE sales_orders DROP COLUMN customer;`

### 1.3 删列/删表

先走"置为废弃 → 停止写入 → 观察 → 删除"，绝不一步删除：

```sql
-- 第 N 版：标记废弃，应用停止写入（Expand 阶段可先只加新结构）
-- 第 N+1 版：Cleanup 删除，需确认无读取
ALTER TABLE sales_orders DROP COLUMN legacy_flag;
```

## 2. 回滚判定表

| 当前处于 | 回滚动作 | 是否需回滚数据库 |
| --- | --- | --- |
| Expand 后 | 切回上一镜像 | 否（新列对新旧都无影响） |
| Contract 双写中 | 切回上一镜像 | 否（旧版本仍可读旧列） |
| Cleanup 后 | 切回上一镜像 | **否，但旧列已删，旧版本可能失效** → Cleanup 前必须确认无旧版本 |

## 3. 迁移工具约定

- 后端用 Flyway（`db/migration/V<序号>__<描述>.sql`），版本号单调递增。
- 每次迁移 = 一个独立文件，禁止改历史已应用过的迁移文件（否则校验和冲突）。
- 迁移脚本在 CI 的集成测试（Testcontainers）中自动执行，保证可复现。

```sql
-- V2026_01_14_01__add_customer_id.sql
ALTER TABLE sales_orders ADD COLUMN customer_id BIGINT;
```

## 4. 验收

- [ ] 每个迁移都有三阶段脚本或"无需 Contract/Cleanup"的显式说明。
- [ ] 迁移脚本在 Testcontainers 集成测试中自动执行并回放通过。
- [ ] 回滚时无需逆向数据库变更。
