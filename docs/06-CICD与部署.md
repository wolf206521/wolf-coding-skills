# 06 · CI/CD 与部署（CI/CD & Deployment）

> 对应 Skill：`wolf-cicd-deploy`。基础设施与交付基线以 [`_conventions.md`](./_conventions.md) 第 2.5 节、版本基线以第 3 节为唯一事实源；总纲见 [`00-master-plan.md`](./00-master-plan.md) 第 9 节。
> 离线/私有化部署见 [`07-自建与私有化部署.md`](./07-自建与私有化部署.md)。

---

## 1. 流水线阶段

```
lint → test → build → sbom/scan → artifact → deploy(staging) → e2e → deploy(prod) → observe
        └─────── PR 门禁（快，<10min）───────┘   └────── 发布门禁（staging 后，<30min）──────┘
```

每个阶段失败即阻断，无人工跳过开关（除 `release` 手动 approve prod 外）。

| 阶段 | 动作 | 门禁 |
| --- | --- | --- |
| lint | ESLint/Prettier/Biome + Spotless(Java) + Ruff(Python) | 无报错 |
| test | 单元/集成/契约/架构/变异（见 [`04-自动化测试策略.md`](./04-自动化测试策略.md)） | 阈值达标 |
| build | 前后端构建、OpenAPI 生成 client、Taro 打包小程序 | 产物可生成 |
| sbom/scan | Syft 生成 SBOM + Trivy/Semgrep/Dependency-Check + SonarQube | 高危 0、新增 Blocker/Critical 0 |
| artifact | 多阶段构建镜像 → 推 Harbor → cosign 签名 → 写 `build-info.json` | 镜像不可变 |
| deploy staging | Compose/Helm 部署到 staging | 健康检查通过 |
| e2e | Playwright + miniprogram-automator + k6 冒烟 | P0 全绿、P95 达标 |
| deploy prod | 蓝绿/灰度发布，手动 approve | 人工确认 |
| observe | Prometheus/Grafana/Loki/Tempo 观测，失败自动告警 | 错误率/延迟阈值 |

---

## 2. GitHub Actions 设计

- **矩阵构建**：前端按 app 矩阵（erp-console/customer-portal/supplier-portal/outsourcing-portal/customer-mini），后端按 JDK 21 + 模块。
- **自建 Runner**：`runs-on: [self-hosted, linux, docker]`；印刷厂内网用内网 Runner（见 07 号文档）。
- **缓存**：`actions/cache` 缓存 pnpm store、Gradle、Docker layer。
- **制品上传**：镜像推 Harbor，SBOM/签名上传为 job artifact，供回溯。

### 2.1 后端 + 前端 + 小程序 YAML 骨架

