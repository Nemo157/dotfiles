// Inject a `<system-details>` block into the system prompt.
//
// For now this carries just the machine's hostname, so the agent always knows
// which host it is running on without having to guess (there's no `hostname`
// tool in this setup). Kept deliberately small and extensible — additional
// fields (OS, arch, ...) can be added to the block later.
//
// Cache-friendly: `before_agent_start` rebuilds the system prompt fresh each
// turn, so appending the same block every turn is idempotent and keeps the
// provider prefix cache warm.

import { hostname } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function systemDetailsExtension(pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt: `${event.systemPrompt}

<system-details>
hostname: ${hostname()}
</system-details>
`,
    };
  });
}
