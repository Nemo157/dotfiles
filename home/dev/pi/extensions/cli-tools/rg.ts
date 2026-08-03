import { Text } from "@earendil-works/pi-tui";
import { type Static, Type } from "typebox";
import {
  asStringArray,
  buildDefaultSpec,
  type CliRenderResult,
  type CliRenderSpec,
  type CliToolDetails,
  expandTilde,
  formatElapsed,
  type StructuredCliToolDef,
} from "./shared";

const rgParams = Type.Object({
  pattern: Type.String({
    description:
      "Regex (or literal, with fixedStrings=true) to search for. Required.",
  }),
  path: Type.Optional(
    Type.String({
      description:
        "File or directory to search. Defaults to the current working " +
        "directory. Passed after `--` so it is never parsed as a flag.",
    }),
  ),
  fixedStrings: Type.Optional(
    Type.Boolean({ description: "Treat pattern as a literal string (-F)." }),
  ),
  ignoreCase: Type.Optional(
    Type.Boolean({ description: "Case-insensitive matching (-i)." }),
  ),
  wordRegexp: Type.Optional(
    Type.Boolean({ description: "Match whole words only (-w)." }),
  ),
  multiline: Type.Optional(
    Type.Boolean({
      description: "Enable multiline matching (-U). Implies --multiline-dotall.",
    }),
  ),
  context: Type.Optional(
    Type.Integer({
      minimum: 0,
      maximum: 20,
      description: "Lines of context around each match (-C).",
    }),
  ),
  glob: Type.Optional(
    Type.Array(Type.String(), {
      description:
        "Include/exclude globs (rg -g). Prefix with `!` to exclude, e.g. `!*.lock`.",
    }),
  ),
  type: Type.Optional(
    Type.Array(Type.String(), {
      description: "Restrict to file types (rg -t), e.g. `[\"rust\", \"nix\"]`.",
    }),
  ),
  filesWithMatches: Type.Optional(
    Type.Boolean({
      description: "List only file paths that contain a match (-l).",
    }),
  ),
  hidden: Type.Optional(
    Type.Boolean({ description: "Search hidden files/dirs (--hidden)." }),
  ),
  noIgnore: Type.Optional(
    Type.Boolean({
      description: "Do not respect .gitignore/.ignore (--no-ignore).",
    }),
  ),
  maxCount: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: 10_000,
      description: "Max matches per file (-m). Default 200.",
    }),
  ),
});

// --- rg --json parsing ---------------------------------------------------

interface RgMatch {
  lineNumber: number;
  /** Line contents with trailing newline stripped. May be truncated. */
  text: string;
}

interface RgFile {
  path: string;
  matches: RgMatch[];
}

/**
 * Extra details attached under `details.rg` for the renderResult hook.
 */
export interface RgExtraDetails {
  rg: {
    matchCount: number;
    fileCount: number;
    /** True if `-l` was requested (no per-line match data expected). */
    filesWithMatchesOnly: boolean;
    files: RgFile[];
    /** True if we hit the display truncation limit while parsing. */
    truncated: boolean;
  };
}

type RgDetails = CliToolDetails & RgExtraDetails;

// Cap how much we retain in memory / show to the LLM. rg itself is bounded
// by --max-count per file but a wide search can still hit thousands of files.
const MAX_FILES = 500;
const MAX_MATCHES_PER_FILE = 200;
// Trim absurdly long match lines (minified files, generated code).
const MAX_LINE_LEN = 400;

function truncateLine(text: string): string {
  const trimmed = text.replace(/\r?\n$/, "");
  if (trimmed.length <= MAX_LINE_LEN) return trimmed;
  return trimmed.slice(0, MAX_LINE_LEN - 1) + "…";
}

function extractPath(node: unknown): string | undefined {
  if (typeof node !== "object" || node === null) return undefined;
  const path = (node as { path?: { text?: unknown } }).path;
  if (path && typeof path === "object" && typeof path.text === "string") {
    return path.text;
  }
  return undefined;
}

// --- rg --json parser ---------------------------------------------------

interface ParsedRg {
  files: RgFile[];
  matchCount: number;
  truncated: boolean;
}

/**
 * Parse rg's JSONL stream. Safe to call on a partial buffer: a trailing
 * incomplete line is skipped rather than logged as a parse error.
 */
