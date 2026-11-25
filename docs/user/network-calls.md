# Network calls M3 Code makes

M3 Code sends no product analytics, crash reports, traces, Clerk auth beacons, Expo OTA pings,
cloud relay traffic, Cloudflare tunnels, or undocumented provider usage/credit probes anywhere.
Nothing leaves your machine except traffic you or your tools explicitly initiate:

- **Connection model (Tailscale-only)**: T3 Connect, Clerk OAuth, Cloudflare Tunnel (`cloudflared`),
  relay push notifications, and guest links are hard-disabled via
  `packages/shared/src/forkCompliance.ts`. Remote access (including from mobile browsers) goes
  directly over your private Tailscale network.
- **Provider traffic (official interfaces only)**:
  - **Google Antigravity**: runs exclusively through Google's official `agy acp` CLI with
    `--disable-telemetry`. Undocumented `v1internal` Cloud Code probing is removed.
  - **OpenAI / ChatGPT Codex**: runs through official `@openai/codex` (`codex app-server`) and
    OpenAI's official Dynamic Agent Client OAuth 2.0 + PKCE flow (`https://auth.openai.com` /
    `https://api.openai.com/v1`).
  - **Blocked unofficial probes**: CLIProxyAPI hub scraping (`chatgpt.com/backend-api/wham/*`,
    spoofed `Originator: Codex Desktop` / `claude-code` / `grok-cli` headers), undocumented Claude
    reset-credit endpoints (`/api/oauth/usage?cedar_ember=1`, `/api/organizations/*/reset_rate_limits`),
    and Grok billing probes (`cli-chat-proxy.grok.com/v1/billing`) are disabled by
    `FORK_COMPLIANCE`.
- **Desktop app updates**: automatic background update checks are disabled by default
  (`FORK_COMPLIANCE.allowAutoUpdateChecks = false`, unmanaged policy `mode: "off"`).
- **Explicit update / release lookups**: only occur if you explicitly trigger a provider CLI update
  check or release lookup.

Diagnostics such as process CPU and memory history, server logs, and local crash logs stay on your
devices until you copy or share them yourself.
