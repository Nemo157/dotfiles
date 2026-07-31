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
import { spawn, spawnSync } from "node:child_process";
import { homedir } from "node:os";

/**
 * Check whether a subprocess invocation succeeds (exit 0). Used at
 * registration time to gate tool availability on the underlying binary.
 * `stdio: "ignore"` keeps the check silent even if the command prints to
 * stdout/stderr.
 */
export function commandOk(command: string, args: string[]): boolean {
  try {
    const r = spawnSync(command, args, { stdio: "ignore" });
    return r.status === 0;
  } catch {
    return false;
  }
}

/**
 * Run a command and capture its trimmed stdout, or `null` if it fails to
 * spawn or exits nonzero. Used at registration time to probe environment
 * facts (e.g. the current Nix system) that a tool's `buildArgs` needs to
 * close over. `stderr` is ignored.
 */
export function commandOutput(command: string, args: string[]): string | null {
  try {
    const r = spawnSync(command, args, {
      stdio: ["ignore", "pipe", "ignore"],
      encoding: "utf8",
    });
    if (r.status !== 0 || typeof r.stdout !== "string") return null;
    return r.stdout.trim();
  } catch {
    return null;
  }
}

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
  /**
   * Wall-clock time (ms since epoch) when the subprocess was spawned.
   * Populated during streaming so `renderPartial` can show elapsed time,
   * and preserved in the final details for consistency.
   */
  startedAt?: number;
  /**
   * Wall-clock time (ms since epoch) of the last streaming update. Bumped
   * on every chunk flush and on every heartbeat tick, so pi treats each
   * heartbeat as a fresh update (otherwise the payload would be byte-
   * identical and re-renders would be deduped).
   */
  updatedAt?: number;
  /**
   * The original, validated params object the tool was invoked with.
   * Threaded through so `renderPartial` (which only sees details at render
   * time) can consult the model's typed intent instead of reverse-
   * engineering it from argv. Tool code should cast this to its own
   * `Static<typeof params>` type.
   */
  params?: unknown;
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
  /**
   * The original, validated params object. See
   * {@link CliToolDetails.params}; tools should cast to their
   * `Static<typeof params>` type.
   */
  params: unknown;
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
  return [command, ...args.map(shellQuote)].join(" ");
}

function computeArgs(def: StructuredCliToolDef, params: unknown): string[] {
  return def.buildArgs(params as Static<typeof def.parameters>);
}

function computeDisplayArgs(def: CliToolDef, params: unknown): string[] {
  const typed = params as Static<typeof def.parameters>;
  if (def.displayArgs) return def.displayArgs(typed);
  if ("buildArgs" in def) return def.buildArgs(typed);
  return [];
}

/** Discriminate the two tool variants: structured (single command) vs. custom
 *  (arbitrary async implementation). */
function isCustom(def: CliToolDef): def is CustomCliToolDef {
  return "run" in def;
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
  /**
   * Optional override for the streaming (partial) row. Called with the
   * accumulated stdout/stderr so far and should return a
   * {@link CliRenderSpec}; `registerCliTool` handles layout the same way it
   * does for the final result. Providing this hook enables streaming even
   * for tools with a `postProcess` hook — useful for tools whose raw output
   * is structured (e.g. `--json`) and needs incremental parsing to be
   * legible mid-run. Falls back to a simple tail-of-stdout renderer when
   * not provided.
   */
  renderPartial?: (
    details: CliToolDetails,
    theme: Parameters<PiRenderResultFn>[2],
    expanded: boolean,
  ) => CliRenderSpec;
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
  /**
   * Optional argv used purely for the header line rendered in the TUI. Lets
   * a tool present the user's *intent* (e.g. `rg -l pattern`) instead of
   * the actual argv used to spawn the subprocess (which may include
   * machine-oriented flags like `--json` or workarounds like
   * `--max-count=1` that stand in for a mode flag). Falls back to
   * `buildArgs` when omitted.
   */
  displayArgs?: (params: Static<T>) => string[];
}

/**
 * Context handed to a {@link CustomCliToolDef.run} implementation.
 */
export interface CustomRunContext {
  cwd: string;
  signal?: AbortSignal;
}

/**
 * Result of a custom tool's `run`. `content` is the LLM-facing text; `stdout`
 * (defaulting to `content`) is what the TUI shows in its output block.
 */
