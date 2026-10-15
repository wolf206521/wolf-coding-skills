---
name: wolf-meta-skill-creator
description: Create or improve a Claude/DSH Skill: folder structure, frontmatter name/description, reference/scripts/assets layout, and evaluation for trigger accuracy. Use when the user wants a new reusable skill or to optimize an existing skill's description. Do not use for writing application code.
---

# 技能创建器（元技能）

> ⚠️ **已降级**：上游 `skill-creator`（官方）+ `writing-skills`（TDD 化写作法）已逐字集成，是本仓库的**首选**技能生产工具。本技能保留为 **wolf 品牌包装**（衔接 [`../docs/_conventions.md`](../../docs/_conventions.md) 第 6 节命名与目录规范）。

本仓库的**自我生产能力**：把自然语言需求做成一个可复用、能被 Agent 按 `description` 正确挂载的 Skill。遵循 [`../docs/_conventions.md`](../../docs/_conventions.md) 第 6 节写作规范。本仓库已有技能（[`../wolf-cicd-deploy/SKILL.md`](../wolf-cicd-deploy/SKILL.md)、[`../wolf-observability/SKILL.md`](../wolf-observability/SKILL.md)、[`../wolf-iteration-evolve/SKILL.md`](../wolf-iteration-evolve/SKILL.md)、[`../wolf-release-versioning/SKILL.md`](../wolf-release-versioning/SKILL.md)）是**规范示范**，写新技能前先读 1–2 个参照结构。

## 何时使用

| 触发场景 | 动作 |
| --- | --- |
| 用户想新增一个可复用技能 | 阶段 0–5 全流程 |
| 现有技能 description 触发不准（该挂载没挂/误挂） | 阶段 2 + 阶段 5 |
| 技能太长/结构乱，要重构拆分 | 阶段 3 + 阶段 4 |
| 写业务功能代码 | **不使用本技能** |

## 前置条件

- 已读 `_conventions.md` 第 6 节（frontmatter 格式、正文结构、体积控制）。
- 明确技能要解决的任务边界（做什么、不做什么）。
- 有 1–2 个真实使用场景可做评测样本。

## 工作流（分阶段，带门禁）

### 阶段 0：澄清需求（先问，Karpathy 原则）

动手前先问清 4 件事，缺一不可：

1. **做什么**：一句话描述技能任务（例如"把提交/版本/迁移/回滚串成一条发布流水线"）。
2. **触发词**：用户会怎么说才会用到它？（决定 description 的 "Use when"）
3. **排除项**：哪些场景**不该**用？（决定 "Do not use for"）
4. **是否已有近似技能**：先查 `../skills/` 目录，避免重复造轮子；能并入的就别新建。

- **门禁 G0（边界清晰）**：能写出「做什么 + Use when + Do not use for」三句；已排除与现有技能重叠。

### 阶段 1：设计目录结构

固定布局（`<skills>/<name>/`）：

```
<name>/
├── SKILL.md          # 主入口：≤500 行，正文结构见 _conventions.md 第 6 节
├── reference/        # 细节：长示例、完整配置、手册（避免 SKILL.md 过长）
│   └── *.md
├── scripts/          # 可执行逻辑：shell/py/ps1，SKILL.md 引用并让 Agent 运行
└── assets/           # 模板/资源：被复制到目标项目的脚手架文件
```

拆分原则：**SKILL.md 只留"决策与步骤"，把"长代码/完整配置"下沉到 reference，把"要跑的命令/脚本"下沉到 scripts，把"要落地的模板文件"下沉到 assets**。

- **门禁 G1（结构正确）**：目录名 = `name`（kebab-case）；SKILL.md ≤ 500 行；reference/scripts/assets 只在确有内容时创建，不为空壳。

### 阶段 2：写 frontmatter（name/description 触发优化）

```yaml
---
name: <kebab-case，与目录名一致>
description: <英文 1-3 句：做什么 + "Use when ..." + "Do not use for ...">
---
```

**description 触发准确率优化清单**：

| 检查 | 规则 |
| --- | --- |
| 动词开头 | 用祈使动词（Build / Run / Manage / Instrument / Create），可被动作匹配 |
| Use when 具体 | 列**用户原话**式的触发词（如 "Use when setting up CI/CD"），不是抽象概念 |
| Do not use for | 明确排除混淆场景，降低误挂 |
| 长度 | 1–3 句，不写教程 |
| 唯一性 | 与其它技能 description 无歧义重叠 |

参照本仓库示范：`wolf-cicd-deploy` 用 "Build CI/CD pipelines ... Use when setting up or changing build, release, or deploy automation. Do not use for writing application business code."

description 优化前后对比（触发准确率）：

