---
name: wolf-security-review
description: "Perform a two-pass security review: defensive checks (secrets, input validation, authentication/authorization, SQL injection) then vulnerability hunting (XSS, IDOR, SSRF, broken access control, dependency CVEs). Use before a release or on a PR flagged for review. Do not use for non-code changes."
---

# 安全审查（两遍扫描法）

> ⚠️ **已废弃**：本技能已被逐字集成的上游 `security-code-review` 替代，请改用 `security-code-review`（含 36 个多语言 reference）。本文件保留仅为历史与**领域红线**（多租户隔离、字段脱敏、审计保留 ≥3 年）参考。

借鉴 Artais-Security 两遍扫描：**第一遍防御性检查**（密钥、输入校验、认证授权、SQL 注入），**第二遍漏洞狩猎**（XSS、IDOR、SSRF、越权、依赖 CVE）。
高危漏洞 **0 容忍**，多租户/字段脱敏红线见 [`../../docs/_conventions.md`](../../docs/_conventions.md) 第 5 节。

## 何时使用

- 发布前（release 门禁）。
- PR 被标记为安全审查。
- 新增对外暴露接口、文件上传、支付/价格、认证授权逻辑。

不适用于：纯文档、纯样式、无代码改动。

## 前置条件

- 工具：Semgrep（SAST）、Trivy（镜像/依赖）、OWASP Dependency-Check（Java 依赖 CVE）、ZAP（DAST）。
- 密钥管理：Vault / SOPS + age / K8s Secret，禁止明文入库（`_conventions.md` 第 2.5 节）。
- 目标：OWASP Top 10（2021）+ 本项目多租户/字段脱敏红线。

## 工作流（分阶段，带门禁）

### 阶段 0：范围与基线

1. 圈定审查范围：PR diff、发布变更集、新增接口清单。
2. 建立威胁面：对外端口、上传点、鉴权点、第三方依赖、AI 服务边界（客户设计稿默认不出域）。

### 阶段 1：第一遍——防御性检查（门禁 G1）

逐项检查并留痕：

1. **密钥**：搜索硬编码（`password`、`token`、`secret`、`api[_-]?key`、AK/SK、私钥）；确认走 Vault/SOPS。
2. **输入校验**：所有对外输入过 DTO 校验（Bean Validation / Zod），禁止信任前端数据。
3. **认证授权**：每个接口有鉴权注解/中间件；越权返回 403；token 内 `partner_type/partner_id` 与资源归属一致。
4. **SQL 注入**：禁止字符串拼接 SQL；用参数化（JPA / MyBatis `#{}`）；动态排序/过滤字段走白名单。
5. **多租户/脱敏**：查询带 `tenant_id`/`partner_id`（RLS + 拦截器双保险）；价格/成本对协同端在 DTO 层裁剪。

```bash
# SAST
semgrep scan --config=auto --config=p/owasp-top-ten .
# Java 依赖 CVE
./gradlew dependencyCheckAnalyze
# 镜像扫描
trivy image harbor.local/wolf/erp-server:1.4.2
```

**G1**：Semgrep 高危/严重 = 0；Dependency-Check 高危 CVE = 0；密钥无明文入库。

### 阶段 2：第二遍——漏洞狩猎（门禁 G2）

主动攻击面：

1. **XSS**：React 默认转义；注意 `dangerouslySetInnerHTML`/富文本走 DOMPurify 白名单。
2. **IDOR**：直接对象引用校验归属（`GET /orders/{id}` 校验 id 属于当前 partner）。
3. **SSRF**：外发请求（AI 服务抓取、文件导入）做 URL 白名单 + 禁内网 IP 段。
4. **越权（Broken Access Control）**：横向（跨合作方）/纵向（角色越权）手工验证。
5. **依赖 CVE**：对 Dependency-Check 报告逐条评级，高危必须升级或加缓解措施。
6. **上传**：类型白名单 + 大小限制 + 存储隔离 + 病毒扫描（设计稿/附件）。

```bash
# DAST（对 staging 环境）
zap-baseline.py -t https://staging.example.com -r zap-report.html
```

**G2**：XSS/IDOR/SSRF/越权 = 0；ZAP High/Medium = 0；上传/SSRF 有缓解措施并留痕。

### 阶段 3：修复与复核（门禁 G3）

1. 按风险排序：高危立即、中危本迭代、低危登记技术债。
2. 修复后重跑 Semgrep/Trivy/Dependency-Check/ZAP，确认 0。
3. 高危必须人工复核代码 diff + 回归测试，**不接受仅工具通过**。

**G3**：全部门禁复跑通过；报告闭环（模板见 [`reference/report-template.md`](reference/report-template.md)）。

## 产物

- 安全审查报告（[`reference/report-template.md`](reference/report-template.md)）。
- Semgrep/Trivy/Dependency-Check/ZAP 原始报告归档。
- 修复 PR 与复核记录。

## 校验

- `semgrep scan` 高危/严重 0；`trivy image` 高危 0；`dependencyCheckAnalyze` 高危 0；ZAP High/Medium 0。
- 密钥无明文、无新增硬编码；越权/IDOR/SSRF/XSS 手工验证记录齐全。

## 常见失败与处置

| 现象 | 处置 |
| --- | --- |
| Semgrep 误报 | 用 `# nosemgrep` 标注并写理由，PR 评审确认；禁止整目录排除。 |
| Dependency-Check 高危无修复版本 | 记录缓解措施（WAF/降权/隔离）并设到期复审。 |
| ZAP 扫描超时 | 缩小范围、排优先级，先扫 P0 接口；staging 数据用脱敏 fixture。 |
| 密钥已入库（历史） | 立即轮换 + `git filter-repo` 清历史 + 接入 secret scanning。 |
| 越权未复现 | 保留手工步骤与数据快照，换权限组合重试，勿把「没测到」当「不存在」。 |

## 验收清单

- [ ] 两遍扫描完成，门禁 G1~G3 通过，高危/严重 = 0，中危有处置计划。
- [ ] 报告闭环，修复有 diff + 回归测试佐证。
- [ ] 密钥无明文入库，敏感数据出域有缓解。
