// Diagnostic: log *what* changed in the wire system prompt between requests.
//
// pi-cachemire reports `cause: system prompt changed` when the hash of the
// outgoing payload's system block differs from the previous billed call, but
// it doesn't say which bytes moved. This extension hooks the same event
// (`before_provider_request`, which sees the final provider payload) and
// writes a line-level diff of the system block to a log file, plus a short
// summary into the TUI.
//
// Read-only: the payload is never modified (the handler always returns
// undefined), so enabling this cannot change what is sent.
//
// Log: $XDG_STATE_HOME/pi/prompt-diff/<pid>-<start-time>.log
// (`/prompt-diff` prints the current path and the last diff summary).

import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// --- payload → system text -------------------------------------------------

// Anthropic-style cache markers move between requests by design; cachemire
// strips them before hashing and so do we, otherwise every diff is noise.
function stripCacheMarkers(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stripCacheMarkers);
  if (!value || typeof value !== "object") return value;
  const out: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
    if (key !== "cache_control" && key !== "cachePoint") {
      out[key] = stripCacheMarkers(entry);
    }
  }
  return out;
}

// Flatten whatever shape the provider uses into plain text:
//   anthropic: system: string | [{ type: "text", text }]
//   openai responses: instructions: string
//   others: system / systemInstruction objects — fall back to JSON.
function systemTextOf(payload: unknown): string | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const body = stripCacheMarkers(payload) as Record<string, unknown>;
  const raw = body.system ?? body.instructions ?? body.systemInstruction;
  if (raw === undefined) return undefined;
  if (typeof raw === "string") return raw;
  if (Array.isArray(raw)) {
    return raw
      .map((block) => {
        if (typeof block === "string") return block;
        const text = (block as { text?: unknown })?.text;
        return typeof text === "string" ? text : JSON.stringify(block);
      })
      .join("\n");
  }
  return JSON.stringify(raw, null, 2);
}

// --- diffing ---------------------------------------------------------------

interface DiffResult {
  /** 0-based line index where the two versions first diverge. */
  at: number;
  removed: string[];
  added: string[];
  context: string[];
}

// Prefix/suffix trim rather than a full LCS: for prompt churn the interesting
// answer is "which block moved", and the divergent middle shows that directly.
function diffLines(prev: string[], cur: string[]): DiffResult | undefined {
  let start = 0;
  while (start < prev.length && start < cur.length && prev[start] === cur[start]) start++;
  let end = 0;
  while (
    end < prev.length - start &&
    end < cur.length - start &&
    prev[prev.length - 1 - end] === cur[cur.length - 1 - end]
  ) {
    end++;
  }
  const removed = prev.slice(start, prev.length - end);
  const added = cur.slice(start, cur.length - end);
  if (removed.length === 0 && added.length === 0) return undefined;
  return {
    at: start,
    removed,
    added,
    context: cur.slice(Math.max(0, start - 3), start),
  };
}

function firstNonEmpty(lines: string[]): string | undefined {
  return lines.find((l) => l.trim().length > 0);
}

// --- logging ---------------------------------------------------------------

function stateDir(): string {
  const base = process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state");
  return join(base, "pi", "prompt-diff");
}

const MAX_BLOCK_LINES = 60;

function clamp(lines: string[]): string[] {
  if (lines.length <= MAX_BLOCK_LINES) return lines;
  return [
    ...lines.slice(0, MAX_BLOCK_LINES),
    `… ${lines.length - MAX_BLOCK_LINES} more line(s)`,
  ];
}

export default function promptDiffExtension(pi: ExtensionAPI): void {
  const logPath = join(stateDir(), `${process.pid}-${Date.now()}.log`);
  let previous: string | undefined;
  let requestNo = 0;
  let lastSummary = "no system-prompt change seen yet";

  function write(text: string): void {
    try {
      mkdirSync(stateDir(), { recursive: true });
      appendFileSync(logPath, text, "utf8");
    } catch {
      // Diagnostics must never break a turn.
    }
  }

  pi.on("before_provider_request", async (event, ctx: ExtensionContext) => {
    const current = systemTextOf(event.payload);
    if (current === undefined) return;
    requestNo++;

    if (previous === undefined) {
      previous = current;
      write(
        `=== request #${requestNo} @ ${new Date().toISOString()} — baseline ` +
          `(${current.length} chars, ${current.split("\n").length} lines)\n`,
      );
      return;
    }
    if (current === previous) return;

    const diff = diffLines(previous.split("\n"), current.split("\n"));
    previous = current;
    if (!diff) return;

    const hint =
      firstNonEmpty(diff.added) ?? firstNonEmpty(diff.removed) ?? "(whitespace)";
    lastSummary =
      `line ${diff.at + 1}: -${diff.removed.length}/+${diff.added.length} — ` +
      hint.slice(0, 120);

    write(
      [
        `=== request #${requestNo} @ ${new Date().toISOString()} — system prompt changed`,
        `    at line ${diff.at + 1}: -${diff.removed.length} +${diff.added.length}`,
        ...diff.context.map((l) => `  ${l}`),
        ...clamp(diff.removed).map((l) => `- ${l}`),
        ...clamp(diff.added).map((l) => `+ ${l}`),
        "",
      ].join("\n"),
    );

    ctx.ui.notify(`system prompt changed — ${lastSummary}`, "warning");
  });

  pi.registerCommand("prompt-diff", {
    description: "Show where the system prompt last changed (and the log path)",
    handler: async (_args, ctx) => {
      ctx.ui.notify(`${lastSummary}\nlog: ${logPath}`, "info");
    },
  });
}
