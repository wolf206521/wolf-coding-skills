---
name: wolf-cicd-deploy
description: Build CI/CD pipelines and deployment: GitHub Actions, Docker multi-stage builds, Compose, then Kubernetes/Helm/Argo CD, environment promotion, and rollback. Use when setting up or changing build, release, or deploy automation. Do not use for writing application business code.
---

# CI/CD 与自动化部署

把"代码合入 → 制品 → 部署 → 回滚"闭环自动化。遵循本仓库 [`../docs/_conventions.md`](../../docs/_conventions.md) 第 2.5 节基础设施基线：Docker 多阶段构建（distroless/JRE 21 slim）、一期 Compose、二期 K3s/K8s + Helm + Argo CD（GitOps）、GitHub Actions（自建 Runner）、Harbor 制品、密钥不进库。版本与分支约定见 `../wolf-release-versioning/SKILL.md`，可观测见 `../wolf-observability/SKILL.md`。

## 何时使用

| 触发场景 | 动作 |
| --- | --- |
| 新建/改造 CI/CD 流水线 | 按本技能阶段 1–4 设计并落地 |
| 新增一个部署环境（staging/prod/内网） | 阶段 4 环境矩阵 + 阶段 5 发布策略 |
| 出现故障需要回滚 | 直接跳阶段 6 一键回滚 |
| 从 Compose 迁移到 K8s | 阶段 4 演进路径 |
| 仅写业务代码 / 功能开发 | **不使用本技能** |

## 前置条件

- 已确定目标仓库结构（Monorepo，见 `_conventions.md` 第 4 节）与容器基础镜像策略。
- 具备制品仓库（Harbor）与可用的 GitHub Actions Runner（内网需自建 Runner）。
- 密钥管理到位：Vault / SOPS + age / K8s Secret，禁止明文入库。
- 版本号由 `wolf-release-versioning` 产出（`<app>@<version>`）。

## 工作流（分阶段，带门禁）

> 门禁（Gate）不可跳过；任一门禁失败即阻断进入下一阶段。

### 阶段 1：设计流水线拓扑与门禁清单

先画出"哪条流水线、覆盖哪些端、哪些门禁"。目标项目基线（`apps/erp-console` 等前端 + `services/erp-server` + `services/ai-service`）通用阶段序列：

```
lint → test → build → sbom/scan → artifact → deploy(staging) → e2e → deploy(prod) → observe
```

**环境矩阵**（每个环境一张表，写入 `platform/` 或 `.github/workflows/`）：

| 环境 | 用途 | 部署方式 | 发布策略 | 数据 |
| --- | --- | --- | --- | --- |
| `ci` | 门禁验证 | 临时 Compose / kind | — | 一次性 |
| `staging` | 预发 | Compose（一期）/ K8s（二期） | 蓝绿/灰度 | 脱敏样例 |
| `prod` | 生产 | K8s + Argo CD | 蓝绿/灰度 + 一键回滚 | 真实 |

- **门禁 G1（拓扑确认）**：每个可部署单元都有明确的环境矩阵行；清单覆盖 lint/test/build/scan/e2e 六类门禁；`main` 禁止直接 push。

### 阶段 2：Docker 不可变镜像（多阶段构建）

原则：**镜像只构建一次、不可变、按 tag 追溯**；运行时层最小化（distroless 或 JRE 21 slim），禁止把密钥打进镜像。

后端示例（`services/erp-server/Dockerfile`）：

```dockerfile
# 阶段1：构建
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -q -B dependency:go-offline || true
COPY src ./src
RUN mvn -q -B -DskipTests package

# 阶段2：运行（最小 JRE）
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /src/target/*.jar /app/app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75.0","-jar","/app/app.jar"]
```

- **门禁 G2（镜像安全）**：`docker buildx build` 多平台一致；构建后运行 `trivy image --severity HIGH,CRITICAL <image>`，高危/严重 = 0；写入 SBOM（`cyclonedx`）；镜像 tag 必须等于 `<app>@<version>`（与 git 标签一致，见 `wolf-release-versioning`）。

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t harbor.local/perp/erp-server:1.4.2 --push services/erp-server
trivy image --exit-code 1 --severity HIGH,CRITICAL harbor.local/perp/erp-server:1.4.2
```

### 阶段 3：GitHub Actions 流水线

按阶段 1 序列拆成多个 job，用缓存与并发控制；内网用自建 Runner（`runs-on: [self-hosted, linux, x64]`）。精简模板：

```yaml
name: ci
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }
jobs:
  lint-test:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm -r lint
      - run: pnpm -r test -- --coverage
      - name: Coverage gate
        run: node scripts/check-coverage.mjs --min 70
  build-scan:
    needs: lint-test
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - name: Build & scan
        run: |
          docker build -t harbor.local/perp/erp-server:${{ github.sha }} services/erp-server
          trivy image --exit-code 1 --severity HIGH,CRITICAL harbor.local/perp/erp-server:${{ github.sha }}
      - name: Push
        run: docker push harbor.local/perp/erp-server:${{ github.sha }}
