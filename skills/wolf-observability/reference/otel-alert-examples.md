# OTel 埋点与告警示例（细节参考）

> 承载 `SKILL.md` 阶段 1/3/4 的完整配置片段，避免主文件过长。

## 1. OTel Collector 配置

`platform/observability/otel-collector-config.yaml`：

```yaml
receivers:
  otlp:
    protocols: { grpc: { endpoint: 0.0.0.0:4317 }, http: { endpoint: 0.0.0.0:4318 } }
processors:
  batch:
  memory_limiter: { check_interval: 1s, limit_mib: 512 }
exporters:
  prometheusremotewrite: { endpoint: "http://prometheus:9090/api/v1/write" }
  otlp/tempo: { endpoint: "tempo:4317", tls: { insecure: true } }
  loki:
    endpoint: "http://loki:3100/loki/api/v1/push"
service:
  pipelines:
    traces:  { receivers: [otlp], processors: [batch], exporters: [otlp/tempo] }
    metrics: { receivers: [otlp], processors: [batch], exporters: [prometheusremotewrite] }
    logs:    { receivers: [otlp], processors: [batch], exporters: [loki] }
```

## 2. 后端依赖（Spring Boot 3 + Micrometer Tracing）

`build.gradle`（或等价 `pom.xml`）关键依赖：

```groovy
implementation 'org.springframework.boot:spring-boot-starter-actuator'
implementation 'io.micrometer:micrometer-tracing-bridge-otel'
implementation 'io.opentelemetry:opentelemetry-exporter-otlp'
runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
implementation 'net.logstash.logback:logstash-logback-encoder:7.4'
```

## 3. RED 记录规则 + SLO（Prometheus）

`platform/observability/recording-rules/slo.yml`：

```yaml
groups:
  - name: slo
    rules:
      - record: job:http_requests:rate5m
        expr: sum(rate(http_server_requests_seconds_count[5m])) by (service)
      - record: job:http_errors:rate5m
        expr: sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m])) by (service)
      - record: job:http_success_ratio
        expr: 1 - (job:http_errors:rate5m / job:http_requests:rate5m)
  - name: error-budget
    rules:
      - alert: ErrorBudgetBurningFast
        expr: |
          (1 - job:http_success_ratio) > (1 - 0.999) * 3   # 燃尽速度 3 倍于预算
        for: 30m
        labels: { severity: p1 }
        annotations:
          summary: "错误预算快速燃尽，建议暂停发布"
          runbook_url: "https://wiki.local/runbooks/error-budget"
```

## 4. 告警静默与抑制（Alertmanager）

`alertmanager.yml` 片段：

```yaml
route:
  receiver: default
  group_by: ['alertname', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers: [severity="p0"]
      receiver: pagerduty
    - matchers: [severity="p1"]
      receiver: im-ops
    - matchers: [severity="p2"]
      receiver: email
inhibit_rules:
  - source_matchers: [severity="p0"]
    target_matchers: [severity="p1"]
    equal: ['service']
```

## 5. 审计日志表（PostgreSQL）

```sql
CREATE TABLE audit_logs (
  id          BIGSERIAL PRIMARY KEY,
  tenant_id   BIGINT      NOT NULL,
  actor_type  TEXT        NOT NULL,          -- user / system / partner
  actor_id    TEXT        NOT NULL,
  action      TEXT        NOT NULL,          -- create / update / delete / read-sensitive
  resource    TEXT        NOT NULL,          -- sales_orders / quotations ...
  resource_id TEXT,
  diff        JSONB,                          -- before/after 摘要，不含明文密钥
  trace_id    TEXT        NOT NULL,
  ip          INET,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 只增不改：拒绝 UPDATE/DELETE
CREATE RULE audit_no_update AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE RULE audit_no_delete AS ON DELETE TO audit_logs DO INSTEAD NOTHING;
-- 保留 ≥ 3 年：分区按月，定期归档
CREATE INDEX idx_audit_trace ON audit_logs(trace_id);
CREATE INDEX idx_audit_resource ON audit_logs(resource, resource_id, created_at);
```

## 6. 故障演练清单

| 注入 | 期望 | 观测点 |
| --- | --- | --- |
| 报价接口注入 800ms 延迟 | P95 面板上升、慢 span 定位到报价引擎 | Tempo span 耗时 |
| DB 连接池打满 | 依赖面板告警、错误预算燃尽 | `hikaricp_connections_pending` |
| 某队列积压 | 消费延迟指标、下游错误率上升 | RocketMQ lag 指标 |
