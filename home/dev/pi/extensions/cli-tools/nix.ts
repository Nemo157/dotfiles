// Nix flake wrappers.
//
// `nix-eval` and `nix-build` take attribute paths within the flake in the
// cwd only (the flakeref is pinned to `.`) and hardcode their flags: no
// `--impure`, no passthrough `--option`s (a trusted user could otherwise
// disable the sandbox), and flake `nixConfig` is never accepted. Eval
// additionally disallows IFD so it never triggers builds.
//
// `nix-flake-info` is a read-oriented metadata tool. It's named `nix-flake-info`
// rather than mirroring any single `nix` subcommand so it can aggregate
// several kinds of flake metadata over time. The structured output is
// namespaced under `details.nixFlake` with one key per category (currently
// just `inputs`), leaving room to add more categories without reshaping the
// existing ones.

import { Container, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
  type BaseCliToolFields,
  buildDefaultSpec,
  COLLAPSED_INLINE_MAX_LINES,
  commandOk,
  commandOutput,
  type CliRenderResult,
  type CliRenderSpec,
  type CliToolDef,
  type CliToolDetails,
  type JsonValue,
  type StructuredCliToolDef,
} from "./shared";

// --- nix flake archive --json parsing ------------------------------------

/**
 * Shape of `nix flake archive --json`. It also carries nested `inputs`, but
 * we only surface the top-level input store paths (the `map_values(.path)`
 * of the equivalent jq one-liner).
 */
interface FlakeArchive {
  path?: string;
  inputs?: Record<string, { path?: string } | undefined>;
}

/**
 * Structured details attached under `details.nixFlake`. One key per metadata
 * category so more can be added later without breaking existing consumers.
 */
export interface NixFlakeExtraDetails {
  nixFlake: {
    /** Top-level input name -> store path (present only once fetched). */
    inputs: Record<string, string>;
  };
}

type NixFlakeDetails = CliToolDetails & NixFlakeExtraDetails;

function parseInputs(stdout: string): Record<string, string> {
  const inputs: Record<string, string> = {};
  let data: FlakeArchive;
  try {
    data = JSON.parse(stdout) as FlakeArchive;
  } catch {
    return inputs;
  }
  for (const [name, node] of Object.entries(data.inputs ?? {})) {
    if (node && typeof node.path === "string") inputs[name] = node.path;
  }
  return inputs;
}

// --- postProcess: JSON -> NixFlakeDetails + LLM text ---------------------

function formatFlakeInfo(raw: {
  stdout: string;
  stderr: string;
  exitCode: number | null;
  timedOut: boolean;
}): { content: string; details: NixFlakeExtraDetails; isError: boolean } {
  const empty: NixFlakeExtraDetails = { nixFlake: { inputs: {} } };

  if (raw.timedOut) {
    return {
      content: "nix flake archive timed out",
      details: empty,
      isError: true,
    };
  }
  if (raw.exitCode !== 0) {
    const stderr = raw.stderr.trim();
    return {
      content:
        stderr.length > 0
          ? stderr
          : `nix flake archive failed (exit ${raw.exitCode})`,
      details: empty,
      isError: true,
    };
  }

  const inputs = parseInputs(raw.stdout);
  const names = Object.keys(inputs);
  const content =
    names.length === 0
      ? "No flake inputs."
      : names.map((name) => `${name}\t${inputs[name]}`).join("\n");

  return { content, details: { nixFlake: { inputs } }, isError: false };
}

// --- renderResult: compact summary + expandable listing ------------------

const renderResult: CliRenderResult<NixFlakeDetails> = (
  result,
  opts,
  theme,
  context,
) => {
  const details = result.details as NixFlakeDetails | undefined;
  const nixFlake = details?.nixFlake;

  if (!nixFlake) {
    return buildDefaultSpec(
      result as unknown as Parameters<typeof buildDefaultSpec>[0],
      opts,
      theme,
      context,
    );
  }

  const names = Object.keys(nixFlake.inputs);
  const summary =
    names.length === 0
      ? theme.fg("dim", "no inputs")
      : theme.fg(
          "success",
          `${names.length} input${names.length === 1 ? "" : "s"}`,
        );

  const outLines = names.map(
    (name) =>
      `${theme.fg("accent", name)}  ${theme.fg("dim", nixFlake.inputs[name]!)}`,
  );
  const output =
    outLines.length > 0 ? new Text(outLines.join("\n"), 0, 0) : undefined;

  return { summary, output, outputLines: outLines.length };
};

// --- tool definition -----------------------------------------------------

