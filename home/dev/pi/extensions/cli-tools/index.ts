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
//
// Some groups are registered conditionally based on the environment: cargo
// and nix tools require their binaries, and the VCS tools resolve to jj
// *or* git depending on the working directory (see vcs.ts).

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerCliTool, type CliToolDef } from "./shared";
import { getVcsTools } from "./vcs";
import { ghTools } from "./gh";
import { rgTool } from "./rg";
import { fdTool } from "./fd";
import { getCargoTools } from "./cargo";
import { getNixTools } from "./nix";
import { getTarTools } from "./tar";

export default function (pi: ExtensionAPI) {
  const tools: CliToolDef[] = [
    ...getVcsTools(),
    ...ghTools,
    rgTool,
    fdTool,
    ...getCargoTools(),
    ...getNixTools(),
    ...getTarTools(),
  ];
  for (const def of tools) {
    registerCliTool(pi, def);
  }
}