export interface CustomRunResult {
  content: string;
  stdout?: string;
  isError?: boolean;
  /** Extra structured fields merged into {@link CliToolDetails}, so a
   *  `renderResult` hook can drive the collapsed summary from them. */
  details?: Record<string, unknown>;
}

/**
 * Custom wrapper: instead of mapping params to a single argv, the tool
 * provides an async `run` that may spawn several helper subprocesses and
 * assemble its own output (e.g. multiple `gh api` calls + formatting). It
 * still renders through the shared spec builders; `displayArgs` supplies the
 * `$ <command> <args>` header line shown in the TUI.
 */
export interface CustomCliToolDef<T extends TSchema = TSchema>
  extends BaseCliToolFields {
  parameters: T;
  displayArgs?: (params: Static<T>) => string[];
  run: (params: Static<T>, ctx: CustomRunContext) => Promise<CustomRunResult>;
}

export type CliToolDef = StructuredCliToolDef | CustomCliToolDef;

export interface RunResult {
  stdout: string;
  stderr: string;
  code: number | null;
  signal: NodeJS.Signals | null;
  timedOut: boolean;
}

export function runCommand(
  command: string,
  args: string[],
  opts: {
    cwd: string;
    signal?: AbortSignal;
    timeoutMs: number;
    /** Called after each stdout chunk with the full accumulated buffer. */
    onStdout?: (buf: string) => void;
    /** Called after each stderr chunk with the full accumulated buffer. */
    onStderr?: (buf: string) => void;
  },
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
      opts.onStdout?.(stdout);
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
      opts.onStderr?.(stderr);
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

// Tail size shown while streaming a partial result when the row is
// collapsed. Matches COLLAPSED_INLINE_MAX_LINES so a short-output tool
// transitions smoothly from streaming into its final inline render.
const STREAMING_TAIL_LINES = COLLAPSED_INLINE_MAX_LINES;

/**
 * Render a live tail of stdout/stderr while the subprocess is still running.
 * Layout (collapsed):
 *   ⋮ N earlier line(s)      (only if > STREAMING_TAIL_LINES lines so far)
 *   … last STREAMING_TAIL_LINES lines…
 *   ⋮ <partialLabel>          ("Linting…", "Testing…", etc.)
 *
 * When expanded we show the same layout but cap the tail at
 * EXPANDED_MAX_LINES instead. If nothing has streamed yet, fall back to a
 * plain one-line label.
 */
/**
 * Format a millisecond duration as `Ns` / `Nm Ss` for compact elapsed-time
 * badges in streaming UIs.
 */
export function formatElapsed(ms: number): string {
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  const rem = s % 60;
  return `${m}m ${rem}s`;
}

function renderStreamingTail(
  details: CliToolDetails | undefined,
  partialLabel: string,
  theme: Parameters<PiRenderResultFn>[2],
  expanded: boolean,
): Component {
  const stdout = details?.stdout ?? "";
  const stderr = details?.stderr ?? "";
  const elapsedSuffix =
    details?.startedAt !== undefined
      ? ` (${formatElapsed((details.updatedAt ?? Date.now()) - details.startedAt)})`
      : "";
  // stdout / stderr arrive on separate Node streams so we don't have true
  // interleaving. For a streaming tail this is fine — users just want to
  // see "what's happening". Concatenate with stderr after stdout.
  const joined =
    stdout.length > 0 && stderr.length > 0
      ? stdout + (stdout.endsWith("\n") ? "" : "\n") + stderr
      : stdout + stderr;
  const trimmed = joined.replace(/\r?\n$/, "");

  if (trimmed.length === 0) {
    return new Text(
      theme.fg("warning", `⋮ ${partialLabel}${elapsedSuffix}`),
      0,
      0,
    );
  }

  const lines = trimmed.split("\n");
  const tailN = expanded ? EXPANDED_MAX_LINES : STREAMING_TAIL_LINES;
  const hidden = Math.max(0, lines.length - tailN);
  const tail = lines.slice(-tailN);

  const c = new Container();
  if (hidden > 0) {
    c.addChild(
      new Text(
        theme.fg("muted", `⋮ ${hidden} earlier line${hidden === 1 ? "" : "s"}`),
        0,
        0,
      ),
    );
  }
  for (const line of tail) {
    c.addChild(new Text(theme.fg("dim", line), 0, 0));
  }
  c.addChild(
    new Text(theme.fg("warning", `⋮ ${partialLabel}${elapsedSuffix}`), 0, 0),
  );
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
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      // Custom tools run their own async implementation and reuse the shared
      // rendering by populating a CliToolDetails from the returned text.
      if (isCustom(def)) {
        const startedAt = Date.now();
        const displayArgs = computeDisplayArgs(def, params);
        try {
          const res = await def.run(params as Static<typeof def.parameters>, {
            cwd: ctx.cwd,
            signal,
          });
          const details: CliToolDetails = {
            command: def.command,
            args: displayArgs,
            stdout: res.stdout ?? res.content,
            stderr: "",
            exitCode: res.isError ? 1 : 0,
            signal: null,
            timedOut: false,
            startedAt,
            updatedAt: Date.now(),
            params,
            ...(res.details ?? {}),
          };
          return {
            content: [{ type: "text", text: res.content }],
            details,
            isError: res.isError ?? false,
          };
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          const details: CliToolDetails = {
            command: def.command,
            args: displayArgs,
            stdout: "",
            stderr: msg,
            exitCode: 1,
            signal: null,
            timedOut: false,
            startedAt,
            updatedAt: Date.now(),
            params,
          };
          return {
            content: [{ type: "text", text: msg }],
            details,
            isError: true,
          };
        }
      }

      const args = computeArgs(def, params);

      // Streaming: for tools without a postProcess hook, forward partial
      // stdout/stderr to pi as the subprocess runs so the TUI can show a
      // live tail. postProcess tools (e.g. rg --json) buffer structured
      // output that only makes sense after the fact, so we skip streaming
      // for them. Partial updates carry empty text content — the LLM only
      // ever sees the final result.
      // Stream partial output when pi is listening. For tools with a
      // postProcess hook the raw stdout is typically structured (e.g.
      // JSONL) and unhelpful as a tail, so we only stream in that case if
      // the tool also provided a renderPartial hook that knows how to
      // present it.
      const shouldStream =
        onUpdate !== undefined &&
        (def.postProcess === undefined || def.renderPartial !== undefined);
      const startedAt = Date.now();
      let pending: NodeJS.Timeout | null = null;
      let latestStdout = "";
      let latestStderr = "";
      const flush = () => {
        pending = null;
        if (!onUpdate) return;
        onUpdate({
          content: [{ type: "text", text: "" }],
          details: {
            command: def.command,
            args,
            stdout: latestStdout,
            stderr: latestStderr,
            exitCode: null,
            signal: null,
            timedOut: false,
            startedAt,
            updatedAt: Date.now(),
            params,
          },
          isError: false,
        });
      };
      const scheduleFlush = () => {
        if (!shouldStream || pending) return;
        // ~60ms coalescing window: fast enough to feel live, slow enough
        // that a chatty subprocess doesn't flood pi with re-renders.
        pending = setTimeout(flush, 60);
      };
      // Heartbeat: even when the subprocess is quiet (e.g. rg walking a
      // huge tree before hitting any match), refire onUpdate every 500ms
      // so `renderPartial` can update an elapsed-time counter and the row
      // doesn't feel frozen.
      const heartbeat: NodeJS.Timeout | null = shouldStream
        ? setInterval(() => {
            if (pending) return; // coalesce with a pending chunk flush
            flush();
          }, 500)
        : null;

      const result = await runCommand(def.command, args, {
        cwd: ctx.cwd,
        signal,
        timeoutMs: def.timeoutMs ?? 30_000,
        onStdout: shouldStream
          ? (buf) => {
              latestStdout = buf;
              scheduleFlush();
            }
          : undefined,
        onStderr: shouldStream
          ? (buf) => {
              latestStderr = buf;
              scheduleFlush();
            }
          : undefined,
      });
      if (pending) {
        clearTimeout(pending);
        pending = null;
      }
      if (heartbeat) clearInterval(heartbeat);
      const baseDetails: CliToolDetails = {
        command: def.command,
        args,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.code,
        signal: result.signal,
        timedOut: result.timedOut,
        startedAt,
        updatedAt: Date.now(),
        params,
      };

      if (def.postProcess) {
        const pp = def.postProcess({ ...baseDetails, params });
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
        const argv = computeDisplayArgs(def, args);
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
        const details = result.details as CliToolDetails | undefined;
        if (def.renderPartial && details) {
          return renderSpec(
            def.renderPartial(details, theme, opts.expanded),
            opts.expanded,
          );
        }
        return renderStreamingTail(
          details,
          def.partialLabel ?? "Running…",
          theme,
          opts.expanded,
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
