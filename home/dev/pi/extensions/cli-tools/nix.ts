// Nix flake wrappers.
//
// So far just one read-oriented metadata tool. It's named `nix-flake-info`
// rather than mirroring any single `nix` subcommand so it can aggregate
// several kinds of flake metadata over time. The structured output is
// namespaced under `details.nixFlake` with one key per category (currently
// just `inputs`), leaving room to add more categories without reshaping the
// existing ones.

import { Container, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
  buildDefaultSpec,
  COLLAPSED_INLINE_MAX_LINES,
  commandOk,
  commandOutput,
  type CliRenderResult,
  type CliRenderSpec,
  type CliToolDef,
  type CliToolDetails,
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
    return { content: "nix flake archive timed out", details: empty, isError: true };
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

// --- nix-flake-check: list or run flake checks ---------------------------

// Last N lines of the build log surfaced to the agent on a check failure.
// `--print-build-logs --option log-lines 0` makes nix stream the full log to
// stderr without appending its own truncated summary, so we own the tail.
const FAILURE_TAIL_LINES = 50;

/**
 * Extra structured details for `nix-flake-check`, namespaced under
 * `flakeCheck`. `mode` distinguishes listing from running; the other fields
 * are populated per mode.
 */
export interface NixFlakeCheckExtraDetails {
  flakeCheck: {
    mode: "list" | "run";
    /** Available check names (list mode). */
    checks?: string[];
    /** The check that was run (run mode). */
    check?: string;
    /** Whether the run succeeded (run mode). */
    passed?: boolean;
    /** Derivation path of the run check (run mode, success). */
    drvPath?: string;
    /** Output store path of the run check (run mode, success). */
    outPath?: string;
  };
}

type NixFlakeCheckDetails = CliToolDetails & NixFlakeCheckExtraDetails;

/** Shape of `nix build --json` output. */
interface NixBuildResult {
  drvPath?: string;
  outputs?: Record<string, string | undefined>;
}

function tailLines(text: string, n: number): string {
  const lines = text.replace(/\s+$/, "").split("\n");
  return lines.slice(-n).join("\n");
}

const flakeCheckParams = Type.Object({
  check: Type.Optional(
    Type.String({
      description: "Name of the check to run; omit to list available checks.",
    }),
  ),
});

function makeFlakeCheckTool(
  system: string,
): StructuredCliToolDef<typeof flakeCheckParams> {
  const renderResult: CliRenderResult<NixFlakeCheckDetails> = (
    result,
    opts,
    theme,
    context,
  ) => {
    const details = result.details as NixFlakeCheckDetails | undefined;
    const fc = details?.flakeCheck;
    if (!fc) {
      return buildDefaultSpec(
        result as unknown as Parameters<typeof buildDefaultSpec>[0],
        opts,
        theme,
        context,
      );
    }

    // Render exactly the lines the agent receives (the postProcess
    // `content`), so the expanded view and the model see the same thing.
    const contentText = (result.content ?? [])
      .filter((p): p is { type: "text"; text: string } => p.type === "text")
      .map((p) => p.text)
      .join("\n")
      .replace(/\s+$/, "");
    const lines = contentText.length > 0 ? contentText.split("\n") : [];
    const isError = result.isError === true;
    const output =
      lines.length > 0
        ? new Text(
            lines
              .map((l) => theme.fg(isError ? "error" : "dim", l))
              .join("\n"),
            0,
            0,
          )
        : undefined;

    let summary: string;
    let status: string | undefined;
    // On success keep the drv/out paths behind expansion: reporting more
    // lines than the inline cap stops renderSpec from inlining them, so a
    // collapsed row shows just "<check> passed". List/failure output still
    // inlines when short.
    let outputLines = lines.length;
    if (fc.mode === "list") {
      const n = fc.checks?.length ?? 0;
      summary = theme.fg("success", `${n} check${n === 1 ? "" : "s"}`);
    } else if (fc.passed) {
      summary = theme.fg("success", `${fc.check} passed`);
      outputLines = COLLAPSED_INLINE_MAX_LINES + 1;
    } else {
      summary = "";
      status = theme.fg("error", `${fc.check} failed`);
    }

    return { summary, status, output, outputLines };
  };

  return {
    name: "nix-flake-check",
    label: "nix flake check",
    command: "nix",
    partialLabel: "Checking…",
    description:
      "List or run the flake's checks. Omit `check` to list check names. On " +
      "failure returns the tail of the build log (with the failing drv path " +
      "for nix-log); on success the drv and out store paths.",
    // Checks may compile/build; allow plenty of time.
    timeoutMs: 600_000,
    parameters: flakeCheckParams,
    buildArgs(p) {
      if (p.check === undefined) {
        return [
          "eval",
          "--json",
          `.#checks.${system}`,
          "--apply",
          "builtins.attrNames",
        ];
      }
      return [
        "build",
        `.#checks.${system}.${p.check}`,
        "--json",
        "--no-link",
        "--print-build-logs",
        "--option",
        "log-lines",
        "0",
      ];
    },
    // Present the user's intent; hide machine-oriented flags (--json,
    // --no-link, --print-build-logs, --option log-lines 0).
    displayArgs(p) {
      if (p.check === undefined) {
        return ["eval", `.#checks.${system}`, "--apply", "builtins.attrNames"];
      }
      return ["build", `.#checks.${system}.${p.check}`];
    },
    postProcess(raw) {
      const p = raw.params as { check?: string };
      const failed =
        raw.timedOut ||
        raw.signal !== null ||
        (raw.exitCode !== null && raw.exitCode !== 0);

      // List mode.
      if (p.check === undefined) {
        if (failed) {
          const stderr = raw.stderr.trim();
          return {
            content:
              stderr.length > 0
                ? stderr
                : `listing checks failed (exit ${raw.exitCode})`,
            details: { flakeCheck: { mode: "list" } },
            isError: true,
          };
        }
        let names: string[] = [];
        try {
          const parsed = JSON.parse(raw.stdout) as unknown;
          if (Array.isArray(parsed)) names = parsed.filter((n): n is string => typeof n === "string");
        } catch {
          // fall through with empty list
        }
        const content =
          names.length === 0
            ? "No checks."
            : names.join("\n");
        return {
          content,
          details: { flakeCheck: { mode: "list", checks: names } },
          isError: false,
        };
      }

      // Run mode.
      if (failed) {
        // Don't parse JSON: on failure nix emits no JSON, and the streamed
        // build-log tail on stderr already carries the failing drvPath for
        // the agent to query via nix-log.
        const tail = tailLines(raw.stderr, FAILURE_TAIL_LINES);
        const header = raw.timedOut
          ? `check ${p.check} timed out`
          : `check ${p.check} failed (exit ${raw.exitCode})`;
        return {
          content: tail.length > 0 ? `${header}\n\n${tail}` : header,
          details: { flakeCheck: { mode: "run", check: p.check, passed: false } },
          isError: true,
        };
      }

      let drvPath: string | undefined;
      let outPath: string | undefined;
      try {
        const parsed = JSON.parse(raw.stdout) as NixBuildResult[];
        const first = parsed[0];
        drvPath = first?.drvPath;
        outPath = first?.outputs?.out;
      } catch {
        // leave paths undefined
      }
      const contentLines = [`check ${p.check} passed`];
      if (drvPath) contentLines.push(`drv: ${drvPath}`);
      if (outPath) contentLines.push(`out: ${outPath}`);
      return {
        content: contentLines.join("\n"),
        details: {
          flakeCheck: { mode: "run", check: p.check, passed: true, drvPath, outPath },
        },
        isError: false,
      };
    },
    renderPartial(details, theme, expanded) {
      // Tail the streamed build log (stderr) while the check runs.
      const TAIL = expanded ? 200 : 6;
      const stderr = (details.stderr ?? "").replace(/\s+$/, "");
      const lines = stderr.length > 0 ? stderr.split("\n") : [];
      const shown = lines.slice(-TAIL);
      const c = new Container();
      if (shown.length === 0) {
        c.addChild(new Text(theme.fg("warning", "⋮ Checking…"), 0, 0));
        return { summary: "", output: c, outputLines: 1 };
      }
      const hidden = lines.length - shown.length;
      if (hidden > 0) {
        c.addChild(
          new Text(theme.fg("muted", `⋮ ${hidden} earlier line(s)`), 0, 0),
        );
      }
      for (const line of shown) c.addChild(new Text(theme.fg("dim", line), 0, 0));
      c.addChild(new Text(theme.fg("warning", "⋮ Checking…"), 0, 0));
      const spec: CliRenderSpec = {
        summary: "",
        output: c,
        outputLines: shown.length + (hidden > 0 ? 2 : 1),
      };
      return spec;
    },
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
    "reported by a failed nix-flake-check.",
  timeoutMs: 60_000,
  parameters: nixLogParams,
  buildArgs(p) {
    return ["log", p.drvPath];
  },
};

/**
 * Return the nix tools whose underlying binary exists. If `nix` is missing
 * (not a Nix environment) we register nothing. The check tool additionally
 * requires resolving the current system; if that probe fails we register the
 * rest and warn once.
 */
export function getNixTools(): CliToolDef[] {
  if (!commandOk("nix", ["--version"])) return [];
  const tools: CliToolDef[] = [nixFlakeInfoTool, nixLogTool];
  const system = commandOutput("nix", [
    "eval",
    "--raw",
    "--impure",
    "--expr",
    "builtins.currentSystem",
  ]);
  if (system) {
    tools.push(makeFlakeCheckTool(system));
  } else {
    console.warn(
      "[cli-tools] nix is available but resolving builtins.currentSystem " +
        "failed; skipping nix-flake-check.",
    );
  }
  return tools;
}
