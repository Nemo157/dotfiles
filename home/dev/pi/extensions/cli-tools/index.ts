// Small local pi extension that exposes narrow CLI wrappers as tools.
//
// The permission-system extension denies the raw `bash` tool, so instead of
// letting the agent shell out freely we register one purpose-built tool per
// common task. Individual tools live in sibling files and are collected here.
//
// Every wrapper is structured (see shared.ts): an explicit `parameters`
// schema plus a `buildArgs` function that maps typed params to argv. This
// keeps the exposed surface read-only (no freeform passthrough args) and
// appends any user-supplied path after a `--` separator so it cannot be
// misinterpreted as a flag.
//
// Keep wrappers small and read-only where possible; anything that mutates
// repo/system state should go through `ask` semantics (see the
// permission-system config in ../../default.nix).

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerCliTool, type CliToolDef } from "./shared";
import { jjTools } from "./jj";
import { gitTools } from "./git";
import { ghTools } from "./gh";
import { rgTool } from "./rg";
import { fdTool } from "./fd";
import { getCargoTools } from "./cargo";
import { getNixTools } from "./nix";

export default function (pi: ExtensionAPI) {
  const tools: CliToolDef[] = [
    ...jjTools,
    ...gitTools,
    ...ghTools,
    rgTool,
    fdTool,
    ...getCargoTools(),
    ...getNixTools(),
  ];
  for (const def of tools) {
    registerCliTool(pi, def);
  }
}
