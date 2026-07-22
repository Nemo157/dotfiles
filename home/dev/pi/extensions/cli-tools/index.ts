// Small local pi extension that exposes narrow CLI wrappers as tools.
//
// The permission-system extension denies the raw `bash` tool, so instead of
// letting the agent shell out freely we register one purpose-built tool per
// common task. Individual tools live in sibling files and are collected here.
//
// Two flavours of tool definition are supported (see shared.ts):
//   * Simple wrappers (jj/git): fixed `baseArgs`, plus optional freeform
//     `acceptArgs`. Read-only inspection only.
//   * Structured wrappers (rg, fd): explicit `parameters` schema and a
//     `buildArgs` function that maps typed params to argv. User-supplied
//     paths are appended after a `--` separator so they cannot be
//     misinterpreted as flags.
//
// Keep wrappers small and read-only where possible; anything that mutates
// repo/system state should go through `ask` semantics (see the
// permission-system config in ../../default.nix).

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerCliTool, type CliToolDef } from "./shared";
import { jjTools } from "./jj";
import { gitTools } from "./git";
import { rgTool } from "./rg";
import { fdTool } from "./fd";

export default function (pi: ExtensionAPI) {
  const tools: CliToolDef[] = [...jjTools, ...gitTools, rgTool, fdTool];
  for (const def of tools) {
    registerCliTool(pi, def);
  }
}
