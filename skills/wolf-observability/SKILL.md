---
name: wolf-observability
description: Instrument observability: OpenTelemetry traces/metrics/logs, Prometheus/Grafana/Loki/Tempo, alerting, SLOs, and immutable audit logging. Use when adding or improving monitoring, alerts, or troubleshooting a production issue. Do not use for feature development.
---

# 可观测性建设

用**三支柱（Trace / Metrics / Logs）**统一观测生产系统，并以 `traceId` 贯通全链路做故障排查。遵循 [`../docs/_conventions.md`](../../docs/_conventions.md) 第 2.5 节：OpenTelemetry Collector → Prometheus + Grafana + Loki + Tempo；结构化 JSON 日志 + 全链路 traceId + 业务审计表（不可删）。埋点与部署由 `../wolf-cicd-deploy` 承载，本技能负责"埋什么、怎么查、怎么告警"。

## 何时使用

| 触发场景 | 动作 |
| --- | --- |
| 新服务上线前补观测 | 阶段 1 埋点 + 阶段 2 面板 |
| 线上告警不准确 / 太吵 | 阶段 3 告警分级与静默 |
| 定义服务可用性目标 | 阶段 4 SLO |
| 生产故障排查 | 直接跳阶段 6（traceId 关联） |
| 纯功能开发 | **不使用本技能** |

## 前置条件

- OTel Collector 已部署（`platform/observability/`），Prometheus/Grafana/Loki/Tempo 可访问。
- 服务已接入 `spring-boot-starter-actuator`（后端）与 OTel SDK（各端）。
- 日志统一 JSON，每条含 `traceId`、`spanId`、`service.name`、`env`、`ts`。

## 工作流（分阶段，带门禁）

### 阶段 1：三支柱埋点（OTel）

**Trace**：每个请求入口生成 `traceId`，跨进程/跨队列透传（RocketMQ 消息头、HTTP header `traceparent`）。后端 Spring Boot 3 用 Micrometer Tracing + OTel exporter：

```yaml
management:
  tracing:
    sampling: { probability: 1.0 }   # 一期全采，量大后降为 0.1
  otlp:
    tracing:
      endpoint: http://otel-collector:4317
```

**Metrics**：统一以 RED（Rate/Error/Duration）为基线，业务指标另加；用 Micrometer 暴露到 `/actuator/prometheus`：

```java
// RED 由框架自动埋；业务计数手动埋
meterRegistry.counter("perp.quotation.submitted", "result", "ok").increment();
meterRegistry.timer("perp.quotation.calc.duration", "engine", "drools").record(Duration.between(s,e));
```

**Logs**：结构化 JSON（`logback` + `logstash-encoder`），每个线程绑定 traceId：

```xml
<appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
  <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
</appender>
```

- **门禁 G1（三支柱齐全）**：任意新写操作/新接口，都能在 Grafana 查到 trace、在 Prometheus 查到 RED 指标、在 Loki 用 `traceId` 反查日志；无观测埋点的 PR 不允许合入。

### 阶段 2：Grafana 面板

按"服务概览 → 依赖 → 业务"三层建面板，命名统一：`{service}/概览`、`{service}/错误率`。

| 面板 | 指标/数据源 | 阈值 |
| --- | --- | --- |
| 请求量 QPS | `rate(http_server_requests_seconds_count[5m])` | 观察 |
| 错误率 | `rate(...[5m]) / rate(...[5m])`（5xx） | > 1% 告警 |
| 延迟 P95/P99 | `histogram_quantile(0.95, ...)` | 查询 P95 < 500ms（见 `_conventions.md`） |
| 依赖（DB/Redis/MQ） | 各自 client 指标 | 超时/连接池耗尽 |
| 业务（报价/订单） | 自定义 counter/timer | 业务 SLO |

- **门禁 G2（面板可查）**：每个服务至少有「概览」与「错误率」两面板；面板数据源非空；`Explore` 中可从一个 traceId 同时看到 trace + 对应日志（Tempo↔Loki 关联）。

### 阶段 3：告警规则与分级

分级策略：**P0 立即电话/IM 值班 → P1 15 分钟响应 → P2 下一个工作日**。用 Prometheus `Alertmanager` 路由，规则写入 `platform/observability/alerts/*.yml`：

```yaml
groups:
  - name: erp-server
    rules:
      - alert: ErpServerHighErrorRate
        expr: |
          sum(rate(http_server_requests_seconds_count{service="erp-server",status=~"5.."}[5m]))
          / sum(rate(http_server_requests_seconds_count{service="erp-server"}[5m])) > 0.01
        for: 5m
        labels: { severity: p1 }
        annotations:
          summary: "erp-server 错误率 > 1%"
          runbook_url: "https://wiki.local/runbooks/erp-high-error"
```

