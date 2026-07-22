// Shared types and runner for the cli-tools extension.
//
// Each individual tool lives in its own file (jj.ts, git.ts, rg.ts, fd.ts)
// and exports one or more `CliToolDef`s. `index.ts` collects them and calls
// `registerCliTool` for each.

import type {
  AgentToolResult,
  ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { type Component, Text } from "@earendil-works/pi-tui";
import { Type, type Static, type TSchema } from "typebox";
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
type RenderResultFn = NonNullable<RegisterToolArg["renderResult"]>;
export type CliRenderResult<TDetails = CliToolDetails> = (
  result: AgentToolResult<TDetails>,
  options: Parameters<RenderResultFn>[1],
  theme: Parameters<RenderResultFn>[2],
  context: Parameters<RenderResultFn>[3],
) => Component;

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
  if (isStructured(def)) {
    return def.buildArgs(params as Static<typeof def.parameters>);
  }
  const extra = def.acceptArgs
    ? ((params as { args?: string[] } | undefined)?.args ?? [])
    : [];
  return [...(def.baseArgs ?? []), ...extra];
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
   * Optional override for the result row. Falls back to `defaultRenderResult`
   * (compact "N lines of output" summary + expanded output) if not provided.
   */
  renderResult?: CliRenderResult<any>;
}

/**
 * Simple wrapper: fixed `baseArgs`, plus optional freeform `acceptArgs` for
 * cases where a small amount of extra flexibility is safe and needed. Use
 * this for read-only inspection commands.
 */
export interface SimpleCliToolDef extends BaseCliToolFields {
  baseArgs?: string[];
  acceptArgs?: boolean;
  parameters?: undefined;
  buildArgs?: undefined;
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

export type CliToolDef = SimpleCliToolDef | StructuredCliToolDef;

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
 * Default result renderer: one-line status ("done" / "exit N") plus "N lines
 * of output", and when the row is expanded, the actual stdout/stderr. Any
 * tool can override this via `renderResult` on its def.
 */
export const defaultRenderResult: CliRenderResult = (
  result,
  { expanded, isPartial },
  theme,
  _context,
) => {
  if (isPartial) return new Text(theme.fg("warning", "Running…"), 0, 0);

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

  // Collect any text content the caller (or an upstream blocker like the
  // permission system) attached to the result. Used for both the inline
  // "blocked: <reason>" summary and the expanded view when notRun.
  const contentText = (result.content ?? [])
    .filter((p): p is { type: "text"; text: string } => p.type === "text")
    .map((p) => p.text)
    .join("\n")
    .trim();

  let text = "";
  if (timedOut) {
    text += theme.fg("error", "timed out");
  } else if (notRun) {
    text += theme.fg("error", "blocked");
    // Inline the first line of the blocker's message so the collapsed row
    // still conveys *why* the call didn't run.
    const firstLine = contentText.split("\n", 1)[0] ?? "";
    if (firstLine.length > 0) {
      const HEADLINE_MAX = 120;
      const trimmed =
        firstLine.length > HEADLINE_MAX
          ? firstLine.slice(0, HEADLINE_MAX - 1) + "…"
          : firstLine;
      text += theme.fg("dim", `: ${trimmed}`);
    }
  } else if (exitCode === 0 || exitCode === null) {
    text += theme.fg("success", "done");
  } else {
    text += theme.fg("error", `exit ${exitCode}`);
  }

  const stdoutLines = countNonEmptyLines(stdout);
  const stderrLines = countNonEmptyLines(stderr);
  const totalLines = stdoutLines + stderrLines;
  if (!notRun && !timedOut) {
    text += theme.fg(
      "dim",
      ` (${totalLines} line${totalLines === 1 ? "" : "s"} of output)`,
    );
  }

  if (expanded && notRun && contentText.length > 0) {
    for (const line of contentText.split("\n")) {
      text += `\n${theme.fg("error", line)}`;
    }
  }

  if (expanded && !notRun) {
    const stdoutTrimmed = stdout.replace(/\s+$/, "");
    if (stdoutTrimmed.length > 0) {
      const lines = stdoutTrimmed.split("\n");
      const shown = lines.slice(0, EXPANDED_MAX_LINES);
      for (const line of shown) text += `\n${theme.fg("dim", line)}`;
      if (lines.length > EXPANDED_MAX_LINES) {
        text += `\n${theme.fg("muted", `… ${lines.length - EXPANDED_MAX_LINES} more line(s)`)}`;
      }
    }
    const stderrTrimmed = stderr.replace(/\s+$/, "");
    if (stderrTrimmed.length > 0) {
      text += `\n${theme.fg("muted", "--- stderr ---")}`;
      const lines = stderrTrimmed.split("\n");
      const shown = lines.slice(0, EXPANDED_MAX_LINES);
      for (const line of shown) text += `\n${theme.fg("error", line)}`;
      if (lines.length > EXPANDED_MAX_LINES) {
        text += `\n${theme.fg("muted", `… ${lines.length - EXPANDED_MAX_LINES} more line(s)`)}`;
      }
    }
  }

  return new Text(text, 0, 0);
};

function isStructured(def: CliToolDef): def is StructuredCliToolDef {
  return typeof (def as StructuredCliToolDef).buildArgs === "function";
}

export function registerCliTool(pi: ExtensionAPI, def: CliToolDef) {
  const parameters: TSchema = isStructured(def)
    ? def.parameters
    : def.acceptArgs
      ? Type.Object({
          args: Type.Optional(
            Type.Array(Type.String(), {
              description:
                "Additional positional arguments appended to the base command.",
            }),
          ),
        })
      : Type.Object({});

  pi.registerTool({
    name: def.name,
    label: def.label,
    description: def.description,
    promptSnippet: def.promptSnippet,
    promptGuidelines: def.promptGuidelines,
    parameters,
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

    renderResult: def.renderResult ?? defaultRenderResult,
  });
}
