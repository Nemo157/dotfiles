// Replace pi's built-in `codemode` rule bullet with a narrower one.
//
// The built-in guideline ("Use codemode to batch independent tool calls
// (Promise.allSettled), chain them, or filter large output, instead of many
// separate calls.") pushes the model to wrap plain parallel reads/searches in
// scripts. That saves nothing: full file contents cost the same tokens either
// way, everything shares one `max_output_tokens` budget, and scripts tend to
// `JSON.stringify` structured tool results (fd/rg/jq), which is noisier than
// the tools' native text output. Codemode only pays off when the script
// shrinks what reaches the model or chains dependent calls.
//
// Cache-friendly: the same mutation is applied every turn, so after the first
// turn's patch the prompt stays byte-identical.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const GUIDELINES = [
  "For independent reads/searches, make parallel direct tool calls (read, rg, fd, ...) rather than wrapping them in codemode.",
  "Use codemode only when the script reduces what reaches you (filtering, slicing, counting, extracting fields) or chains calls that depend on earlier results; return concise text, not JSON.stringify'd tool results.",
];

export default function codemodeGuidanceExtension(pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (event) => {
    const guidelines = event.systemPromptOptions.toolGuidelines;
    if (guidelines && "codemode" in guidelines) {
      guidelines.codemode = [...GUIDELINES];
    }
  });
}