const params = Type.Object({});

const nixFlakeInfoTool: StructuredCliToolDef<typeof params> = {
  name: "nix-flake-info",
  label: "nix flake info",
  command: "nix",
  description:
    "Show each top-level input's store path for the flake in the current " +
    "directory (fetching inputs into the store as needed).",
  // Fetching inputs into the store can be slow on a cold cache.
  timeoutMs: 120_000,
  parameters: params,
  buildArgs() {
    // Runs in ctx.cwd; nix defaults the flakeref to the current directory.
    return ["flake", "archive", "--json"];
  },
  postProcess(raw) {
    return formatFlakeInfo(raw);
  },
  renderResult,
};

// --- shared helpers for nix-eval / nix-build -----------------------------

// Last N lines of the build log surfaced to the agent on a build failure.
// `--print-build-logs --option log-lines 0` makes nix stream the full log to
// stderr without appending its own truncated summary, so we own the tail.
const FAILURE_TAIL_LINES = 50;

// Placeholder substituted into attribute paths so the agent doesn't need to
// know the host's system double (pure eval has no builtins.currentSystem).
const SYSTEM_PLACEHOLDER = "{system}";

// Never honour `nixConfig` from the flake: the agent can edit flake.nix, and
// accepted settings could e.g. add substituters or disable the sandbox.
const COMMON_FLAGS = ["--option", "accept-flake-config", "false"];

// Harmless stderr chatter: the dirty-tree warning on every invocation of a
// worktree flake, and eval-cache contention when calls run in parallel.
const NOISE_PATTERNS = [
  /^warning: Git tree '.*' is dirty$/,
  /^error \(ignored\): SQLite database '.*' is busy$/,
];

/** Drop {@link NOISE_PATTERNS} lines from nix's stderr. */
function stripNoise(stderr: string): string {
  return stderr
    .split("\n")
    .filter((l) => !NOISE_PATTERNS.some((re) => re.test(l)))
    .join("\n");
}

function tailLines(text: string, n: number): string {
  const lines = text.replace(/\s+$/, "").split("\n");
  return lines.slice(-n).join("\n");
}

/**
 * Turn an attribute path into an installable for the flake in the cwd. The
 * flakeref is pinned to `.`, so the model can only choose the attribute.
 */
function toInstallable(attr: string, system: string | null): string {
  let resolved = attr.trim();
  if (resolved.startsWith(".#")) resolved = resolved.slice(2);
  if (resolved.length === 0) throw new Error("attribute path is empty");
  if (resolved.includes("#")) {
    throw new Error(
      "pass an attribute path within the current flake, not a flakeref",
    );
  }
  if (resolved.includes(SYSTEM_PLACEHOLDER)) {
    if (!system) {
      throw new Error(
        `could not resolve the current system to substitute ${SYSTEM_PLACEHOLDER}`,
      );
    }
    resolved = resolved.split(SYSTEM_PLACEHOLDER).join(system);
  }
  return `.#${resolved}`;
}

function isFailed(raw: {
  exitCode: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
}): boolean {
  return (
    raw.timedOut ||
    raw.signal !== null ||
    (raw.exitCode !== null && raw.exitCode !== 0)
  );
}

/** Streaming renderer: tail the log on stderr while nix runs. */
function makeRenderPartial(
  label: string,
): NonNullable<BaseCliToolFields["renderPartial"]> {
  return (details, theme, expanded): CliRenderSpec => {
    const TAIL = expanded ? 200 : 6;
    const stderr = stripNoise(details.stderr ?? "").replace(/\s+$/, "");
    const lines = stderr.length > 0 ? stderr.split("\n") : [];
    const shown = lines.slice(-TAIL);
    const c = new Container();
    if (shown.length === 0) {
      c.addChild(new Text(theme.fg("warning", `⋮ ${label}`), 0, 0));
      return { summary: "", output: c, outputLines: 1 };
    }
    const hidden = lines.length - shown.length;
    if (hidden > 0) {
      c.addChild(
        new Text(theme.fg("muted", `⋮ ${hidden} earlier line(s)`), 0, 0),
      );
    }
    for (const line of shown) c.addChild(new Text(theme.fg("dim", line), 0, 0));
    c.addChild(new Text(theme.fg("warning", `⋮ ${label}`), 0, 0));
    return {
      summary: "",
      output: c,
      outputLines: shown.length + (hidden > 0 ? 2 : 1),
    };
  };
}