- **门禁 G3（告警可闭环）**：每条告警必须带 `runbook_url`；设置静默/抑制规则避免抖动（`for: 5m` + `repeat_interval`）；P0/P1 覆盖核心链路；无 runbook 的告警禁止上线。

### 阶段 4：SLO 定义

为**关键用户旅程**（下单、报价、查进度）定义 SLO，用错误预算（error budget）驱动发布决策：

| 服务 | SLI | SLO | 错误预算/月 |
| --- | --- | --- | --- |
| 报价 API | 成功请求占比 | 99.9% | 约 43 分钟不可用 |
| 下单流程 | 端到端成功率 | 99.5% | 约 3.6 小时 |
| 交期查询 | P95 延迟 | < 500ms，99% 分位 | — |

- **门禁 G4（SLO 可用）**：SLO 以 Prometheus 记录规则（`recording rules`）落为指标；错误预算燃尽率接入告警（快燃尽时降速发布）；灰度放量必须参考错误预算（见 `wolf-cicd-deploy` 阶段 5）。

### 阶段 5：不可变审计日志

区别于"运维日志"，**审计日志**记录"谁在何时对什么做了写操作/越权尝试"，只增不改、保留 ≥ 3 年（见 `_conventions.md` 第 5 节）：

- 表 `audit_logs`：`id, tenant_id, actor_type, actor_id, action, resource, resource_id, before/after(diff), trace_id, ip, created_at`。
- 写入走独立通道（异步落库 + 定期归档冷存储），**禁止 UPDATE/DELETE**（数据库触发器或应用层约束兜底）。
- 财务/价格类敏感字段的读取也计入审计（防越权读取）。

- **门禁 G5（审计不可篡改）**：对 `audit_logs` 执行 `UPDATE/DELETE` 会被拒绝；抽样校验：每笔生产写操作都能在审计表找到对应 `trace_id` 记录。

### 阶段 6：故障排查流程（traceId 关联）

标准排查链，从告警出发：

1. 拿到告警面板 → 取最耗时/最多次的 `traceId`。
2. Grafana `Explore` 用该 `traceId` 打开 Tempo，定位最慢 span（DB？MQ？外部调用？）。
3. 同一 `traceId` 在 Loki 反查日志，看该 span 的异常栈/参数。
4. 交叉 Prometheus 指标（连接池、队列积压、CPU/内存）判断是资源还是代码。
5. 定位根因 → 修复 → 用同一 `traceId` 复测 → 回填 runbook 与告警规则。

- **门禁 G6（可排障）**：任意一次故障演练（注入延迟/错误）能沿上述 5 步在 15 分钟内定位根因；traceId 未断链。

埋点与告警完整示例见 [`reference/otel-alert-examples.md`](./reference/otel-alert-examples.md)。

## 产物

- `platform/observability/`：`otel-collector-config.yaml`、`alerts/*.yml`、`recording-rules/*.yml`。
- 每个服务的 Grafana 面板（导出 JSON 存 `platform/observability/dashboards/`）。
- SLO 清单表 + 错误预算告警。
- `audit_logs` 表结构与写入约束。

## 校验

- [ ] 新接口都能查到 trace + RED 指标 + 日志，三者经 `traceId` 打通。
- [ ] 每条告警有 `runbook_url`，P0/P1 已分级且不抖动。
- [ ] SLO 已落为记录规则，错误预算告警生效。
- [ ] `audit_logs` 无法 UPDATE/DELETE，保留策略 ≥ 3 年。
- [ ] 一次故障注入演练能在 15 分钟内沿 traceId 定位根因。

## 常见失败与处置

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| trace 断在跨服务/跨 MQ 处 | 未透传 `traceparent` / 消息头丢失 | 统一 OTel propagation；MQ 用消息头携带 trace context |
| Loki 查不到日志 | 日志未 JSON、未带 traceId、未采到 | 强制 LogstashEncoder + MDC 绑定 traceId |
| 告警频繁抖动 | 阈值太敏感、无 `for` 窗口 | 加 `for: 5m` 与 `repeat_interval`，看 P95 而非瞬时 |
| 高基数指标拖垮 Prometheus | label 含 userId/traceId 等高基数值 | 指标 label 只用低基数（service/method/status） |
| 审计日志丢失/被改 | 同步写失败、无防删约束 | 异步落库 + 定期对账；DB 层禁止 UPDATE/DELETE |
| 找不到问题 span | 采样率过低 | 关键链路强制采样；报错 span 100% 采 |

---

## 验收清单

- [ ] 阶段 1–6 全部走通，六道门禁（G1–G6）有通过记录。
- [ ] 三支柱 + 审计日志四类数据齐全，`traceId` 全链路贯通。
- [ ] 告警分级 + runbook + SLO/错误预算接入发布决策。
- [ ] 一次故障演练完成，根因定位时长与修复记录已归档。