function parseRgJsonl(stdout: string): ParsedRg {
  const filesByPath = new Map<string, RgFile>();
  let truncated = false;
  // Only the segments before the final `\n` are guaranteed complete.
  const lastNl = stdout.lastIndexOf("\n");
  const complete = lastNl === -1 ? "" : stdout.slice(0, lastNl);

  for (const line of complete.split("\n")) {
    if (line.length === 0) continue;
    let evt: unknown;
    try {
      evt = JSON.parse(line);
    } catch {
      continue;
    }
    if (typeof evt !== "object" || evt === null) continue;
    const type = (evt as { type?: unknown }).type;
    const data = (evt as { data?: unknown }).data;

    if (type === "begin") {
      const path = extractPath(data);
      if (typeof path === "string" && !filesByPath.has(path)) {
        if (filesByPath.size >= MAX_FILES) {
          truncated = true;
          continue;
        }
        filesByPath.set(path, { path, matches: [] });
      }
    } else if (type === "match") {
      const path = extractPath(data);
      if (typeof path !== "string") continue;
      let file = filesByPath.get(path);
      if (!file) {
        if (filesByPath.size >= MAX_FILES) {
          truncated = true;
          continue;
        }
        file = { path, matches: [] };
        filesByPath.set(path, file);
      }
      if (file.matches.length >= MAX_MATCHES_PER_FILE) {
        truncated = true;
        continue;
      }
      const lineNumber = Number(
        (data as { line_number?: unknown } | undefined)?.line_number ?? 0,
      );
      const lineText = (data as { lines?: { text?: unknown } } | undefined)
        ?.lines?.text;
      file.matches.push({
        lineNumber,
        text: typeof lineText === "string" ? truncateLine(lineText) : "",
      });
    }
    // Ignore `context`, `end`, `summary`. We could surface elapsed time later.
  }

  const files = [...filesByPath.values()];
  const matchCount = files.reduce((n, f) => n + f.matches.length, 0);
  return { files, matchCount, truncated };
}

// --- postProcess: rg --json -> RgDetails + LLM text ---------------------

function formatRgOutput(
  raw: {
    stdout: string;
    stderr: string;
    exitCode: number | null;
    timedOut: boolean;
  },
  filesWithMatchesOnly: boolean,
): { content: string; details: RgExtraDetails; isError: boolean } {
  if (raw.timedOut) {
    return {
      content: "rg timed out",
      details: {
        rg: {
          matchCount: 0,
          fileCount: 0,
          filesWithMatchesOnly,
          files: [],
          truncated: false,
        },
      },
      isError: true,
    };
  }

  // rg exit codes: 0 = matches, 1 = no matches, 2 = error.
  if (raw.exitCode !== 0 && raw.exitCode !== 1) {
    const stderr = raw.stderr.trim();
    return {
      content: stderr.length > 0 ? stderr : `rg failed (exit ${raw.exitCode})`,
      details: {
        rg: {
          matchCount: 0,
          fileCount: 0,
          filesWithMatchesOnly,
          files: [],
          truncated: false,
        },
      },
      isError: true,
    };
  }

  const { files, matchCount, truncated } = parseRgJsonl(raw.stdout);

  let content: string;
  if (files.length === 0) {
    content = "No matches.";
  } else if (filesWithMatchesOnly) {
    content = files.map((f) => f.path).join("\n");
  } else {
    const blocks: string[] = [];
    for (const file of files) {
      const lines: string[] = [`${file.path}:`];
      for (const m of file.matches) {
        lines.push(`  ${m.lineNumber}: ${m.text}`);
      }
      blocks.push(lines.join("\n"));
    }
    content = blocks.join("\n\n");
  }

  if (truncated) {
    content += `\n\n[output truncated: showing at most ${MAX_FILES} files and ${MAX_MATCHES_PER_FILE} matches per file]`;
  }

  return {
    content,
    details: {
      rg: {
        matchCount,
        fileCount: files.length,
        filesWithMatchesOnly,
        files,
        truncated,
      },
    },
    isError: false,
  };
}

// --- renderResult: compact summary + expanded matches -------------------

const EXPAND_LIMIT = 300;

