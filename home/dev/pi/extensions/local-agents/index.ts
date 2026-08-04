// Load a project-local `.local/AGENTS.md` as extra context, additively.
//
// Pi's built-in discovery loads `AGENTS.md` / `CLAUDE.md` walking up from the
// cwd (plus the global `~/.pi/agent/AGENTS.md`). It intentionally does not
// look inside a `.local/` subdirectory — that's a conventional spot for
// gitignored, machine- or checkout-specific instructions that shouldn't be
// committed. This extension bridges that gap: if `<cwd>/.local/AGENTS.md`
// exists, its contents are appended to the system prompt.
//
// Additive, not a replacement: whatever pi discovered normally is left
// untouched; we only append. See the "additive approach" discussion — the
// full-replacement route would require disabling built-in discovery with
// `--no-context-files` and rebuilding the prompt, which we deliberately avoid.
//
// Cache-friendly: `before_agent_start` rebuilds the system prompt fresh each
// turn, so appending the same block every turn is idempotent — earlier
// turns' bytes don't change and the provider prefix cache stays warm. We
// re-read the file each turn (cheap) so edits are picked up live.

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Path of the local context file relative to the working directory.
const LOCAL_AGENTS_REL = ".local/AGENTS.md";

// Read `<cwd>/.local/AGENTS.md`, returning its trimmed contents or null when
// the file is absent (or unreadable / empty).
function readLocalAgents(cwd: string): { path: string; content: string } | null {
  const path = resolve(cwd, LOCAL_AGENTS_REL);
  try {
    const content = readFileSync(path, "utf8").trim();
    if (content.length === 0) return null;
    return { path, content };
  } catch {
    // ENOENT (no local file) is the common case; treat any read error as
    // "nothing to inject" rather than surfacing noise into the prompt.
    return null;
  }
}

export default function localAgentsExtension(pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (event) => {
    const cwd = event.systemPromptOptions.cwd;
    if (!cwd) return;

    const local = readLocalAgents(cwd);
    if (!local) return;

    // Skip if pi already loaded this exact file through its own discovery
    // (belt-and-suspenders — built-in discovery doesn't descend into
    // `.local/`, but a future change or symlink could make it appear).
    const already = event.systemPromptOptions.contextFiles?.some(
      (f) => resolve(f.path) === local.path,
    );
    if (already) return;

    // Match pi's own context-file framing (see core/system-prompt.js) so the
    // injected block reads like a first-class project context file.
    return {
      systemPrompt: `${event.systemPrompt}

<project_context>

Project-specific instructions and guidelines:

<project_instructions path="${local.path}">
${local.content}
</project_instructions>

</project_context>
`,
    };
  });
}
