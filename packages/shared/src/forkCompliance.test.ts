import { assert, describe, it } from "@effect/vitest";

import { FORK_COMPLIANCE } from "./forkCompliance.ts";

describe("FORK_COMPLIANCE", () => {
  it("keeps cloud relay, CLIProxyAPI, undocumented provider probes, and auto-updates disabled", () => {
    assert.deepStrictEqual(FORK_COMPLIANCE, {
      allowCloudRelay: false,
      allowCliproxyUsageHub: false,
      allowUndocumentedProviderProbes: false,
      allowAutoUpdateChecks: false,
    });
  });
});
