# 流水线蓝图（细节参考）

> 本文承载 `SKILL.md` 阶段 3–5 的完整示例，避免主文件过长。使用前先读完 `SKILL.md`。

## 1. 完整 CI 工作流骨架

`.github/workflows/ci.yml`（Monorepo，按目录变更触发对应 job）：

```yaml
name: ci
on:
  pull_request: { branches: [main] }
  push: { branches: [main] }
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  changed:
    runs-on: [self-hosted, linux, x64]
    outputs:
      backend: ${{ steps.diff.outputs.backend }}
      frontend: ${{ steps.diff.outputs.frontend }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - id: diff
        uses: dorny/paths-filter@v3
        with:
          filters: |
            backend: ['services/**', '.github/workflows/**']
            frontend: ['apps/**', 'packages/**', '.github/workflows/**']

  backend:
    needs: changed
    if: needs.changed.outputs.backend == 'true'
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 21, cache: maven }
      - run: mvn -q -B -pl services/erp-server verify   # test + integration + ArchUnit
      - name: Sonar
        run: mvn -q -B sonar:sonar -Dsonar.qualitygate.wait=true
      - name: Build & scan image
        run: |
          docker build -t harbor.local/perp/erp-server:${{ github.sha }} services/erp-server
          trivy image --exit-code 1 --severity HIGH,CRITICAL harbor.local/perp/erp-server:${{ github.sha }}
          docker push harbor.local/perp/erp-server:${{ github.sha }}

  frontend:
    needs: changed
    if: needs.changed.outputs.frontend == 'true'
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm -r lint
      - run: pnpm -r test -- --coverage
      - run: pnpm -r build
```

## 2. 发布工作流（release.yml）要点

- 触发：打注解标签 `<app>@<version>`（由 `wolf-release-versioning` 产出）。
- 动作：读 `build-info.json` 写 commit SHA + 构建号 + SBOM + 签名 → 构建镜像 → 推 Harbor → 触发 Argo CD 同步 staging。
- 生产部署用**人工审批**（`environment: production` + required reviewers），不用全自动。

```yaml
deploy-prod:
  needs: deploy-staging
  environment:
    name: production
  runs-on: [self-hosted, linux, x64]
  steps:
    - run: echo "生产部署需审批后执行；此处 argocd 同步 prod"
```

## 3. Helm values 与金丝雀

`platform/helm/erp-server/values.yaml` 关键片段：

```yaml
image:
  repository: harbor.local/perp/erp-server
  tag: ""              # 由 CI 注入，必须等于 <app>@<version>
  pullPolicy: IfNotPresent
replicaCount: 2
canary:
  enabled: false
  weight: 0
resources:
  requests: { cpu: 250m, memory: 512Mi }
  limits: { cpu: "1", memory: 1Gi }
readinessProbe:
  httpGet: { path: /actuator/health/readiness, port: 8080 }
livenessProbe:
  httpGet: { path: /actuator/health/liveness, port: 8080 }
```

## 4. Argo CD 环境分离

用 `ApplicationSet` 按环境矩阵生成 staging/prod：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata: { name: erp-server, namespace: argocd }
spec:
  generators:
    - list:
        elements:
          - { env: staging, cluster: staging }
          - { env: prod, cluster: prod }
  template:
    metadata: { name: 'erp-server-{{env}}' }
    spec:
      source:
        repoURL: https://github.com/<org>/p-erp.git
        path: platform/helm/erp-server
        targetRevision: main
      destination: { server: '{{cluster}}', namespace: 'erp-{{env}}' }
      syncPolicy:
        automated: { prune: true, selfHeal: true }
```

## 5. 回滚脚本骨架

`scripts/rollback.sh`（在目标项目，非本仓库）：

```bash
#!/usr/bin/env bash
set -euo pipefail
APP="${1:-erp-server}"
PREV_TAG="${2:-}"          # 显式指定上一版本 tag，避免误切
if [[ -z "$PREV_TAG" ]]; then
  echo "用法: rollback.sh <app> <prev-tag>" >&2; exit 1
fi
kubectl -n argocd rollout undo "application/${APP}" || {
  echo "ArgoCD undo 失败，回退到显式 tag: ${PREV_TAG}" >&2
  # 通过 Helm 显式回退（保证镜像不可变回滚）
  helm upgrade "${APP}" "platform/helm/${APP}" --set image.tag="${PREV_TAG}" --wait
}
echo "[$(date -u +%FT%TZ)] rollback ${APP} -> ${PREV_TAG}" >> docs/rollback.log
```
