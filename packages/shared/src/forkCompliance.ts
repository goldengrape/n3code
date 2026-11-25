/**
 * Central fork compliance and connection policy for n3code.
 *
 * Keeping these switches in a single fork-protected module lets upstream syncs
 * merge cleanly while enforcing:
 * - Tailscale-only remote access (no T3 Connect, Clerk, Cloudflare Tunnel, or Relay).
 * - Strict provider ToS compliance (no CLIProxyAPI scraping, no spoofed headers,
 *   no undocumented internal API probes for Google/OpenAI/Anthropic/xAI).
 * - No automatic background update checks.
 */
export interface ForkCompliancePolicy {
  /** Disables T3 Connect, Clerk OAuth, Cloudflare Tunnel, Relay push, and Guest links. */
  readonly allowCloudRelay: boolean;
  /** Disables CLIProxyAPI hub (undocumented chatgpt.com/backend-api/wham, spoofed headers). */
  readonly allowCliproxyUsageHub: boolean;
  /** Disables undocumented provider usage/credit probes (Claude cedar_ember, Grok billing, Antigravity v1internal). */
  readonly allowUndocumentedProviderProbes: boolean;
  /** Disables automatic background update checks (desktop updater defaults to off). */
  readonly allowAutoUpdateChecks: boolean;
}

export const FORK_COMPLIANCE: ForkCompliancePolicy = {
  allowCloudRelay: false,
  allowCliproxyUsageHub: false,
  allowUndocumentedProviderProbes: false,
  allowAutoUpdateChecks: false,
};
