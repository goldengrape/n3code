#!/usr/bin/env bash
# Typechecks every package one at a time. `vp run typecheck` runs them in parallel and gets
# OOM-killed on small runners, and it skips the apps. Prints the errors and fails if any.
set -u
cd "$(git rev-parse --show-toplevel)"
bad=0
# Tailscale-only web/desktop fork: mobile client and cloud relay are excluded from active builds.
skip_dirs=(apps/mobile infra/relay)
for d in apps/* infra/* evals scripts packages/*; do
  [ -f "$d/tsconfig.json" ] || continue
  skip=0
  for s in "${skip_dirs[@]}"; do
    [ "$d" = "$s" ] && skip=1 && break
  done
  [ "$skip" -eq 1 ] && continue
  out=$(cd "$d" && vp exec effect-tsgo tsrs --noEmit 2>&1 | grep -v TS377141 | grep -E ' error |error TS')
  if [ -n "$out" ]; then echo "== $d"; echo "$out" | head -20 | cut -c1-240; bad=1; fi
done
exit $bad