```

- **门禁 G3（CI 绿）**：PR 必须全绿才可合入；覆盖率 ≥ 阈值（后端 70%、前端 60%，见 `_conventions.md` 第 2.4 节）；SonarQube 无新增 Blocker/Critical；Trivy/Semgrep 高危 = 0。

### 阶段 4：部署编排（Compose → K8s/Helm/Argo CD）

**一期 Compose**（单机/双机，`platform/compose/docker-compose.prod.yml` 片段）：

```yaml
services:
  erp-server:
    image: harbor.local/perp/erp-server:1.4.2
    environment:
      SPRING_PROFILES_ACTIVE: prod
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/actuator/health"]
      interval: 10s
      timeout: 3s
      retries: 5
    deploy:
      replicas: 2
      update_config: { parallelism: 1, order: start-first }
secrets:
  db_password: { file: ./secrets/db_password.txt }
```

**二期 K8s + Helm + Argo CD**：把 Compose 的每项能力映射为 Helm chart（`platform/helm/erp-server/`），用 Argo CD 以 GitOps 声明式部署，禁止 `kubectl` 手工改生产。Argo CD Application 片段：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: erp-server, namespace: argocd }
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/p-erp.git
    path: platform/helm/erp-server
    targetRevision: main
  destination: { server: https://kubernetes.default.svc, namespace: erp }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

- **门禁 G4（部署成功）**：部署后健康检查通过；金丝雀/蓝绿流量切换前旧版本仍存活；`argocd app sync` 后 `Healthy` 状态；staging 环境 E2E 全绿才可推进 prod。

### 阶段 5：发布策略（蓝绿 / 灰度）

| 策略 | 适用 | 要点 |
| --- | --- | --- |
| 蓝绿 | 切换干净、回滚最快 | 两套完整副本 + 流量一次性切换 |
| 灰度（Canary） | 需要逐步验证 | 按百分比/用户特征放量，配合观测指标 |

灰度示例（Helm values + Ingress 权重，流量 10%）：

```yaml
canary:
  enabled: true
  weight: 10
  header: x-canary-user
```

**放量规则**：10% → 观察 15 分钟（错误率、P95、CPU）→ 25% → 50% → 100%，任意一步指标劣化立即回退。观测指标见 `wolf-observability`。

- **门禁 G5（发布验收）**：灰度每一步无告警；错误率 < 阈值；P95 达标；若劣化，先回滚再排查。

### 阶段 6：一键回滚

原则：**镜像不可变 + 数据库向前兼容（Expand/Contract）→ 回滚 = 切回上一镜像 tag**，不改数据库。

```bash
# Compose：切回上一 tag 并滚动更新
TAG=1.4.1 docker compose -f platform/compose/docker-compose.prod.yml up -d

# K8s/Argo CD：回滚到上一 revision
kubectl -n argocd rollout undo application/erp-server   # 或 argocd app rollback erp-server 1
```

- **门禁 G6（回滚可用）**：每季度至少一次**回滚演练**；回滚记录写入 `docs/`（时间、触发原因、上一版本、恢复耗时）；回滚脚本在流水线中受控（需人工确认，不用全自动）。

完整流水线蓝图、Helm values 与 Argo CD 示例见 [`reference/pipeline-blueprint.md`](./reference/pipeline-blueprint.md)。

## 产物

- 每个可部署单元：`Dockerfile`（多阶段）+ 镜像 tag 规则 + SBOM。
- `.github/workflows/`：`ci.yml`、`release.yml`、`deploy-*.yml`。
- `platform/`：Compose（一期）/ Helm chart + Argo CD Application（二期）。
- 环境矩阵表 + 发布策略 + 回滚脚本（`scripts/rollback.sh`）。

## 校验

- [ ] `docker build` 与 `docker buildx build` 均成功，运行时层无构建工具、无密钥。
- [ ] `trivy image --severity HIGH,CRITICAL` 通过，SBOM 已生成并随制品保存。
- [ ] PR 上 `ci.yml` 全绿，覆盖率/质量/安全门禁全部通过。
- [ ] staging 部署后 E2E 全绿；prod 灰度放量步骤有日志、有回退记录。
- [ ] 回滚演练实际执行一次，回滚耗时已记录。

## 常见失败与处置

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| 构建在 CI 能过、本地不过（或反之） | 依赖未锁、平台差异 | 使用 `--frozen-lockfile` / 锁定基础镜像 digest；统一 `buildx` 平台 |
| `trivy` 报高危 | 基础镜像或依赖含漏洞 | 升级基础镜像/依赖；如为误报，用 `.trivyignore` 记录豁免理由 |
| 部署后健康检查失败 | 探针路径/端口错误、依赖未就绪 | 对齐 `/actuator/health` 端点；依赖注入用 `start-first` + 依赖等待 |
| Argo CD 持续 OutOfSync | 手工改集群、`selfHeal` 未开 | 开启 `automated.selfHeal`；禁止手工 `kubectl edit` |
| 回滚失败 | 数据库迁移不可逆、镜像 tag 混乱 | 采用 Expand/Contract 迁移；tag 严格等于 `<app>@<version>` |
| 密钥泄漏进镜像/日志 | 明文 env、`COPY` 了 `.env` | 用 Secret/secrets 文件，构建期不得注入运行时密钥 |

---

## 验收清单

- [ ] 阶段 1–6 全部走通，六道门禁（G1–G6）有明确通过/失败记录。
- [ ] 所有镜像 tag 与 `wolf-release-versioning` 产出的 `<app>@<version>` 一一对应。
- [ ] 环境矩阵覆盖 `ci/staging/prod`，发布策略与回滚脚本可用并演练过。
- [ ] 密钥不进库、不进镜像、不进日志。