const renderResult: CliRenderResult<RgDetails> = (
  result,
  opts,
  theme,
  context,
) => {
  const details = result.details as RgDetails | undefined;
  const rg = details?.rg;

  // If parsing produced nothing usable (unexpected exit, no rg block), fall
  // back to the shared default spec so we don't silently hide errors.
  if (!rg) {
    return buildDefaultSpec(
      result as unknown as Parameters<typeof buildDefaultSpec>[0],
      opts,
      theme,
      context,
    );
  }

  const summary =
    rg.matchCount === 0 && rg.fileCount === 0
      ? theme.fg("dim", "no matches")
      : rg.filesWithMatchesOnly
        ? theme.fg(
            "success",
            `${rg.fileCount} file${rg.fileCount === 1 ? "" : "s"}`,
          )
        : theme.fg(
            "success",
            `${rg.matchCount} match${rg.matchCount === 1 ? "" : "es"}`,
          ) +
          theme.fg(
            "dim",
            ` across ${rg.fileCount} file${rg.fileCount === 1 ? "" : "s"}`,
          );

  const totalOutputLines = rg.filesWithMatchesOnly
    ? rg.fileCount
    : rg.matchCount + rg.fileCount;

  // Build the listing up to EXPAND_LIMIT; the shared layer decides whether
  // to actually show it based on expanded / outputLines.
  const outLines: string[] = [];
  outer: for (const file of rg.files) {
    if (outLines.length >= EXPAND_LIMIT) break;
    outLines.push(theme.fg("accent", file.path));
    if (rg.filesWithMatchesOnly) continue;
    for (const m of file.matches) {
      if (outLines.length >= EXPAND_LIMIT) break outer;
      const gutter = String(m.lineNumber).padStart(5);
      outLines.push(
        `${theme.fg("muted", gutter)}  ${theme.fg("dim", m.text)}`,
      );
    }
  }
  if (outLines.length < totalOutputLines) {
    outLines.push(
      theme.fg("muted", `… ${totalOutputLines - outLines.length} more line(s)`),
    );
  }

  const output =
    outLines.length > 0 ? new Text(outLines.join("\n"), 0, 0) : undefined;
  const spec: CliRenderSpec = {
    summary,
    output,
    outputLines: outLines.length,
  };
  if (rg.truncated) spec.trailer = theme.fg("warning", "(truncated)");
  return spec;
};

// --- renderPartial: incremental summary from streamed JSONL --------------

// Tail of most-recent matches to show while streaming, keyed off the same
// budget as the collapsed inline view so the transition to the final render
// is smooth.
const PARTIAL_TAIL_MATCHES = 5;

function renderRgPartial(
  details: CliToolDetails,
  theme: Parameters<CliRenderResult>[2],
  _expanded: boolean,
): CliRenderSpec {
  const params = details.params as Static<typeof rgParams> | undefined;
  const filesWithMatchesOnly = params?.filesWithMatches === true;
  const parsed = parseRgJsonl(details.stdout);
  const totalMatches = parsed.matchCount;
  const totalFiles = parsed.files.length;
  const elapsed =
    details.startedAt !== undefined
      ? formatElapsed(
          (details.updatedAt ?? Date.now()) - details.startedAt,
        )
      : undefined;
  const elapsedBadge = elapsed ? theme.fg("muted", ` · ${elapsed}`) : "";

  const summaryBody =
    (totalMatches === 0 && totalFiles === 0
      ? theme.fg("dim", "searching…")
      : filesWithMatchesOnly
        ? theme.fg(
            "success",
            `${totalFiles} file${totalFiles === 1 ? "" : "s"}`,
          ) + theme.fg("dim", " so far…")
        : theme.fg(
            "success",
            `${totalMatches} match${totalMatches === 1 ? "" : "es"}`,
          ) +
          theme.fg(
            "dim",
            ` across ${totalFiles} file${totalFiles === 1 ? "" : "s"} so far…`,
          )) + elapsedBadge;

  // Build a short tail of the most recent matches (or file paths) so the
  // user can see rg making progress, not just a growing counter.
  const tailLines: string[] = [];
  if (filesWithMatchesOnly) {
    const recent = parsed.files.slice(-PARTIAL_TAIL_MATCHES);
    for (const f of recent) tailLines.push(theme.fg("accent", f.path));
  } else {
    // Walk files in reverse to grab the most recent matches without
    // materialising a giant list.
    const recent: { path: string; m: RgMatch }[] = [];
    for (let i = parsed.files.length - 1; i >= 0; i--) {
      const file = parsed.files[i]!;
      for (let j = file.matches.length - 1; j >= 0; j--) {
        recent.push({ path: file.path, m: file.matches[j]! });
        if (recent.length >= PARTIAL_TAIL_MATCHES) break;
      }
      if (recent.length >= PARTIAL_TAIL_MATCHES) break;
    }
    recent.reverse();
    let lastPath: string | undefined;
    for (const { path, m } of recent) {
      if (path !== lastPath) {
        tailLines.push(theme.fg("accent", path));
        lastPath = path;
      }
      const gutter = String(m.lineNumber).padStart(5);
      tailLines.push(
        `${theme.fg("muted", gutter)}  ${theme.fg("dim", m.text)}`,
      );
    }
  }
  tailLines.push(
    theme.fg("warning", `⋮ Searching…${elapsed ? ` (${elapsed})` : ""}`),
  );

  const output = new Text(tailLines.join("\n"), 0, 0);
  return {
    summary: summaryBody,
    output,
    outputLines: tailLines.length,
  };
}

