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
/** Fallback chars/token when no billed usage is available to calibrate. */
export const DEFAULT_CHARS_PER_TOKEN = 4;
/** Calibrated ratios outside this range are clamped (bad usage data). */
const MIN_CHARS_PER_TOKEN = 1.5;
const MAX_CHARS_PER_TOKEN = 6;
/** Prompts smaller than this are too dominated by fixed overhead. */
const MIN_CALIBRATION_TOKENS = 2_000;
/**
 * How far a reused prompt's cache read may fall short of the earlier prompt
 * (Codex caches in blocks); same slack as pi-contextimate.
 */
const CACHE_PREFIX_SLACK_TOKENS = 2_048;

export type Reason =
  | "superseded-read"
  | "failed-retry"
  | "stale-bulky"
  | "stale";

/**
 * Prior of an old result no heuristic flags: below any sane
 * `heuristicThreshold`, so only the classifier can remove it.
 */
const STALE_PRIOR = 0.3;

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
  /** `estTokens` is measured from billed usage, not estimated. */
  measured: boolean;
  /** User-message spans between this result and the branch tip. */
  age: number;
  /** User turn that produced this result (`TurnSummary.turn`). */
  turn: number;
  /** Position in the flattened projected message list (break-point math). */
  messageIndex: number;
  reasons: Reason[];
  /** Heuristic redundancy estimate, 0..1 (higher = safer to remove). */
  prior: number;
  later: LaterEvidence;
}

export interface TurnSummary {
  /** 0-based user turn index; matches `Candidate.turn`. */
  turn: number;
  user: string;
  /** The agent's last text in that turn, usually its answer or summary. */
  outcome?: string;
}

export interface TaskContext {
  /**
   * User requests with the agent's closing text, oldest first. Over budget,
   * turns after the first are dropped oldest first (`turn` shows the gap).
   */
  conversation: TurnSummary[];
  recentlyModifiedFiles: string[];
}

/** Character budget for `TaskContext.conversation`. */
const CONVERSATION_BUDGET = 6_000;
/** Turns at the tip that get the longer clip limits. */
const RECENT_TURNS = 2;

function clip(text: string, max: number): string {
  const t = text.trim();
  return t.length > max ? `${t.slice(0, max)}…` : t;
}

function turnChars(t: TurnSummary): number {
  return t.user.length + (t.outcome?.length ?? 0);
}

function outline(
  users: Map<number, string>,
  replies: Map<number, string>,
  lastSpan: number,
): TurnSummary[] {
  const turns: TurnSummary[] = [];
  for (const [turn, user] of users) {
    const recent = lastSpan - turn < RECENT_TURNS;
    const reply = replies.get(turn);
    turns.push({
      turn,
      user: clip(user, recent ? 1_500 : 500),
      ...(reply ? { outcome: clip(reply, recent ? 800 : 300) } : {}),
    });
  }
  // The first request usually states the overall task; keep it and the tip.
  let total = turns.reduce((n, t) => n + turnChars(t), 0);
  while (total > CONVERSATION_BUDGET && turns.length > 1 + RECENT_TURNS) {
    const [dropped] = turns.splice(1, 1);
    total -= turnChars(dropped);
  }
  return turns;
}

export interface CandidateScan {
  candidates: Candidate[];
  task: TaskContext;
  /**
   * Tokens per flattened message (same indexing as messageIndex): measured
   * from billed prompt growth where possible (see `measureToolResults`),
   * otherwise estimated.
   */
  messageTokens: number[];
  /** Flattened indices whose `messageTokens` entry is measured. */
  measured: Set<number>;
  /** Chars per token used for all estimates (see `calibrate`). */
  charsPerToken: number;
  /** Where `charsPerToken` came from; absent when it is the default. */
  calibration?: Calibration;
}

export interface Calibration {
  /** Flattened index of the assistant message whose usage was used. */
  index: number;
  /** Estimated chars of its prompt (head + preceding messages). */
  chars: number;
  /** Billed prompt tokens (input + cacheRead + cacheWrite), minus images. */
  tokens: number;
  provider?: string;
  model?: string;
}