/** Render exactly the LLM-facing content lines as the output block. */
function contentOutput(
  result: { content?: { type: string; text?: string }[] },
  theme: Parameters<CliRenderResult>[2],
  isError: boolean,
): { output?: Text; lines: number } {
  const contentText = (result.content ?? [])
    .filter((p): p is { type: "text"; text: string } => p.type === "text")
    .map((p) => p.text)
    .join("\n")
    .replace(/\s+$/, "");
  const lines = contentText.length > 0 ? contentText.split("\n") : [];
  if (lines.length === 0) return { lines: 0 };
  return {
    output: new Text(
      lines.map((l) => theme.fg(isError ? "error" : "dim", l)).join("\n"),
      0,
      0,
    ),
    lines: lines.length,
  };
}

// --- nix-eval: evaluate an attribute of the current flake ----------------

const nixEvalParams = Type.Object({
  attr: Type.String({
    description:
      "Attribute path within the current flake, e.g. " +
      "`checks.{system}` or `packages.{system}.foo.src`. " +
      "`{system}` is replaced with the host's system (e.g. x86_64-linux).",
  }),
  apply: Type.Optional(
    Type.String({
      description:
        "Nix function applied to the value before printing (--apply), e.g. " +
        "`builtins.attrNames` or `p: p.src.outPath`.",
    }),
  ),
  raw: Type.Optional(
    Type.Boolean({
      description: "Print a string result verbatim (--raw) instead of as JSON.",
    }),
  ),
});

export interface NixEvalExtraDetails {
  nixEval: { installable: string; ok: boolean };
}

function makeNixEvalTool(
  system: string | null,
): StructuredCliToolDef<typeof nixEvalParams> {
  return {
    name: "nix-eval",
    label: "nix eval",
    command: "nix",
    description:
      "Evaluate an attribute of the flake in the current directory and " +
      "print it as JSON (or raw string). Pure evaluation without IFD " +
      "(nothing is built). Derivations print as their " +
      "out path (not built; use nix-build to realise). Avoid forcing huge " +
      "values (whole configs, package sets): narrow with `attr` or reduce " +
      "with `apply` (e.g. `builtins.attrNames`). List flake checks with " +
      "attr `checks.{system}` + apply `builtins.attrNames`.",
    timeoutMs: 120_000,
    parameters: nixEvalParams,
    outputSchema: Type.Object({
      value: Type.Unknown({
        description: "Parsed JSON value (or the raw string with `raw`).",
      }),
    }),
    buildArgs(p) {
      const args = [
        "eval",
        toInstallable(p.attr, system),
        p.raw ? "--raw" : "--json",
        ...COMMON_FLAGS,
        // Eval must not trigger builds; use nix-build for that.
        "--option",
        "allow-import-from-derivation",
        "false",
        // No `restrict-eval`: it also forbids fetching the flake's own
        // locked inputs. Pure mode already requires hashed fetches, and
        // nix-build grants network via FODs anyway.
      ];
      if (p.apply !== undefined) args.push("--apply", p.apply);
      return args;
    },
    displayArgs(p) {
      let installable: string;
      try {
        installable = toInstallable(p.attr, system);
      } catch {
        installable = `.#${p.attr}`;
      }
      const args = ["eval", installable];
      if (p.raw) args.push("--raw");
      if (p.apply !== undefined) args.push("--apply", p.apply);
      return args;
    },
    postProcess(raw) {
      const p = raw.params as { attr: string; raw?: boolean };
      const installable = raw.args[1] ?? p.attr;
      if (isFailed(raw)) {
        const stderr = stripNoise(raw.stderr).trim();
        const header = raw.timedOut
          ? "nix eval timed out (value too large or non-terminating?)"
          : `nix eval failed (exit ${raw.exitCode})`;
        return {
          content: stderr.length > 0 ? `${header}\n\n${stderr}` : header,
          details: { nixEval: { installable, ok: false } },
          isError: true,
        };
      }
      if (p.raw) {
        return {
          content: raw.stdout,
          details: { nixEval: { installable, ok: true } },
          isError: false,
          structured: { value: raw.stdout },
        };
      }
      let value: JsonValue | undefined;
      let content = raw.stdout.trim();
      try {
        value = JSON.parse(content) as JsonValue;
        // Pretty-print for legibility; clampForLlm bounds the size.
        content = JSON.stringify(value, null, 2);
      } catch {
        // leave as-is
      }
      return {
        content,
        details: { nixEval: { installable, ok: true } },
        isError: false,
        ...(value !== undefined ? { structured: { value } } : {}),
      };
    },
    renderPartial: makeRenderPartial("Evaluating…"),
    // Show exactly the postProcess content (the value, or the filtered
    // error) rather than the raw stdout/stderr.
    renderResult(result, _opts, theme, context) {
      const { output, lines } = contentOutput(
        result as { content?: { type: string; text?: string }[] },
        theme,
        context.isError,
      );
      if (context.isError) {
        return {
          summary: "",
          status: theme.fg("error", "eval failed"),
          output,
          outputLines: lines,
        };
      }
      return {
        summary: theme.fg("success", `${lines} line${lines === 1 ? "" : "s"}`),
        output,
        outputLines: lines,
      };
    },
  };
}

