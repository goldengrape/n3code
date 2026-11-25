#!/usr/bin/env bash
# Checks that what this fork added is still there and what it removed has not come back.
# Run after merging upstream. Edit the lists below when the fork changes.
set -u
cd "$(git rev-parse --show-toplevel)"
bad=0

# Fork-only paths that must keep existing.
required=(
  MIA_CHANGELOG.md
  docs/compliance-report.md
  packages/provider-omp
  packages/provider-noname
  packages/shared/src/forkCompliance.ts
  packages/shared/src/forkCompliance.test.ts
  apps/server/src/inference
  apps/server/src/inference/InferenceGateway.ts
)
for p in "${required[@]}"; do
  if [ -z "$(git ls-files -- "$p")" ]; then echo "Missing fork path: $p"; bad=1; fi
done

# Fork compliance policy must keep all non-compliant / non-Tailscale toggles off.
for flag in allowCloudRelay allowCliproxyUsageHub allowUndocumentedProviderProbes allowAutoUpdateChecks; do
  if ! grep -Eq "^[[:space:]]*${flag}:[[:space:]]*false," packages/shared/src/forkCompliance.ts; then
    echo "Compliance flag not set to false in packages/shared/src/forkCompliance.ts: $flag"
    bad=1
  fi
done

# Every pluggable compliance hook must stay wired after upstream merges.
compliance_hooks=(
  apps/server/src/cloud/publicConfig.ts
  apps/server/src/cloud/ManagedEndpointRuntime.ts
  apps/server/src/relay/AgentAwarenessRelay.ts
  apps/web/src/cloud/publicConfig.ts
  apps/server/src/usage/UsageLimitSources.ts
  apps/web/src/components/settings/UsageProviderSettings.tsx
  apps/server/src/provider/claudeResetCredits.ts
  packages/provider-grok/src/server/usageLimits.ts
  apps/desktop/src/updates/DesktopUpdatePolicy.ts
)
for hook in "${compliance_hooks[@]}"; do
  if ! grep -q "FORK_COMPLIANCE" "$hook"; then
    echo "Missing FORK_COMPLIANCE guard in: $hook"
    bad=1
  fi
done

# Undocumented Google Antigravity v1internal / antigravity/hub probing must not return.
if grep -En "v1internal|antigravity/hub|cloudcode-pa" apps/server/src/provider/antigravityUsageLimits.ts | grep -qvE "^[0-9]+:[[:space:]]*\*"; then
  echo "Undocumented Google Antigravity usage probe returned in apps/server/src/provider/antigravityUsageLimits.ts"
  bad=1
fi

# Telemetry removed by this fork must not return.
pkgs='@clerk/|@sentry/|posthog|@opentelemetry/|@effect/opentelemetry'
hits=$(git ls-files -- 'package.json' '**/package.json' 'pnpm-workspace.yaml' ':!:.repos/**' | xargs grep -nE "\"?($pkgs)" 2>/dev/null)
if [ -n "$hits" ]; then echo "Telemetry dependencies present:"; echo "$hits"; bad=1; fi
files=$(git ls-files -- 'packages/shared/src/observability.ts' 'packages/shared/src/otelEnvironment.ts' 'packages/shared/src/telemetryId.ts')
if [ -n "$files" ]; then echo "Telemetry modules present:"; echo "$files"; bad=1; fi

exit $bad
