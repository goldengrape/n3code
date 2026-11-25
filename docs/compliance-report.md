# Compliance & Privacy Audit Report / 合规与隐私审计报告

> Language / 语言: [中文](#中文报告) | [English](#english-report)

---

<a id="中文报告"></a>
## 中文报告

### 1. 审计目标与基线要求

本报告记录对 `n3code`（基于上游 `pingdotgg/t3code` 的隐私强化分支）的**服务条款合规（重点关注 Google / Antigravity 与 OpenAI / ChatGPT / Codex）**及**隐私与网络外连合规**核查结论与修订措施。

基线需求：
1. **仅使用 Tailscale 连接**：不启用 T3 Connect、Clerk 认证、Cloudflare Tunnel、第三方 Relay 推送或访客链接；移动端仅通过浏览器直连 Tailscale，不维护原生移动端客户端。
2. **严格遵守厂商服务条款（ToS）**：特别是 Google（使用 Antigravity 登录额度）与 OpenAI（使用 ChatGPT 登录额度），仅使用官方 CLI / SDK / OAuth 协议，禁止调用未公开内部 API 或伪造客户端请求头。
3. **隐私合规与零静默外连**：无产品分析遥测、无崩溃上报、无静默后台自动更新检查。
4. **可插拔、低冲突的上游同步能力**：所有合规开关集中管理，以极简守卫接入上游边界，并通过自动化脚本防止上游更新时发生合规回退。

---

### 2. Google / Antigravity 合规核查

| 核查项 | 现状与结论 | 代码位置 |
| --- | --- | --- |
| 运行与通信方式 | **合规**。仅通过 Google 官方 `agy acp --disable-telemetry` CLI 通信，不直接拼接或调用未公开后端接口。 | `apps/server/src/provider/antigravityAuthSupport.ts` |
| OAuth 登录流程 | **合规**。无硬编码 Google OAuth Client ID/Secret；校验 CLI 输出的授权地址必须为 `accounts.google.com/o/oauth2/`，回调仅限本机回环或官方 `antigravity.google/oauth-callback`。 | `apps/server/src/provider/antigravityAuthSupport.ts`、`apps/server/src/provider/antigravityCallback.ts` |
| 凭证存储与隔离 | **合规**。Token 由官方 `agy` 进程管理并存放于隔离的 `GEMINI_HOME` 目录下；不再读取系统钥匙串提取 Google 令牌。 | `apps/server/src/provider/antigravityAuthSupport.ts` |
| 未公开额度探测 | **已移除并加锁**。此前探测 Google `v1internal` Cloud Code 接口及伪造 `antigravity/hub` UA 的逻辑已移除；已在 `scripts/check-fork-invariants.sh` 加入防回归检查。 | `apps/server/src/provider/antigravityUsageLimits.ts`、`scripts/check-fork-invariants.sh` |

---

### 3. OpenAI / ChatGPT / Codex 合规核查

| 核查项 | 现状与结论 | 代码位置 |
| --- | --- | --- |
| 本地 Codex 模式 | **合规**。封装官方 `@openai/codex`（`codex app-server`），速率限制与额度数据来自官方协议通知。 | `apps/server/src/provider/Drivers/CodexDriver.ts`、`apps/server/src/provider/codexUsageLimits.ts` |
| ChatGPT 登录（托管模式） | **合规**。使用 OpenAI 官方 OIDC 发现（`https://auth.openai.com/.well-known/openid-configuration`）、OAuth 2.0 + PKCE 动态客户端注册（`dynamic_agent_client` -> `oaiapp_*`、`chatgpt.tokens.use.direct`）与 JWKS 校验，直接请求官方 `https://api.openai.com/v1`，不抓取 ChatGPT 网页后台接口。 | `apps/server/src/provider/CodexChatGptAuth.ts`、`apps/server/src/provider/CodexManagedRuntime.ts` |
| CLIProxyAPI 中转抓取 | **高风险（已阻断）**。上游支持通过 CLIProxyAPI 请求未公开接口 `chatgpt.com/backend-api/wham/*` 并伪造 `Originator: "Codex Desktop"` 请求头。现已通过 `FORK_COMPLIANCE.allowCliproxyUsageHub = false` 在服务端与前端同步硬禁用。 | `apps/server/src/usage/UsageLimitSources.ts`、`apps/web/src/components/settings/UsageProviderSettings.tsx` |

---

### 4. 其他 Provider 合规核查

| 组件 | 风险等级 | 问题描述 | 处置措施 |
| --- | --- | --- | --- |
| CLIProxyAPI（Anthropic / xAI） | **高** | 请求未公开接口 `api.anthropic.com/api/oauth/usage`、`cli-chat-proxy.grok.com/v1/billing`，并伪造 `claude-code/...`、`grok-cli/...` UA。 | 由 `FORK_COMPLIANCE.allowCliproxyUsageHub = false` 阻断。 |
| Claude Reset Credits | **高** | 直接读取 `.credentials.json` 中的私有 OAuth Token，伪造 `claude-cli/...` UA，调用未公开接口 `/api/oauth/usage?cedar_ember=1` 与 `/api/organizations/*/reset_rate_limits`。 | 在 `apps/server/src/provider/claudeResetCredits.ts` 由 `FORK_COMPLIANCE.allowUndocumentedProviderProbes = false` 阻断。 |
| Grok 用量探测 | **中** | 读取 `~/.grok/auth.json` 并直接请求 `cli-chat-proxy.grok.com/v1/billing`。 | 在 `packages/provider-grok/src/server/usageLimits.ts` 由 `FORK_COMPLIANCE.allowUndocumentedProviderProbes = false` 阻断。 |

---

### 5. 隐私、自动更新与仅 Tailscale 连接架构

- **零遥测与崩溃上报**：仓库中已无 PostHog、Sentry、Clerk、OpenTelemetry 等第三方 SDK；Web 字体全部本地打包，不请求 Google Fonts 或外部 CDN 脚本。
- **仅 Tailscale 连接（硬禁用云端中转）**：
  - `apps/server/src/cloud/publicConfig.ts` 与 `apps/web/src/cloud/publicConfig.ts` 均绑定 `FORK_COMPLIANCE.allowCloudRelay = false`，即使注入云端环境变量也无法启用 T3 Connect / Clerk。
  - `apps/server/src/cloud/ManagedEndpointRuntime.ts` 直接短路 `reconcileConfig`，永不拉起 `cloudflared` 隧道。
  - `apps/server/src/relay/AgentAwarenessRelay.ts` 直接短路 `start` 与 `publishThreadUnsafe`，不启动后台推送协程，不向外发送线程标题或状态。
- **零静默自动更新**：
  - `apps/desktop/src/updates/DesktopUpdatePolicy.ts` 将默认未托管策略改为 `mode: "off"`、`allowNightly: false`（由 `FORK_COMPLIANCE.allowAutoUpdateChecks = false` 控制），避免桌面端启动后定时向 GitHub Releases 发包。
- **精简移动端与 Relay**：
  - 在 `scripts/typecheck-all.sh` 中排除 `apps/mobile` 与 `infra/relay`，日常仅构建与校验 `server + web + desktop`。
  - 保留目录文件本身（不在 git 中物理删除），从而避免上游更新移动端或 Relay 时产生大量 `delete/modify` 合并冲突。

---

### 6. 可插拔设计与上游同步保障

1. **单一真相来源**：`packages/shared/src/forkCompliance.ts`（受 `scripts/fork-protected.txt` 保护）集中管理全部 4 个合规布尔开关，配套单元测试 `packages/shared/src/forkCompliance.test.ts`。
2. **极简边界接入**：每处上游文件仅增加 1~7 行守卫代码，合并上游更新时冲突概率极低。
3. **自动防回归门禁**：`scripts/check-fork-invariants.sh`（被 `.github/workflows/upstream-sync.yml` 自动执行）会在每次合并上游后校验：
   - `forkCompliance.ts` 存在且全部 4 个开关均为 `false`；
   - 全部 9 处边界守卫文件仍包含 `FORK_COMPLIANCE` 引用；
   - `antigravityUsageLimits.ts` 未带回 `v1internal` / `antigravity/hub` / `cloudcode-pa`；
   - 未重新引入任何遥测 / Clerk / Sentry / PostHog / OpenTelemetry 依赖。

---

<a id="english-report"></a>
## English Report

### 1. Audit Scope & Baseline Requirements

This report documents the **provider Terms of Service (ToS) compliance audit** (with emphasis on **Google / Antigravity** and **OpenAI / ChatGPT / Codex**) and **privacy / network egress audit** for `n3code` (a privacy-hardened fork of `pingdotgg/t3code`), together with the pluggable remediations applied.

Baseline requirements:
1. **Tailscale-only connectivity**: Disable T3 Connect, Clerk auth, Cloudflare Tunnel, third-party relay push notifications, and guest links. Mobile access uses a mobile web browser over Tailscale rather than a native mobile app.
2. **Strict provider ToS compliance**: Especially for Google (Antigravity login quota) and OpenAI (ChatGPT login quota)—use official CLIs, SDKs, and OAuth flows only; prohibit undocumented internal API probes and spoofed first-party headers.
3. **Privacy compliance & zero silent egress**: No product analytics, no crash reporting, and no automatic background update checks.
4. **Pluggable, low-conflict upstream sync**: Centralize all compliance toggles in one fork-protected module, wire minimal guards at upstream boundaries, and enforce invariants automatically on every upstream merge.

---

### 2. Google / Antigravity Compliance

| Area | Status & Finding | Source |
| --- | --- | --- |
| Execution & Protocol | **Compliant**. Delegates exclusively to Google's official `agy acp --disable-telemetry` CLI; makes no direct calls to undocumented internal endpoints. | `apps/server/src/provider/antigravityAuthSupport.ts` |
| OAuth Flow | **Compliant**. No hardcoded Google OAuth client ID or secret. Validates that CLI-emitted auth URLs target `accounts.google.com/o/oauth2/` with loopback or official `antigravity.google/oauth-callback`. | `apps/server/src/provider/antigravityAuthSupport.ts`, `apps/server/src/provider/antigravityCallback.ts` |
| Credential Storage | **Compliant**. Tokens are owned by `agy` inside an isolated per-instance `GEMINI_HOME`; no OS keyring extraction for Google tokens. | `apps/server/src/provider/antigravityAuthSupport.ts` |
| Undocumented Usage Probe | **Removed & Guarded**. Probing Google's undocumented `v1internal` Cloud Code endpoints with a spoofed `antigravity/hub` User-Agent was removed and is now regression-checked in `scripts/check-fork-invariants.sh`. | `apps/server/src/provider/antigravityUsageLimits.ts`, `scripts/check-fork-invariants.sh` |

---

### 3. OpenAI / ChatGPT / Codex Compliance

| Area | Status & Finding | Source |
| --- | --- | --- |
| Local Codex Mode | **Compliant**. Wraps official `@openai/codex` (`codex app-server`); rate-limit snapshots come from official protocol notifications. | `apps/server/src/provider/Drivers/CodexDriver.ts`, `apps/server/src/provider/codexUsageLimits.ts` |
| Managed Codex / ChatGPT Login | **Compliant**. Uses OpenAI's official OIDC discovery (`https://auth.openai.com/.well-known/openid-configuration`), OAuth 2.0 + PKCE Dynamic Agent Client registration (`dynamic_agent_client` -> `oaiapp_*`, `chatgpt.tokens.use.direct`), and JWKS verification against `https://api.openai.com/v1`. Does not scrape ChatGPT web backend APIs. | `apps/server/src/provider/CodexChatGptAuth.ts`, `apps/server/src/provider/CodexManagedRuntime.ts` |
| CLIProxyAPI Hub Scraping | **High Risk (Blocked)**. Upstream supports probing undocumented `chatgpt.com/backend-api/wham/*` endpoints via CLIProxyAPI with spoofed `Originator: "Codex Desktop"` headers. Now hard-disabled on both server and web UI via `FORK_COMPLIANCE.allowCliproxyUsageHub = false`. | `apps/server/src/usage/UsageLimitSources.ts`, `apps/web/src/components/settings/UsageProviderSettings.tsx` |

---

### 4. Other Providers

| Component | Risk | Finding | Remediation |
| --- | --- | --- | --- |
| CLIProxyAPI (Anthropic / xAI) | **High** | Calls undocumented `api.anthropic.com/api/oauth/usage` and `cli-chat-proxy.grok.com/v1/billing` with spoofed `claude-code/...` and `grok-cli/...` User-Agents. | Blocked by `FORK_COMPLIANCE.allowCliproxyUsageHub = false`. |
| Claude Reset Credits | **High** | Reads Claude Code's private `.credentials.json` OAuth token, spoofs `claude-cli/...` User-Agent, and calls undocumented `/api/oauth/usage?cedar_ember=1` and `/api/organizations/*/reset_rate_limits`. | Blocked in `apps/server/src/provider/claudeResetCredits.ts` via `FORK_COMPLIANCE.allowUndocumentedProviderProbes = false`. |
| Grok Usage Probe | **Medium** | Reads `~/.grok/auth.json` and calls undocumented `cli-chat-proxy.grok.com/v1/billing`. | Blocked in `packages/provider-grok/src/server/usageLimits.ts` via `FORK_COMPLIANCE.allowUndocumentedProviderProbes = false`. |

---

### 5. Privacy, Auto-Updates & Tailscale-Only Posture

- **Zero Telemetry / Crash Reporting**: All third-party analytics/crash SDKs (PostHog, Sentry, Clerk, OpenTelemetry) are absent; fonts are bundled locally with zero external CDN beacons.
- **Tailscale-Only Networking (Cloud Relay Hard-Disabled)**:
  - `apps/server/src/cloud/publicConfig.ts` and `apps/web/src/cloud/publicConfig.ts` bind `hasCloudPublicConfig` to `FORK_COMPLIANCE.allowCloudRelay = false`, preventing T3 Connect / Clerk activation even if env vars are present.
  - `apps/server/src/cloud/ManagedEndpointRuntime.ts` short-circuits `reconcileConfig` to `disabled`, ensuring `cloudflared` is never spawned.
  - `apps/server/src/relay/AgentAwarenessRelay.ts` short-circuits `start` and `publishThreadUnsafe`, spawning no background relay fibers and publishing no thread titles or status externally.
- **No Silent Auto-Update Polling**:
  - `apps/desktop/src/updates/DesktopUpdatePolicy.ts` defaults unmanaged desktop builds to `mode: "off"` and `allowNightly: false` via `FORK_COMPLIANCE.allowAutoUpdateChecks = false`, eliminating background checks against GitHub Releases.
- **Streamlined Surface Without Merge Conflicts**:
  - `scripts/typecheck-all.sh` skips `apps/mobile` and `infra/relay`, focusing verification on `server + web + desktop`.
  - Both directories remain untouched in git rather than deleted so upstream merges never trigger `delete/modify` conflicts.

---

### 6. Pluggable Architecture & Automated Upstream Sync Guardrails

1. **Single Source of Truth**: `packages/shared/src/forkCompliance.ts` (protected via `scripts/fork-protected.txt`, tested by `packages/shared/src/forkCompliance.test.ts`) defines all four compliance switches in one place.
2. **Minimal Boundary Hooks**: Each upstream file contains only a 1–7 line guard referencing `FORK_COMPLIANCE`, keeping upstream merge conflicts negligible.
3. **Automated Invariant Verification**: `scripts/check-fork-invariants.sh` (run automatically by `.github/workflows/upstream-sync.yml`) verifies after every upstream merge that:
   - `packages/shared/src/forkCompliance.ts` exists and all four flags remain `false`;
   - All nine boundary hook files retain their `FORK_COMPLIANCE` guards;
   - `apps/server/src/provider/antigravityUsageLimits.ts` contains no `v1internal`, `antigravity/hub`, or `cloudcode-pa` regression;
   - No telemetry, Clerk, Sentry, PostHog, or OpenTelemetry dependencies have been reintroduced.