// --- nix-build: build attributes of the current flake --------------------

const nixBuildParams = Type.Object({
  attrs: Type.Array(Type.String(), {
    minItems: 1,
    description:
      "Attribute paths within the current flake to build together, e.g. " +
      "`checks.{system}.foo` or `packages.{system}.foo.src`. " +
      "`{system}` is replaced with the host's system.",
  }),
  dryRun: Type.Optional(
    Type.Boolean({
      description:
        "Only report what would be built locally and what fetched from " +
        "caches (--dry-run). Use before builds that might be expensive.",
    }),
  ),
  substituteOnly: Type.Optional(
    Type.Boolean({
      description:
        "Fail instead of building anything locally (--max-jobs 0); only " +
        "fetch from binary caches (remote builders may still build). " +
        "Uncached source fetches count as local builds and fail too; " +
        "`<pkg>.src` is usually just a download, so build it directly.",
    }),
  ),
});

/** Shape of `nix build --json` output. */
interface NixBuildResult {
  drvPath?: string;
  outputs?: Record<string, string | undefined>;
}

export interface NixBuildExtraDetails {
  nixBuild: {
    mode: "build" | "dry-run";
    attrs: string[];
    passed: boolean;
  };
}

type NixBuildDetails = CliToolDetails & NixBuildExtraDetails;