```yaml
name: ci
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
env:
  REGISTRY: harbor.example.com/perp
jobs:
  lint-test:
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 21, cache: gradle }
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - name: Cache pnpm store
        uses: actions/cache@v4
        with: { path: ~/.local/share/pnpm/store, key: pnpm-${{ hashFiles('pnpm-lock.yaml') }} }
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: ./gradlew test jacocoTestReport integrationTest   # Testcontainers
      - run: pnpm test && pnpm test:contract

  build-matrix:
    needs: lint-test
    strategy:
      matrix:
        app: [erp-console, customer-portal, supplier-portal, outsourcing-portal, customer-mini]
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm --filter @perp/${{ matrix.app }} build
      - uses: actions/upload-artifact@v4
        with: { name: dist-${{ matrix.app }}, path: apps/${{ matrix.app }}/dist }

  backend-build:
    needs: lint-test
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 21, cache: gradle }
      - run: ./gradlew bootJar

  sbom-scan:
    needs: [build-matrix, backend-build]
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: anchore/sbom-action@v0
        with: { path: . , format: spdx-json, output-file: sbom.spdx.json }
      - run: trivy image --severity HIGH,CRITICAL --exit-code 1 ${REGISTRY}/backend:${GITHUB_SHA::7}
      - run: semgrep scan --config=auto --error
      - run: sonar-scanner -Dsonar.qualitygate.wait=true

  image:
    needs: sbom-scan
    runs-on: [self-hosted, linux, docker]
    steps:
      - name: Build & sign & write build-info.json
        run: |
          docker build -t ${REGISTRY}/backend:${GITHUB_SHA::7} -f services/erp-server/Dockerfile .
          cosign sign --key cosign.key ${REGISTRY}/backend:${GITHUB_SHA::7}
          scripts/write-build-info.sh ${GITHUB_SHA} ${GITHUB_RUN_NUMBER}
          docker push ${REGISTRY}/backend:${GITHUB_SHA::7}

  deploy-staging:
    needs: image
    runs-on: [self-hosted, linux, docker]
    steps:
      - run: helm upgrade --install perp-staging ./platform/helm -f platform/helm/values-staging.yaml --wait

  e2e:
    needs: deploy-staging
    runs-on: [self-hosted, linux, docker]
    steps:
      - run: pnpm --filter @perp/e2e test:e2e --project=erp-console
      - run: pnpm --filter @perp/e2e test:e2e --project=customer-portal
      - run: pnpm --filter @perp/e2e test:e2e --project=supplier-portal
      - run: pnpm --filter @perp/e2e test:e2e --project=outsourcing-portal
      - run: k6 run tests/performance/quotation-smoke.js

  deploy-prod:
    needs: e2e
    runs-on: [self-hosted, linux, docker]
    environment: production      # 需手动 approve
    steps:
      - run: helm upgrade --install perp-prod ./platform/helm -f platform/helm/values-prod.yaml --wait
      - run: scripts/observe-post-deploy.sh     # 观测 + 失败自动回滚
```

---

## 3. 环境与密钥管理（Vault / SOPS）

| 环境 | 用途 | 密钥来源 |
| --- | --- | --- |
| `dev` | 本地 + 集成 | `.env.local`（不提交） |
| `staging` | 预发布 | SOPS 加密的 `platform/helm/secrets-staging.enc.yaml` |
| `prod` | 生产 | Vault（K8s Secret 注入）/ SOPS + age 兜底 |

规则（2.5 节）：**禁止明文入库**。

```bash
# SOPS 加密/解密（age）
sops --encrypt --age <recipient> platform/helm/secrets-prod.yaml > secrets-prod.enc.yaml
sops --decrypt secrets-prod.enc.yaml > /tmp/secrets-prod.yaml   # 仅运行时，不入库

# Vault 写入 + K8s External Secrets 拉取
vault kv put secret/perp/db password="$(openssl rand -base64 32)"
```

密钥最小权限：DB/Redis/RocketMQ/对象存储/MinIO 各自独立凭证，按服务挂载，不共享根账号。

---

## 4. 环境矩阵表

| 环境 | 规模 | 数据库 | 数据 | E2E | 密钥 | 部署方式 |
| --- | --- | --- | --- | --- | --- | --- |
| `dev` | 单机 | 本地 Testcontainers | fixtures | 否 | `.env.local` | `docker compose up` |
| `staging` | 双机 Compose | PG16 + Redis + RocketMQ + MinIO | 脱敏样例 | 是（P0 全量） | SOPS | Compose / Helm |
| `prod` | 一期 Compose → 二期 K8s | 高可用 PG + 主从 | 真实 | 冒烟 | Vault | Helm + Argo CD |

---

## 5. Docker 多阶段构建与不可变镜像

```dockerfile
# services/erp-server/Dockerfile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM gcr.io/distroless/java21-debian12:nonroot
COPY --from=build /src/services/erp-server/build/libs/*.jar /app/app.jar
USER nonroot
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- 镜像 tag 用 **git SHA**（不可变），`latest` 仅本地开发，禁止进生产。
- 每个镜像写入 `build-info.json` 为 OCI label（见 [`05-版本管理与分支策略.md`](./05-版本管理与分支策略.md) §7）。

---

## 6. 一期 Compose / 二期 K8s+Helm+Argo CD

### 6.1 一期 Compose（`platform/compose/docker-compose.prod.yml` 节选）

```yaml
services:
  backend:
    image: ${REGISTRY}/backend:${TAG}
    restart: unless-stopped
    depends_on: [postgres, redis, rocketmq, minio]
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/perp
  postgres:
    image: postgres:16
    volumes: [pgdata:/var/lib/postgresql/data]
  minio:
    image: minio/minio:RELEASE.2024-01-16T16-07-38Z
    command: server /data --console-address ":9001"
