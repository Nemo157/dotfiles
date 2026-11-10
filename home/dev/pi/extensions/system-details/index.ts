// Inject a `<system-details>` block into the system prompt.
//
// For now this carries just the machine's hostname, so the agent always knows
// which host it is running on without having to guess (there's no `hostname`
// tool in this setup). Kept deliberately small and extensible — additional
// fields (OS, arch, ...) can be added to the block later.
//
// Adds a structured section (`systemPromptOptions.sections`, rendered by pi as
// `<system-details>…</system-details>`) instead of returning `systemPrompt`.
// Returning `systemPrompt` sets `forceSystemPrompt`, freezing the prompt text
// at this handler: later `before_agent_start` handlers' structured edits
// (e.g. codemode-guidance's rule rewrite) then never reach the wire.
//
// Cache-friendly: options are rebuilt from the base each turn, so setting the
// same section every turn is idempotent and pi's section diff stays empty.

import { hostname } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function systemDetailsExtension(pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (event) => {
    event.systemPromptOptions.sections["system-details"] =
      `hostname: ${hostname()}`;
  });
}