function makeNixBuildTool(
  system: string | null,
): StructuredCliToolDef<typeof nixBuildParams> {
  const renderResult: CliRenderResult<NixBuildDetails> = (
    result,
    opts,
    theme,
    context,
  ) => {
    const nb = (result.details as NixBuildDetails | undefined)?.nixBuild;
    if (!nb) {
      return buildDefaultSpec(
        result as unknown as Parameters<typeof buildDefaultSpec>[0],
        opts,
        theme,
        context,
      );
    }
    const { output, lines } = contentOutput(
      result as { content?: { type: string; text?: string }[] },
      theme,
      context.isError,
    );
    const what =
      nb.attrs.length === 1 ? nb.attrs[0]! : `${nb.attrs.length} attrs`;
    if (nb.mode === "dry-run") {
      return {
        summary: theme.fg("success", `dry run: ${what}`),
        output,
        outputLines: lines,
      };
    }
    if (nb.passed) {
      // Keep the out paths behind expansion: a line count over the inline
      // cap makes the collapsed row show just "<attr> built".
      return {
        summary: theme.fg("success", `${what} built`),
        output,
        outputLines: COLLAPSED_INLINE_MAX_LINES + 1,
      };
    }
    return {
      summary: "",
      status: theme.fg("error", `${what} failed`),
      output,
      outputLines: lines,
    };
  };

  return {
    name: "nix-build",
    label: "nix build",
    command: "nix",
    partialLabel: "Building…",
    description:
      "Build one or more attributes of the flake in the current directory " +
      "(no result symlinks) and return their store paths. On failure " +
      "returns the build log tail (with the failing drv path for nix-log). " +
      "Run flake checks via `checks.{system}.<name>` (list them with " +
      "nix-eval). " +
      "Use `dryRun` first when a build might be large. Building " +
      "`<pkg>.src` fetches a package's source.",
    // Builds may compile; allow plenty of time.
    timeoutMs: 1_800_000,
    parameters: nixBuildParams,
    buildArgs(p) {
      const args = [
        "build",
        ...p.attrs.map((a) => toInstallable(a, system)),
        "--no-link",
        ...COMMON_FLAGS,
      ];
      if (p.substituteOnly) args.push("--max-jobs", "0");
      if (p.dryRun) {
        args.push("--dry-run");
      } else {
        args.push(
          "--json",
          "--keep-going",
          "--print-build-logs",
          "--option",
          "log-lines",
          "0",
        );
      }
      return args;
    },
    // Present the user's intent; hide machine-oriented flags.
    displayArgs(p) {
      const installables = p.attrs.map((a) => {
        try {
          return toInstallable(a, system);
        } catch {
          return `.#${a}`;
        }
      });
      const args = ["build", ...installables];
      if (p.substituteOnly) args.push("--max-jobs", "0");
      if (p.dryRun) args.push("--dry-run");
      return args;
    },
    postProcess(raw) {
      const p = raw.params as {
        attrs: string[];
        dryRun?: boolean;
      };
      // Report attrs with `{system}` substituted (buildArgs already
      // validated them, so this can't throw).
      const attrs = p.attrs.map((a) => toInstallable(a, system).slice(2));
      const mode = p.dryRun ? "dry-run" : "build";
      const failed = isFailed(raw);

      if (failed) {
        // On failure nix emits no JSON; the streamed log tail on stderr
        // carries the failing drvPath for nix-log.
        const tail = tailLines(stripNoise(raw.stderr), FAILURE_TAIL_LINES);
        const header = raw.timedOut
          ? "nix build timed out"
          : `nix build failed (exit ${raw.exitCode})`;
        return {
          content: tail.length > 0 ? `${header}\n\n${tail}` : header,
          details: { nixBuild: { mode, attrs, passed: false } },
          isError: true,
        };
      }

      if (p.dryRun) {
        const stderr = stripNoise(raw.stderr).trim();
        return {
          content:
            stderr.length > 0
              ? stderr
              : "Nothing to build or fetch; all outputs are already valid.",
          details: { nixBuild: { mode, attrs, passed: true } },
          isError: false,
        };
      }

      let parsed: NixBuildResult[] = [];
      try {
        const v = JSON.parse(raw.stdout) as unknown;
        if (Array.isArray(v)) parsed = v as NixBuildResult[];
      } catch {
        // leave empty
      }
      const lines: string[] = [];
      const structuredResults: JsonValue[] = [];
      parsed.forEach((r, i) => {
        // nix reports results in installable order.
        const attr = parsed.length === attrs.length ? attrs[i]! : `#${i}`;
        const outputs: Record<string, string> = {};
        for (const [name, path] of Object.entries(r.outputs ?? {})) {
          if (typeof path === "string") outputs[name] = path;
        }
        lines.push(`${attr}:`);
        if (r.drvPath) lines.push(`  drv: ${r.drvPath}`);
        for (const [name, path] of Object.entries(outputs)) {
          lines.push(`  ${name}: ${path}`);
        }
        structuredResults.push({
          attr,
          drvPath: r.drvPath ?? null,
          outputs,
        });
      });
      return {
        content: lines.length > 0 ? lines.join("\n") : "built",
        details: { nixBuild: { mode, attrs, passed: true } },
        isError: false,
        structured: { results: structuredResults },
      };
    },
    outputSchema: Type.Object({
      results: Type.Array(
        Type.Object({
          attr: Type.String(),
          drvPath: Type.Union([Type.String(), Type.Null()]),
          outputs: Type.Record(Type.String(), Type.String()),
        }),
      ),
    }),
    renderPartial: makeRenderPartial("Building…"),
    renderResult,
  };
}

// --- nix-log: build log for a derivation ---------------------------------

const nixLogParams = Type.Object({
  drvPath: Type.String({
    description: "Derivation or store path to fetch the build log for.",
  }),
});

const nixLogTool: StructuredCliToolDef<typeof nixLogParams> = {
  name: "nix-log",
  label: "nix log",
  command: "nix",
  description:
    "Show the build log for a derivation or store path, e.g. the drvPath " +
    "reported by a failed nix-build.",
  timeoutMs: 60_000,
  parameters: nixLogParams,
  buildArgs(p) {
    return ["log", p.drvPath];
  },
};

/**
 * Return the nix tools whose underlying binary exists. If `nix` is missing
 * (not a Nix environment) we register nothing. The current system is
 * resolved once for the `{system}` placeholder; if that probe fails the
 * tools still register but reject attributes using the placeholder.
 */
export function getNixTools(): CliToolDef[] {
  if (!commandOk("nix", ["--version"])) return [];
  const system = commandOutput("nix", [
    "eval",
    "--raw",
    "--impure",
    "--expr",
    "builtins.currentSystem",
  ]);
  if (!system) {
    console.warn(
      "[cli-tools] nix is available but resolving builtins.currentSystem " +
        "failed; `{system}` placeholders will be rejected.",
    );
  }
  return [
    nixFlakeInfoTool,
    makeNixEvalTool(system),
    makeNixBuildTool(system),
    nixLogTool,
  ];
}
