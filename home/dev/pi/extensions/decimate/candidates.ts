// Heuristic candidate generation over the projected (context-edited) branch.
//
// Pure: takes the session projection, returns scored candidates. v1 only
// targets tool results, always via *replacement* (never omission), so every
// tool call keeps its paired result and providers never see an orphan.

import type { ProjectedSessionEntry } from "@earendil-works/pi-coding-agent";
import type { DecimateConfig } from "./config";

export const STUB_PREFIX = "[decimated";
/** Marker `plan.ts` puts between a trim's head and tail. */
export const TRIM_MARKER = /\n\[decimated: \d+ chars/;

/** Already stubbed or trimmed by an earlier decimation. */
export function isDecimated(text: string): boolean {
  return text.startsWith(STUB_PREFIX) || TRIM_MARKER.test(text);
}
export const IMAGE_TOKENS = 1_600;

export type Reason = "superseded-read" | "failed-retry" | "stale-bulky";

export interface LaterEvidence {
  /** Same path re-read after this result, covering at least its line range. */
  rereads: number;
  /** Same path modified after this result. */
  edits: number;
  /** Path (or its basename) mentioned in later assistant text. */
  mentioned: boolean;
}

export interface Candidate {
  entryId: string;
  toolCallId: string;
  toolName: string;
  args: Record<string, unknown>;
  argsSummary: string;
  path?: string;
  isError: boolean;
  text: string;
  chars: number;
  lines: number;
  images: number;
  estTokens: number;
  /** User-message spans between this result and the branch tip. */
  age: number;
  /** Position in the flattened projected message list (break-point math). */
  messageIndex: number;
  reasons: Reason[];
  /** Heuristic redundancy estimate, 0..1 (higher = safer to remove). */
  prior: number;
  later: LaterEvidence;
}

export interface TaskContext {
  recentUserRequests: string[];
  recentlyModifiedFiles: string[];
}

export interface CandidateScan {
  candidates: Candidate[];
  task: TaskContext;
  /** Estimated tokens per flattened message (same indexing as messageIndex). */
  messageTokens: number[];
}

// --- message shapes (structural; AgentMessage is not importable here) -------

interface Block {
  type?: string;
  text?: string;
  id?: string;
  name?: string;
  arguments?: unknown;
}

interface MsgLike {
  role?: string;
  content?: unknown;
  toolCallId?: string;
  toolName?: string;
  isError?: boolean;
}

function blocks(content: unknown): Block[] {
  if (typeof content === "string") return [{ type: "text", text: content }];
  return Array.isArray(content) ? (content as Block[]) : [];
}

export function textOf(content: unknown): string {
  return blocks(content)
    .filter((b) => b.type === "text" && typeof b.text === "string")
    .map((b) => b.text as string)
    .join("\n");
}

function imageCount(content: unknown): number {
  return blocks(content).filter((b) => b.type === "image").length;
}

export function estimateTokens(content: unknown): number {
  return (
    Math.ceil(textOf(content).length / 4) + imageCount(content) * IMAGE_TOKENS
  );
}

// --- tool vocabulary ----------------------------------------------------------

const READ_TOOLS = new Set(["read"]);
const MODIFY_TOOLS = new Set([
  "edit",
  "write",
  "replace-block",
  "regex-replace",
  "cut-lines",
  "paste-lines",
  "mv",
  "rm",
]);

function pathOf(args: Record<string, unknown>): string | undefined {
  const p = args.path ?? args.file_path ?? args.source;
  return typeof p === "string" && p.length > 0
    ? p.replace(/^\.\//, "")
    : undefined;
}

export function summarizeArgs(
  args: Record<string, unknown>,
  max = 120,
): string {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(args)) {
    if (value === undefined || value === null) continue;
    let v =
      typeof value === "string"
        ? JSON.stringify(value)
        : (JSON.stringify(value) ?? "");
    if (v.length > 60) v = `${v.slice(0, 57)}…`;
    parts.push(`${key}=${v}`);
  }
  const s = parts.join(", ");
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}

/** 1-indexed inclusive line range a `read` covers (`offset`/`limit`). */
interface LineRange {
  start: number;
  end: number;
}

function readRange(args: Record<string, unknown>): LineRange {
  const num = (v: unknown): number | undefined =>
    typeof v === "number" && Number.isFinite(v) && v > 0 ? v : undefined;
  const start = num(args.offset) ?? 1;
  const limit = num(args.limit);
  return {
    start,
    end: limit === undefined ? Number.POSITIVE_INFINITY : start + limit - 1,
  };
}

function covers(outer: LineRange, inner: LineRange): boolean {
  return outer.start <= inner.start && outer.end >= inner.end;
}

function basename(p: string): string {
  const i = p.lastIndexOf("/");
  return i >= 0 ? p.slice(i + 1) : p;
}

// --- scan ---------------------------------------------------------------------

interface Flat {
  entryId: string;
  msg: MsgLike;
  span: number;
}

interface CallInfo {
  name: string;
  args: Record<string, unknown>;
}

interface FileOp {
  index: number;
  kind: "read" | "modify";
  path: string;
  /** Lines read (reads only). */
  range?: LineRange;
}

export function scanCandidates(
  projected: readonly ProjectedSessionEntry[],
  cfg: Pick<DecimateConfig, "keepRecentTurns" | "minChars" | "bulkyChars">,
): CandidateScan {
  const flat: Flat[] = [];
  let span = -1;
  for (const entry of projected) {
    for (const message of entry.messages) {
      const msg = message as MsgLike;
      if (msg.role === "user") span++;
      flat.push({
        entryId: entry.sourceEntry.id,
        msg,
        span: Math.max(span, 0),
      });
    }
  }
  const lastSpan = Math.max(span, 0);

  const calls = new Map<string, CallInfo>();
  const fileOps: FileOp[] = [];
  const assistantText: Array<{ index: number; text: string }> = [];
  const userTexts: string[] = [];
  const messageTokens: number[] = [];

  flat.forEach(({ msg }, index) => {
    messageTokens.push(estimateTokens(msg.content));
    if (msg.role === "user") userTexts.push(textOf(msg.content));
    if (msg.role !== "assistant") return;
    const text = textOf(msg.content);
    if (text) assistantText.push({ index, text });
    for (const b of blocks(msg.content)) {
      if (
        b.type !== "toolCall" ||
        typeof b.id !== "string" ||
        typeof b.name !== "string"
      )
        continue;
      const args =
        b.arguments &&
        typeof b.arguments === "object" &&
        !Array.isArray(b.arguments)
          ? (b.arguments as Record<string, unknown>)
          : {};
      calls.set(b.id, { name: b.name, args });
      const path = pathOf(args);
      if (!path) continue;
      if (READ_TOOLS.has(b.name))
        fileOps.push({ index, kind: "read", path, range: readRange(args) });
      else if (MODIFY_TOOLS.has(b.name))
        fileOps.push({ index, kind: "modify", path });
      if (b.name === "mv" && typeof args.dest === "string") {
        fileOps.push({
          index,
          kind: "modify",
          path: args.dest.replace(/^\.\//, ""),
        });
      }
    }
  });

  // Tool results in order, for retry-chain detection.
  const results: Array<{
    index: number;
    name: string;
    path?: string;
    isError: boolean;
  }> = [];
  flat.forEach(({ msg }, index) => {
    if (msg.role === "toolResult" && typeof msg.toolName === "string") {
      const call =
        typeof msg.toolCallId === "string"
          ? calls.get(msg.toolCallId)
          : undefined;
      results.push({
        index,
        name: msg.toolName,
        path: call ? pathOf(call.args) : undefined,
        isError: msg.isError === true,
      });
    }
  });

  const candidates: Candidate[] = [];
  results.forEach((r, ri) => {
    const { entryId, msg, span: s } = flat[r.index];
    const age = lastSpan - s;
    if (age < cfg.keepRecentTurns) return;
    const call =
      typeof msg.toolCallId === "string"
        ? calls.get(msg.toolCallId)
        : undefined;
    if (!call || typeof msg.toolCallId !== "string") return;

    const text = textOf(msg.content);
    if (isDecimated(text)) return;
    const images = imageCount(msg.content);
    const chars = text.length;
    if (chars < cfg.minChars && images === 0) return;

    const path = pathOf(call.args);
    const reasons: Reason[] = [];
    let prior = 0;

    const later: LaterEvidence = { rereads: 0, edits: 0, mentioned: false };
    if (path) {
      // A later read only supersedes this one if it covers the same lines
      // (reading another slice of a file says nothing about this slice).
      const range = readRange(call.args);
      for (const op of fileOps) {
        if (op.index <= r.index || op.path !== path) continue;
        if (op.kind === "modify") later.edits++;
        else if (op.range && covers(op.range, range)) later.rereads++;
      }
      const base = basename(path);
      later.mentioned = assistantText.some(
        (a) =>
          a.index > r.index &&
          (a.text.includes(path) || (base.length > 3 && a.text.includes(base))),
      );
    }

    if (
      READ_TOOLS.has(r.name) &&
      path &&
      (later.rereads > 0 || later.edits > 0)
    ) {
      reasons.push("superseded-read");
      // A later full re-read supersedes cleanly; an edit only partially does.
      prior = Math.max(prior, later.rereads > 0 ? 0.95 : 0.85);
    }

    if (r.isError) {
      const next = results.slice(ri + 1, ri + 7);
      // `path` (forced onto most tools by pi-permission-system) must match
      // too, so a failed edit of one file isn't "retried" by another's.
      const retried = next.some(
        (n) => n.name === r.name && n.path === r.path && !n.isError,
      );
      if (retried) {
        reasons.push("failed-retry");
        prior = Math.max(prior, 0.85);
      }
    }

    if (chars >= cfg.bulkyChars || images > 0) {
      reasons.push("stale-bulky");
      prior = Math.max(prior, Math.min(0.8, 0.45 + 0.05 * age));
    }

    if (reasons.length === 0) return;

    candidates.push({
      entryId,
      toolCallId: msg.toolCallId,
      toolName: r.name,
      args: call.args,
      argsSummary: summarizeArgs(call.args),
      path,
      isError: r.isError,
      text,
      chars,
      lines: text.length === 0 ? 0 : text.split("\n").length,
      images,
      estTokens: messageTokens[r.index],
      age,
      messageIndex: r.index,
      reasons,
      prior,
      later,
    });
  });

  // Task context for the classifier: what the agent is working on *now*.
  const recentSpanStart = flat.findIndex((f) => f.span >= lastSpan - 2);
  const recentlyModified = new Set<string>();
  for (const op of fileOps) {
    if (op.kind === "modify" && op.index >= Math.max(recentSpanStart, 0))
      recentlyModified.add(op.path);
  }

  return {
    candidates,
    task: {
      recentUserRequests: userTexts
        .slice(-3)
        .map((t) => (t.length > 1_500 ? `${t.slice(0, 1_500)}…` : t)),
      recentlyModifiedFiles: [...recentlyModified].slice(-20),
    },
    messageTokens,
  };
}