// --- tool definition -----------------------------------------------------

export const rgTool: StructuredCliToolDef<typeof rgParams> = {
  name: "rg",
  label: "rg (ripgrep)",
  command: "rg",
  partialLabel: "Searching…",
  description:
    "Search file contents with ripgrep. Provide a `pattern` plus optional " +
    "typed flags and `path`. Respects .gitignore by default. Read-only.",
  promptSnippet:
    "Use rg to search file contents by regex/literal; prefer it over ad-hoc grep.",
  promptGuidelines: [
    "Use rg to search file contents. Prefer fixedStrings=true for literal text.",
  ],
  parameters: rgParams,
  buildArgs(p) {
    // Always emit --json; we re-format output for the LLM and TUI in
    // postProcess/renderResult. --json makes rg ignore human-oriented output
    // flags, so we skip --line-number / --max-columns here.
    //
    // Note: we don't pass `-l` even when `filesWithMatches` is set. rg's
    // `-l` interacts badly with `--json` (the plain file list is emitted
    // as bare lines, not JSON events), so the postProcessor never sees any
    // matches. Instead we force `--max-count=1` so rg stops reading each
    // file after the first hit, then reduce to a file list in postProcess.
    const maxCount = p.filesWithMatches ? 1 : (p.maxCount ?? 200);
    const args: string[] = ["--json", `--max-count=${maxCount}`];
    if (p.fixedStrings) args.push("-F");
    if (p.ignoreCase) args.push("-i");
    if (p.wordRegexp) args.push("-w");
    if (p.multiline) args.push("-U", "--multiline-dotall");
    if (p.hidden) args.push("--hidden");
    if (p.noIgnore) args.push("--no-ignore");
    if (p.context !== undefined) args.push(`-C${p.context}`);
    for (const g of asStringArray(p.glob)) args.push("-g", g);
    for (const t of asStringArray(p.type)) args.push("-t", t);
    // -e so a pattern starting with `-` is still safe.
    args.push("-e", p.pattern);
    args.push("--");
    if (p.path !== undefined) args.push(expandTilde(p.path));
    return args;
  },
  postProcess(raw) {
    const params = raw.params as Static<typeof rgParams> | undefined;
    return formatRgOutput(raw, params?.filesWithMatches === true);
  },
  displayArgs(p) {
    // Present the user's intent, not the JSON/--max-count=1 mechanics we
    // use under the hood. Mirrors the flag surface exposed via `params`,
    // preferring long forms for readability.
    const args: string[] = [];
    if (p.fixedStrings) args.push("--fixed-strings");
    if (p.ignoreCase) args.push("--ignore-case");
    if (p.wordRegexp) args.push("--word-regexp");
    if (p.multiline) args.push("--multiline");
    if (p.filesWithMatches) args.push("--files-with-matches");
    if (p.hidden) args.push("--hidden");
    if (p.noIgnore) args.push("--no-ignore");
    if (p.context !== undefined) args.push(`--context=${p.context}`);
    if (p.maxCount !== undefined) args.push(`--max-count=${p.maxCount}`);
    for (const g of asStringArray(p.glob)) args.push("--glob", g);
    for (const t of asStringArray(p.type)) args.push("--type", t);
    args.push("--regexp", p.pattern);
    if (p.path !== undefined) args.push("--", expandTilde(p.path));
    return args;
  },
  renderPartial: renderRgPartial,
  renderResult,
};
