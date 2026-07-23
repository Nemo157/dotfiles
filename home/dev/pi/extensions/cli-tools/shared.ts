// Shared types and runner for the cli-tools extension.
//
// Each individual tool lives in its own file (jj.ts, git.ts, rg.ts, fd.ts)
// and exports one or more `CliToolDef`s. `index.ts` collects them and calls
// `registerCliTool` for each.

import type {
  AgentToolResult,
  ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { type Component, Container, Spacer, Text } from "@earendil-works/pi-tui";
import type { Static, TSchema } from "typebox";
import { spawn } from "node:child_process";
import { homedir } from "node:os";

/**
 * Expand a leading `~` (`~` or `~/…`) to the user's home directory. We spawn
 * child processes without a shell, so shell tilde expansion doesn't happen
 * for free — pass user-supplied paths through this before appending them to
 * argv. The pi permission system tilde-expands input paths on its side, so
 * expanding here for exec purposes stays consistent with policy matching.
 */
export function expandTilde(p: string): string {
  if (p === "~") return homedir();
  if (p.startsWith("~/")) return `${homedir()}/${p.slice(2)}`;
  return p;
}

// Cap the rendered command line so long argv doesn't blow up the header.
const HEADER_MAX_LEN = 200;
// How many output lines to show when the tool row is expanded.
const EXPANDED_MAX_LINES = 200;
// When collapsed, show the full output inline if it's at most this many lines.
export const COLLAPSED_INLINE_MAX_LINES = 6;

/**
 * Structured details attached to every cli-tool result. Custom `renderResult`
 * hooks can rely on this shape; the default renderer uses it too.
 */
export interface CliToolDetails {
  command: string;
  args: string[];
  stdout: string;
  stderr: string;
  exitCode: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
}

// Extract the exact signature pi uses so extension code stays in sync with
// its private `Theme` / `ToolRenderContext` types without importing them.
type RegisterToolArg = Parameters<ExtensionAPI["registerTool"]>[0];
type PiRenderResultFn = NonNullable<RegisterToolArg["renderResult"]>;

/**
 * A tool's renderer returns one of these instead of building a `Component`
 * itself. `registerCliTool` handles layout: it decides whether to show the
 * one-line summary or expand the output block, adds separators, etc. This
 * keeps the collapse/expand/inline-short-output policy in one place so every
 * cli-tool behaves consistently.
 */
export interface CliRenderSpec {
  /** One-line description shown when the row is collapsed and the output
   *  isn't being inlined. Should already be styled with `theme.fg(...)`. */
  summary: string;
  /** Always-visible prefix (e.g. "exit 1", "timed out", "blocked: …"). Shown
   *  inline with the summary when collapsed, or as its own line above the
   *  output when the row shows the output. */
  status?: string;
  /** Component to render when the row shows output (expanded, or short
   *  enough to inline while collapsed). */
  output?: Component;
  /** Rendered line count of `output`. Only used to decide whether a collapsed
   *  row is short enough to inline the output; if omitted or too large the
   *  collapsed row stays on the summary line. */
  outputLines?: number;
  /** Trailer such as "(truncated)". Rendered inline after the summary when
   *  collapsed, or as its own line below the output when the row shows it. */
  trailer?: string;
}

export type CliRenderResult<TDetails = CliToolDetails> = (
  result: AgentToolResult<TDetails>,
  options: Parameters<PiRenderResultFn>[1],
  theme: Parameters<PiRenderResultFn>[2],
  context: Parameters<PiRenderResultFn>[3],
) => CliRenderSpec;

/**
 * Raw output from the subprocess handed to `postProcess` hooks.
 */
export interface RawCommandResult {
  command: string;
  args: string[];
  stdout: string;
  stderr: string;
  exitCode: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
}

/**
 * Result of a `postProcess` hook: LLM-facing text and any extra structured
 * details to merge into the standard {@link CliToolDetails}.
 */
export interface PostProcessResult<TExtra = Record<string, unknown>> {
  content: string;
  details?: TExtra;
  /** Force error state. If omitted the runner infers it from exit code. */
  isError?: boolean;
}

function shellQuote(arg: string): string {
  if (arg === "") return "''";
  if (/^[A-Za-z0-9_@%+=:,./-]+$/.test(arg)) return arg;
  return `'${arg.replace(/'/g, `'\\''`)}'`;
}

function buildInvocation(command: string, args: string[]): string {
  const parts = [command, ...args.map(shellQuote)].join(" ");
  if (parts.length <= HEADER_MAX_LEN) return parts;
  return parts.slice(0, HEADER_MAX_LEN - 1) + "…";
}

function computeArgs(def: CliToolDef, params: unknown): string[] {
  return def.buildArgs(params as Static<typeof def.parameters>);
}

export interface BaseCliToolFields {
  /** Tool name exposed to the LLM. Kebab-case for multi-word names. */
  name: string;
  /** Short human-facing label shown in the TUI. */
  label: string;
  /** Description shown to the LLM. Should explain when to use it. */
  description: string;
  /** Executable to run. Looked up on PATH. */
  command: string;
  /** One-line snippet used in the Available tools section of the prompt. */
  promptSnippet?: string;
  /** Extra guideline bullets appended to the prompt Guidelines section. */
  promptGuidelines?: string[];
  /** Timeout in ms. Defaults to 30s. */
  timeoutMs?: number;
  /**
   * Optional post-processor. If defined, the returned `content` replaces the
   * default formatted text sent to the LLM, and `details` is merged into
   * {@link CliToolDetails}. Useful for tools that emit structured output
   * (e.g. `--json`) which is easier to re-format for both the LLM and the
   * TUI than raw human-readable text.
   */
  postProcess?: (raw: RawCommandResult) => PostProcessResult;
  /**
   * Optional override for the result row. Returns a {@link CliRenderSpec};
   * `registerCliTool` handles the collapse/expand layout. Falls back to
   * {@link buildDefaultSpec} (stdout/stderr + "N lines of output" summary)
   * when not provided.
   */
  renderResult?: CliRenderResult<any>;
  /** Label shown while the call is streaming. Defaults to "Running…". */
  partialLabel?: string;
}

/**
 * Structured wrapper: explicit `parameters` schema and a `buildArgs` function
 * that maps typed params to argv. `buildArgs` is responsible for placing a
 * `--` separator before any user-supplied paths.
 *
 * NOTE: when a tool accepts a filesystem path from the model, expose it as a
 * single optional field named exactly `path` (string). The pi permission
 * system's built-in access-intent extractor keys on `input.path` and uses it
 * to evaluate the `path` / `external_directory` gates — using a different
 * name (or an array like `paths`) silently bypasses those gates. If a tool
 * genuinely needs multiple paths, register a custom extractor via
 * `getPermissionsService().registerToolAccessExtractor(...)` instead.
 */
export interface StructuredCliToolDef<T extends TSchema = TSchema>
  extends BaseCliToolFields {
  parameters: T;
  buildArgs: (params: Static<T>) => string[];
}

export type CliToolDef = StructuredCliToolDef;

interface RunResult {
  stdout: string;
  stderr: string;
  code: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
}

function runCommand(
  command: string,
  args: string[],
  opts: { cwd: string; signal?: AbortSignal; timeoutMs: number },
): Promise<RunResult> {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: opts.cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, opts.timeoutMs);

    const onAbort = () => {
      child.kill("SIGTERM");
    };
    opts.signal?.addEventListener("abort", onAbort, { once: true });

    child.on("error", (err) => {
      clearTimeout(timer);
      opts.signal?.removeEventListener("abort", onAbort);
      resolve({
        stdout,
        stderr: stderr + `\n[spawn error] ${err.message}`,
        code: null,
        signal: null,
        timedOut,
      });
    });

    child.on("close", (code, signal) => {
      clearTimeout(timer);
      opts.signal?.removeEventListener("abort", onAbort);
      resolve({ stdout, stderr, code, signal, timedOut });
    });
  });
}

function formatResult(
  def: CliToolDef,
  args: string[],
  result: RunResult,
): { text: string; isError: boolean } {
  const invocation = buildInvocation(def.command, args);
  const parts: string[] = [`$ ${invocation}`];
  if (result.stdout.trim().length > 0) parts.push(result.stdout.trimEnd());
  if (result.stderr.trim().length > 0) {
    parts.push(`--- stderr ---\n${result.stderr.trimEnd()}`);
  }

  let isError = false;
  if (result.timedOut) {
    parts.push(`[timed out]`);
    isError = true;
  } else if (result.signal) {
    parts.push(`[killed by signal ${result.signal}]`);
    isError = true;
  } else if (result.code !== 0) {
    parts.push(`[exit ${result.code}]`);
    isError = true;
  }

  return { text: parts.join("\n\n"), isError };
}

function countNonEmptyLines(text: string): number {
  if (text.length === 0) return 0;
  return text.split("\n").filter((l) => l.trim().length > 0).length;
}

/**
 * Turn a {@link CliRenderSpec} into the final `Component`. Applies the shared
 * collapse / expand / inline-short-output policy:
 *
 *   - collapsed + no output (or too many lines): render `status? summary trailer?`
 *     on a single line.
 *   - collapsed + output ≤ {@link COLLAPSED_INLINE_MAX_LINES}: render `status?`,
 *     a blank spacer, `output`, and `trailer?` stacked.
 *   - expanded: same as inline case, but without the size cap.
 */
function renderSpec(
  spec: CliRenderSpec,
  expanded: boolean,
): Component {
  const size = spec.outputLines ?? 0;
  const inline =
    !expanded &&
    spec.output !== undefined &&
    size > 0 &&
    size <= COLLAPSED_INLINE_MAX_LINES;
  const showOutput = (expanded && spec.output !== undefined) || inline;

  if (!showOutput) {
    let head = spec.status ?? "";
    if (spec.summary) {
      if (head) head += " ";
      head += spec.summary;
    }
    if (spec.trailer) {
      if (head) head += " ";
      head += spec.trailer;
    }
    return new Text(head, 0, 0);
  }

  const c = new Container();
  if (spec.status) c.addChild(new Text(spec.status, 0, 0));
  // Blank line between the invocation header (or status) and the output.
  c.addChild(new Spacer(1));
  c.addChild(spec.output!);
  if (spec.trailer) c.addChild(new Text(spec.trailer, 0, 0));
  return c;
}

/**
 * Default spec builder: turns stdout/stderr into a colored `Text` output and
 * derives `status` / `summary` from exit code, timeout, and blocked state.
 */
export const buildDefaultSpec: CliRenderResult = (
  result,
  _opts,
  theme,
  _context,
) => {
  const details = result.details as CliToolDetails | undefined;
  const stdout = details?.stdout ?? "";
  const stderr = details?.stderr ?? "";
  const exitCode = details?.exitCode ?? null;
  const timedOut = details?.timedOut ?? false;
  // The command never actually ran: the tool call was blocked upstream
  // (e.g. denied by the permission system) so our execute() didn't produce
  // any details. Pi may pass either an absent or empty details object in
  // that case, so detect it by the absence of the fields we always set.
  const notRun = !details || details.command === undefined;

  // Text content attached to the result (used for the blocker message).
  const contentText = (result.content ?? [])
    .filter((p): p is { type: "text"; text: string } => p.type === "text")
    .map((p) => p.text)
    .join("\n")
    .trim();

  if (timedOut) {
    return { summary: "", status: theme.fg("error", "timed out") };
  }

  if (notRun) {
    const lines = contentText.length > 0 ? contentText.split("\n") : [];
    const firstLine = lines[0] ?? "";
    const HEADLINE_MAX = 120;
    const headline =
      firstLine.length > HEADLINE_MAX
        ? firstLine.slice(0, HEADLINE_MAX - 1) + "…"
        : firstLine;
    let status = theme.fg("error", "blocked");
    if (headline.length > 0) status += theme.fg("dim", `: ${headline}`);
    const output =
      lines.length > 0
        ? new Text(lines.map((l) => theme.fg("error", l)).join("\n"), 0, 0)
        : undefined;
    return {
      summary: "",
      status,
      output,
      outputLines: lines.length,
    };
  }

  const stdoutTrimmed = stdout.replace(/\s+$/, "");
  const stderrTrimmed = stderr.replace(/\s+$/, "");
  const stdoutRawLines = stdoutTrimmed.length > 0 ? stdoutTrimmed.split("\n") : [];
  const stderrRawLines = stderrTrimmed.length > 0 ? stderrTrimmed.split("\n") : [];
  const totalRawLines = stdoutRawLines.length + stderrRawLines.length;
  const totalNonEmpty =
    countNonEmptyLines(stdout) + countNonEmptyLines(stderr);

  // Build the output component: stdout in dim, then "--- stderr ---" divider
  // and stderr in error, each capped at EXPANDED_MAX_LINES with a "… N more"
  // tail.
  const chunks: string[] = [];
  let extraTailLines = 0;
  if (stdoutRawLines.length > 0) {
    const shown = stdoutRawLines.slice(0, EXPANDED_MAX_LINES);
    for (const line of shown) chunks.push(theme.fg("dim", line));
    if (stdoutRawLines.length > EXPANDED_MAX_LINES) {
      chunks.push(
        theme.fg(
          "muted",
          `… ${stdoutRawLines.length - EXPANDED_MAX_LINES} more line(s)`,
        ),
      );
      extraTailLines++;
    }
  }
  if (stderrRawLines.length > 0) {
    chunks.push(theme.fg("muted", "--- stderr ---"));
    extraTailLines++;
    const shown = stderrRawLines.slice(0, EXPANDED_MAX_LINES);
    for (const line of shown) chunks.push(theme.fg("error", line));
    if (stderrRawLines.length > EXPANDED_MAX_LINES) {
      chunks.push(
        theme.fg(
          "muted",
          `… ${stderrRawLines.length - EXPANDED_MAX_LINES} more line(s)`,
        ),
      );
      extraTailLines++;
    }
  }
  const output =
    chunks.length > 0 ? new Text(chunks.join("\n"), 0, 0) : undefined;
  // outputLines is used only to decide inline vs. summary while collapsed.
  // Count the raw output lines plus any dividers/tails we injected.
  const outputLines = totalRawLines + extraTailLines;

  const status =
    exitCode === 0 || exitCode === null
      ? undefined
      : theme.fg("error", `exit ${exitCode}`);
  const summaryBase =
    exitCode === 0 || exitCode === null
      ? theme.fg("success", "done")
      : "";
  const summary =
    totalNonEmpty > 0
      ? (summaryBase
          ? summaryBase +
            theme.fg(
              "dim",
              ` (${totalNonEmpty} line${totalNonEmpty === 1 ? "" : "s"} of output)`,
            )
          : theme.fg(
              "dim",
              `(${totalNonEmpty} line${totalNonEmpty === 1 ? "" : "s"} of output)`,
            ))
      : summaryBase;

  return { summary, status, output, outputLines };
};

export function registerCliTool(pi: ExtensionAPI, def: CliToolDef) {
  pi.registerTool({
    name: def.name,
    label: def.label,
    description: def.description,
    promptSnippet: def.promptSnippet,
    promptGuidelines: def.promptGuidelines,
    parameters: def.parameters,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const args = computeArgs(def, params);
      const result = await runCommand(def.command, args, {
        cwd: ctx.cwd,
        signal,
        timeoutMs: def.timeoutMs ?? 30_000,
      });
      const baseDetails: CliToolDetails = {
        command: def.command,
        args,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.code,
        signal: result.signal,
        timedOut: result.timedOut,
      };

      if (def.postProcess) {
        const pp = def.postProcess({ ...baseDetails });
        const details = { ...baseDetails, ...(pp.details ?? {}) };
        const inferredError =
          result.timedOut ||
          result.signal !== null ||
          (result.code !== null && result.code !== 0);
        return {
          content: [{ type: "text", text: pp.content }],
          details,
          isError: pp.isError ?? inferredError,
        };
      }

      const { text, isError } = formatResult(def, args, result);
      return {
        content: [{ type: "text", text }],
        details: baseDetails,
        isError,
      };
    },

    // Header line: `$ <command> <args>`. Matches the built-in bash renderer
    // and lets the user see exactly what will run before/after execution.
    // Wrapped in try/catch because args may be partial while streaming, in
    // which case buildArgs (structured tools) can throw on missing fields.
    renderCall(args, theme, _context) {
      let invocation: string;
      try {
        const argv = computeArgs(def, args);
        invocation = buildInvocation(def.command, argv);
      } catch {
        invocation = def.command;
      }
      const text =
        theme.fg("toolTitle", theme.bold("$ ")) +
        theme.fg("accent", invocation);
      return new Text(text, 0, 0);
    },

    renderResult(result, opts, theme, ctx) {
      if (opts.isPartial) {
        return new Text(
          theme.fg("warning", def.partialLabel ?? "Running…"),
          0,
          0,
        );
      }
      const spec = (def.renderResult ?? buildDefaultSpec)(
        result,
        opts,
        theme,
        ctx,
      );
      return renderSpec(spec, opts.expanded);
    },
  });
}