| 版本 | description | 问题 |
| --- | --- | --- |
| ❌ 差 | "Helps with deployment." | 太抽象、无触发词、无排除项 |
| ✅ 好 | "Build CI/CD pipelines and deployment: GitHub Actions, Docker multi-stage builds, Compose, then Kubernetes/Helm/Argo CD, environment promotion, and rollback. Use when setting up or changing build, release, or deploy automation. Do not use for writing application business code." | 动词开头 + 具体触发词 + 明确排除 |

- **门禁 G2（frontmatter 合法）**：`name` 与目录同名；description 含 "Use when" 与 "Do not use for"；能通过阶段 5 的触发评测。

### 阶段 3：写 SKILL.md 正文

固定结构（与 `_conventions.md` 第 6 节一致）：

```
# 标题
## 何时使用
## 前置条件
## 工作流（分阶段，带门禁）
## 产物
## 校验
## 常见失败与处置
（末尾）## 验收清单
```

写作要点：**中文正文**（代码/命令/标识符保持英文）；每个结论给命令/目录/配置片段，禁止只讲理念；「工作流」拆成**阶段 + 门禁（Gate）**，门禁是客观可判的检查点；「常见失败」用症状→原因→处置三列表。

- **门禁 G3（可执行可验证）**：每个阶段有明确产出；每个门禁有客观判定标准；文末有可勾选「验收清单」。

### 阶段 4：拆分 reference / scripts / assets

按阶段 1 原则执行下沉：长配置/完整示例 → `reference/*.md`；要跑的命令逻辑 → `scripts/*`；要落地到目标项目的文件 → `assets/*`。SKILL.md 用相对链接引用，不复制大段内容。

- **门禁 G4（体积达标）**：SKILL.md 150–500 行；细节在 reference、模板在 assets、可执行逻辑在 scripts；链接无死链。

### 阶段 5：评测与迭代

做**触发准确率 + 输出质量**双重评测：

1. **触发评测**：准备 5–10 个真实用户语句（正例 + 反例），验证 description 是否「该挂则挂、不该挂不挂」。
2. **输出评测**：用技能跑 1 个真实任务，检查产物是否可执行、门禁是否可判。
3. **迭代**：触发不准 → 改 description 的 Use when/Do not use for；产物冗余/缺失 → 调阶段 3/4 拆分。

评测样本示例（正例命中 / 反例排除，记录到 `docs/skill-eval.md`）：

| 用户语句 | 期望 | 结果 |
| --- | --- | --- |
| "帮我把发布流水线搭起来" | 命中 `wolf-cicd-deploy` | ✅ |
| "给报价接口加个字段" | 不命中任何部署技能（属功能开发） | ✅ 排除 |
| "线上报错了帮我查" | 命中 `wolf-observability` | ✅ |

- **门禁 G5（评测通过）**：触发准确率 ≥ 80%（正例全命中、反例全排除）；跑通一个真实任务产出符合验收清单。

新技能可直接套用 [`reference/skill-template.md`](./reference/skill-template.md) 的骨架。

## 产物

- 新技能目录：`SKILL.md` + 必要的 `reference/`、`scripts/`、`assets/`。
- 触发评测样本与结果记录。
- （若改造）旧技能 description 优化前后对比 + 触发率变化。

## 校验

- [ ] `name` 与目录一致，description 含 "Use when" 与 "Do not use for"。
- [ ] SKILL.md 结构完整（何时使用→前置条件→工作流带门禁→产物→校验→常见失败→验收清单）。
- [ ] SKILL.md 行数 150–500，细节/模板/脚本正确下沉。
- [ ] 触发评测 ≥ 80%，真实任务跑通。

## 常见失败与处置

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| 该挂载不挂载 | description 触发词太抽象 | 换成用户原话式 Use when |
| 误挂载（抢别的技能） | 边界不清、缺 Do not use for | 补排除句，与相邻技能对拍 |
| SKILL.md 超 500 行 | 细节全塞主文件 | 长示例下沉 reference、脚本下沉 scripts |
| 技能"只有理念跑不通" | 缺命令/配置/门禁 | 每阶段补可执行命令 + 客观门禁 |
| 与现有技能重复 | 未先查目录 | 阶段 0 先查 `../skills/`，能并入则并入 |

---

## 验收清单

- [ ] 新技能 frontmatter 合法、结构完整、体积达标（150–500 行）。
- [ ] reference/scripts/assets 拆分合理且无死链、无空壳。
- [ ] 触发评测 ≥ 80%，真实任务跑通产出符合验收清单。
- [ ] 新技能已登记到 `skills/README.md` 索引（见 `_conventions.md` 第 7 节）。