// --- message shapes (structural; AgentMessage is not importable here) -------

interface Block {
  type?: string;
  text?: string;
  thinking?: string;
  thinkingSignature?: string;
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
  api?: string;
  provider?: string;
  model?: string;
  stopReason?: string;
  usage?: {
    input?: number;
    output?: number;
    cacheRead?: number;
    cacheWrite?: number;
    reasoning?: number;
  };
}

/** Billed prompt size of an assistant reply, if trustworthy. */
function promptTokens(m: MsgLike): number | undefined {
  if (m.role !== "assistant" || !m.usage) return undefined;
  if (m.stopReason === "error" || m.stopReason === "aborted") return undefined;
  const u = m.usage;
  const total = (u.input ?? 0) + (u.cacheRead ?? 0) + (u.cacheWrite ?? 0);
  return total > 0 ? total : undefined;
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

/**
 * Chars of everything in a message that reaches the provider as text:
 * text, thinking and tool calls (name + JSON arguments).
 */
function charsOf(content: unknown): number {
  let n = 0;
  for (const b of blocks(content)) {
    if (b.type === "text" && typeof b.text === "string") n += b.text.length;
    else if (b.type === "thinking" && typeof b.thinking === "string")
      n += b.thinking.length;
    else if (b.type === "toolCall")
      n += (b.name?.length ?? 0) + (JSON.stringify(b.arguments) ?? "").length;
  }
  return n;
}

export function estimateTokens(
  content: unknown,
  charsPerToken = DEFAULT_CHARS_PER_TOKEN,
): number {
  return (
    Math.ceil(charsOf(content) / charsPerToken) +
    imageCount(content) * IMAGE_TOKENS
  );
}

/**
 * Derive chars/token from the latest billed prompt on the branch: its
 * usage (input + cache read + cache write) against the estimated chars of
 * the head (system prompt + tools) and every message before it. Code and
 * diffs tokenize far denser than the 4 chars/token rule of thumb, so a
 * fixed ratio badly underestimates what stubbing them saves. Prefers a
 * reply from `model` (tokenizers differ), else any model.
 */
function calibrate(
  flat: readonly Flat[],
  headChars: number,
  model?: { provider: string; id: string },
): Calibration | undefined {
  let fallback: number | undefined;
  let index: number | undefined;
  for (let i = flat.length - 1; i >= 0; i--) {
    const m = flat[i].msg;
    const total = promptTokens(m);
    if (total === undefined || total < MIN_CALIBRATION_TOKENS) continue;
    if (!model || (m.provider === model.provider && m.model === model.id)) {
      index = i;
      break;
    }
    fallback ??= i;
  }
  index ??= fallback;
  if (index === undefined) return undefined;
  const m = flat[index].msg;
  const u = m.usage ?? {};
  let chars = headChars;
  let images = 0;
  for (const { msg } of flat.slice(0, index)) {
    chars += charsOf(msg.content);
    images += imageCount(msg.content);
  }
  const tokens =
    (u.input ?? 0) +
    (u.cacheRead ?? 0) +
    (u.cacheWrite ?? 0) -
    images * IMAGE_TOKENS;
  if (tokens < MIN_CALIBRATION_TOKENS || chars === 0) return undefined;
  return { index, chars, tokens, provider: m.provider, model: m.model };
}

/**
 * Exact token cost of tool results, from billed prompt growth (the method
 * pi-contextimate uses for its "Tool outputs · measured" row). Between two
 * consecutive replies of the same model with only tool results in between,
 * the prompt grows by exactly the earlier reply as replayed plus those
 * results — provided the later request reused the earlier prompt, which its
 * cache read proves. The reply's output is subtracted (minus reasoning that
 * was not replayed: no signed thinking carrier); the rest is the results',
 * split by estimated size when a step has several (parallel calls).
 *
 * Steps holding an already-decimated result are skipped: the measurement is
 * of the original content, not the stub now in its place.
 */
function measureToolResults(
  flat: readonly Flat[],
  charsPerToken: number,
): Map<number, number> {
  const out = new Map<number, number>();
  let prev: number | undefined;
  for (let i = 0; i < flat.length; i++) {
    const next = flat[i].msg;
    const nextPrompt = promptTokens(next);
    if (nextPrompt === undefined) continue;
    const p = prev;
    prev = i;
    if (p === undefined) continue;
    const prevMsg = flat[p].msg;
    const prevPrompt = promptTokens(prevMsg) ?? 0;
    if (
      prevMsg.provider !== next.provider ||
      prevMsg.api !== next.api ||
      prevMsg.model !== next.model
    )
      continue;
    if (prevPrompt - (next.usage?.cacheRead ?? 0) > CACHE_PREFIX_SLACK_TOKENS)
      continue;
    const between = flat.slice(p + 1, i);
    if (
      between.length === 0 ||
      between.some(
        ({ msg }) =>
          msg.role !== "toolResult" || isDecimated(textOf(msg.content)),
      )
    )
      continue;
    const carrier = blocks(prevMsg.content).some(
      (b) => b.type === "thinking" && Boolean(b.thinkingSignature),
    );
    const replayed =
      (prevMsg.usage?.output ?? 0) -
      (carrier ? 0 : (prevMsg.usage?.reasoning ?? 0));
    const measured = nextPrompt - prevPrompt - replayed;
    if (measured <= 0) continue;
    const weights = between.map(
      ({ msg }) => estimateTokens(msg.content, charsPerToken) || 1,
    );
    const total = weights.reduce((a, b) => a + b, 0);
    between.forEach((_, k) => {
      out.set(p + 1 + k, Math.round((measured * weights[k]) / total));
    });
  }
  return out;
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

/**
 * `ahead`: the plan is for a send that adds a user turn not yet on the
 * branch (precompute, resume, manual staging), so ages count it already —
 * the same results are eligible as when planning at send time.
 */
export function scanCandidates(
  projected: readonly ProjectedSessionEntry[],
  cfg: Pick<DecimateConfig, "keepRecentTurns" | "minChars" | "bulkyChars">,
  opts: {
    ahead?: boolean;
    /** Chars of system prompt + active tool definitions. */
    headChars?: number;
    /** Current model, preferred for calibration. */
    model?: { provider: string; id: string };
  } = {},
): CandidateScan {
  const { ahead = false, headChars = 0 } = opts;
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

  const calibration = calibrate(flat, headChars, opts.model);
  const charsPerToken = calibration
    ? Math.min(
        MAX_CHARS_PER_TOKEN,
        Math.max(MIN_CHARS_PER_TOKEN, calibration.chars / calibration.tokens),
      )
    : DEFAULT_CHARS_PER_TOKEN;
  const measuredTokens = measureToolResults(flat, charsPerToken);

  const calls = new Map<string, CallInfo>();
  const fileOps: FileOp[] = [];
  const assistantText: Array<{ index: number; text: string }> = [];
  const userTexts = new Map<number, string>();
  const lastReplies = new Map<number, string>();
  const messageTokens: number[] = [];

  flat.forEach(({ msg, span: s }, index) => {
    messageTokens.push(
      measuredTokens.get(index) ?? estimateTokens(msg.content, charsPerToken),
    );
    if (msg.role === "user") userTexts.set(s, textOf(msg.content));
    if (msg.role !== "assistant") return;
    const text = textOf(msg.content);
    if (text) {
      assistantText.push({ index, text });
      lastReplies.set(s, text);
    }
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
    const age = lastSpan - s + (ahead ? 1 : 0);
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

    // Everything else old enough is still worth asking the classifier about.
    if (reasons.length === 0) {
      reasons.push("stale");
      prior = STALE_PRIOR;
    }

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
      measured: measuredTokens.has(r.index),
      age,
      turn: s,
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
      conversation: outline(userTexts, lastReplies, lastSpan),
      recentlyModifiedFiles: [...recentlyModified].slice(-20),
    },
    messageTokens,
    measured: new Set(measuredTokens.keys()),
    charsPerToken,
    calibration,
  };
}
