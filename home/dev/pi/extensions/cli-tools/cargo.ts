// Cargo wrappers. Deliberately minimal: only clippy and nextest, both with
// just package-selection knobs. Everything else (build, run, add/remove,
// fmt, doc, tree, metadata) is either redundant with these two, mutating,
// or handled elsewhere (e.g. formatting flows through `jj fix`). Add more
// subcommands here as concrete needs come up.
//
// No `path` param on these tools — cargo runs in `ctx.cwd`. If we later
// need out-of-tree invocation, add `--manifest-path` support then.

import { Type } from "typebox";
import { commandOk, type CliToolDef, type StructuredCliToolDef } from "./shared";

const packageSelection = {
  package: Type.Optional(
    Type.String({
      description: "Restrict to a single workspace member (-p <package>).",
    }),
  ),
  workspace: Type.Optional(
    Type.Boolean({
      description: "Run against every workspace member (--workspace).",
    }),
  ),
};

// --- cargo clippy --------------------------------------------------------

const clippyParams = Type.Object({
  ...packageSelection,
});

export const cargoClippyTool: StructuredCliToolDef<typeof clippyParams> = {
  name: "cargo-clippy",
  label: "cargo clippy",
  command: "cargo",
  partialLabel: "Linting…",
  description: "Lint and type-check a Rust crate or workspace with clippy.",
  promptSnippet: "Lint and type-check Rust code.",
  timeoutMs: 120_000,
  parameters: clippyParams,
  buildArgs(p) {
    const args: string[] = ["clippy"];
    if (p.workspace) args.push("--workspace");
    if (p.package !== undefined) args.push("-p", p.package);
    return args;
  },
};

// --- cargo nextest run ---------------------------------------------------

const nextestParams = Type.Object({
  ...packageSelection,
});

export const cargoNextestTool: StructuredCliToolDef<typeof nextestParams> = {
  name: "cargo-test",
  label: "cargo nextest",
  command: "cargo",
  partialLabel: "Testing…",
  description: "Run the test suite for a Rust crate or workspace.",
  promptSnippet: "Run Rust tests.",
  timeoutMs: 180_000,
  parameters: nextestParams,
  buildArgs(p) {
    const args: string[] = ["nextest", "run"];
    if (p.workspace) args.push("--workspace");
    if (p.package !== undefined) args.push("-p", p.package);
    return args;
  },
};

/**
 * Return the subset of cargo tools whose underlying binaries exist. If
 * `cargo` itself is missing we register nothing (not a Rust dev env). If
 * `cargo nextest` is missing we still register clippy and warn once so the
 * gap is visible on extension load.
 */
export function getCargoTools(): CliToolDef[] {
  if (!commandOk("cargo", ["--version"])) return [];
  const tools: CliToolDef[] = [cargoClippyTool];
  if (commandOk("cargo", ["nextest", "--version"])) {
    tools.push(cargoNextestTool);
  } else {
    console.warn(
      "[cli-tools] cargo is available but `cargo nextest` is not; " +
        "skipping cargo-test. Install cargo-nextest to enable it.",
    );
  }
  return tools;
}