volumes: { pgdata: {} }
```

### 6.2 二期 Helm values 关键片段

```yaml
# platform/helm/values-prod.yaml
image:
  repository: harbor.example.com/perp/backend
  tag: ""            # 由 Argo CD 从 git SHA 注入，不可变
  pullPolicy: IfNotPresent
replicaCount: 3
resources:
  requests: { cpu: "500m", memory: "1Gi" }
  limits:   { cpu: "2", memory: "4Gi" }
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
strategy:
  type: RollingUpdate
  rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }   # 蓝绿/灰度基础
postgresql:
  enabled: false        # 生产接外部托管/自建 PG，避免 chart 内置
  host: pg.internal
  database: perp
```

### 6.3 Argo CD GitOps

```yaml
# platform/argocd/perp-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: perp-prod, namespace: argocd }
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/p-erp
    path: platform/helm
    targetRevision: main
  destination: { server: https://kubernetes.default.svc, namespace: perp-prod }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

- **GitOps 原则**：集群状态 = `platform/` 目录声明，任何线上改动必须改代码/配置，禁止 `kubectl` 裸改。

---

## 7. 蓝绿/灰度发布与一键回滚

### 7.1 蓝绿

```
blue(旧 v1.4.0) ──► 新 green(v1.5.0) 就绪 ──► 流量切 green ──► 观测稳定 ──► 下线 blue
                                    └─ 异常：流量切回 blue（秒级）
```

```bash
# K8s：切换 Service selector 指向 active 版本
kubectl patch service erp-console -p '{"spec":{"selector":{"version":"v1.5.0"}}}'
```

### 7.2 灰度（金丝雀）

```bash
# Argo Rollouts：10% → 50% → 100%
kubectl argo rollouts set image perp-backend backend=<image>:<tag>
kubectl argo rollouts promote perp-backend
```

### 7.3 一键回滚

```bash
# K8s：rollout 回滚到上一镜像 tag
kubectl rollout undo deployment/erp-console
# 或精确切回：
kubectl set image deployment/backend backend=${REGISTRY}/backend:<prev-tag>

# Compose 阶段：切回旧 tag 配置后
docker compose -f docker-compose.prod.yml up -d --no-deps backend
# 观测脚本自动回滚（deploy-prod 内）：
scripts/observe-post-deploy.sh   # 错误率>阈值 → 自动执行上面 undo
```

> DB 永不回滚（Expand/Contract），回滚仅切镜像 tag，见 [`05-版本管理与分支策略.md`](./05-版本管理与分支策略.md) §6。

---

## 8. 验收清单

- [ ] 流水线阶段为 `lint→test→build→sbom/scan→artifact→deploy(staging)→e2e→deploy(prod)→observe`。
- [ ] GitHub Actions YAML 覆盖前端矩阵 + 后端 + 小程序构建，含自建 Runner、缓存、制品上传、cosign 签名。
- [ ] 环境矩阵表含 dev/staging/prod 的规模、数据、E2E、密钥、部署方式。
- [ ] 密钥经 Vault/SOPS 管理，仓库内无明文凭证。
- [ ] Docker 多阶段构建 + distroless，镜像 tag 用 git SHA 不可变。
- [ ] 一期 Compose、二期 Helm + Argo CD 配置齐全，Helm values 含资源/扩缩容/滚动策略。
- [ ] 蓝绿/灰度发布与一键回滚命令可执行，回滚不触发 DB 回退。
- [ ] `deploy-prod` 设 `environment: production` 需手动 approve。
