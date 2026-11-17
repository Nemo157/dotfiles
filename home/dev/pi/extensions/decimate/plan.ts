// Combine heuristic priors and (optional) classifier verdicts into concrete
// replacement edits.

import type { ContextEditableContent } from "@earendil-works/pi-coding-agent";
import type { Candidate, Reason } from "./candidates";
import type { ClassifierConfig, DecimateConfig } from "./config";
import type { ClassifyUsage, Verdict } from "./classify";

export type Action = "keep" | "trim" | "stub";
export type DecisionSource =
  | "heuristic"
  | "auto-accept"
  | "classifier"
  | "classifier-fallback";

export interface Decision {
  entryId: string;
  toolCallId: string;
  toolName: string;
  argsSummary: string;
  path?: string;
  reasons: Reason[];
  prior: number;
  estTokens: number;
  messageIndex: number;
  heuristicAction: Action;
  action: Action;
  source: DecisionSource;
  verdict?: Verdict;
  savedTokens: number;
}

export interface Edit {
  entryId: string;
  toolCallId: string;
  content: ContextEditableContent;
}

export interface Plan {
  id: string;
  createdAt: number;
  leafId: string | null;
  decisions: Decision[];
  edits: Edit[];
  savedTokens: number;
  /** Flattened message index of the earliest edit. */
  breakIndex: number;
  /** Estimated message tokens before the earliest edit (cold verification). */
  prefixTokens: number;
  shadow: boolean;
  classifier?: ClassifyUsage;
}

// --- rendering ------------------------------------------------------------------

const REASON_TEXT: Record<Reason, string> = {
  "superseded-read": "file was read again or modified later",
  "failed-retry": "failed call that was retried successfully",
  "stale-bulky": "large output from an earlier turn",
};

export function stubText(c: Candidate): string {
  const size = `${c.lines} lines, ${c.chars} chars${c.images ? `, ${c.images} image(s)` : ""}`;
  const why = c.reasons.map((r) => REASON_TEXT[r]).join("; ");
  return (
    `[decimated: ${c.toolName}(${c.argsSummary}) → ${c.isError ? "error, " : ""}${size}. ` +
    `Removed from context (${why}); re-run the tool if the content is needed.]`
  );
}

const TRIM_HEAD = 1_200;
const TRIM_TAIL = 600;

// Keep the `\n[decimated: N chars` marker in sync with `TRIM_MARKER`
// (candidates.ts), which stops trims from being decimated again.
function trimText(c: Candidate): string {
  const omitted = c.text.length - TRIM_HEAD - TRIM_TAIL;
  const head = c.text.slice(0, TRIM_HEAD);
  const tail = c.text.slice(-TRIM_TAIL);
  return (
    `${head}\n[decimated: ${omitted} chars${c.images ? ` and ${c.images} image(s)` : ""} elided from ` +
    `${c.toolName}(${c.argsSummary}); re-run the tool if the full output is needed]\n${tail}`
  );
}

function render(c: Candidate, action: Action): string | undefined {
  if (action === "keep") return undefined;
  // Trimming only pays when there's a real middle to drop.
  if (action === "trim" && c.text.length > (TRIM_HEAD + TRIM_TAIL) * 1.5)
    return trimText(c);
  return stubText(c);
}

// --- decisions ---------------------------------------------------------------------

export function heuristicAction(c: Candidate, threshold: number): Action {
  if (c.prior < threshold) return "keep";
  if (
    c.reasons.includes("superseded-read") ||
    c.reasons.includes("failed-retry")
  )
    return "stub";
  return "trim";
}

/** Which candidates the classifier should see (the uncertain middle band). */
export function needsModel(c: Candidate, ccfg: ClassifierConfig): boolean {
  return c.prior < ccfg.autoAcceptPrior;
}

function modelAction(v: Verdict, ccfg: ClassifierConfig): Action {
  if (v.pNeeded >= ccfg.tauKeep) return "keep";
  if (v.action !== "keep" && v.pStubOk >= ccfg.tauStub) return v.action;
  // Not needed verbatim but the stub may lose something: keep the gist.
  return "trim";
}

export function buildPlan(args: {
  candidates: Candidate[];
  messageTokens: number[];
  leafId: string | null;
  cfg: DecimateConfig;
  verdicts?: Map<string, Verdict>;
  classifier?: ClassifyUsage;
  systemTokens: number;
}): Plan {
  const { candidates, cfg, verdicts } = args;
  const ccfg = cfg.classifier;
  const decisions: Decision[] = [];
  const edits: Edit[] = [];
  let saved = 0;
  let breakIndex = Number.POSITIVE_INFINITY;

  for (const c of candidates) {
    const hAction = heuristicAction(c, cfg.heuristicThreshold);
    let action = hAction;
    let source: DecisionSource = "heuristic";
    const verdict = verdicts?.get(c.entryId);
    if (ccfg && verdicts && !cfg.shadow) {
      if (!needsModel(c, ccfg)) {
        source = "auto-accept";
        action = hAction === "keep" ? "stub" : hAction;
      } else if (verdict) {
        source = "classifier";
        action = modelAction(verdict, ccfg);
      } else {
        source = "classifier-fallback";
      }
    }

    const text = render(c, action);
    const savedTokens =
      text === undefined
        ? 0
        : Math.max(0, c.estTokens - Math.ceil(text.length / 4));
    if (text !== undefined && savedTokens > 0) {
      edits.push({
        entryId: c.entryId,
        toolCallId: c.toolCallId,
        content: [{ type: "text", text }],
      });
      saved += savedTokens;
      breakIndex = Math.min(breakIndex, c.messageIndex);
    }
    decisions.push({
      entryId: c.entryId,
      toolCallId: c.toolCallId,
      toolName: c.toolName,
      argsSummary: c.argsSummary,
      path: c.path,
      reasons: c.reasons,
      prior: Number(c.prior.toFixed(3)),
      estTokens: c.estTokens,
      messageIndex: c.messageIndex,
      heuristicAction: hAction,
      action: text !== undefined && savedTokens > 0 ? action : "keep",
      source,
      verdict,
      savedTokens,
    });
  }

  const bi = Number.isFinite(breakIndex)
    ? breakIndex
    : args.messageTokens.length;
  const prefixTokens =
    args.systemTokens +
    args.messageTokens.slice(0, bi).reduce((a, b) => a + b, 0);

  return {
    id: `d${Date.now().toString(36)}`,
    createdAt: Date.now(),
    leafId: args.leafId,
    decisions,
    edits,
    savedTokens: saved,
    breakIndex: bi,
    prefixTokens,
    shadow: cfg.shadow,
    classifier: args.classifier,
  };
}

// --- reporting ---------------------------------------------------------------------

export function kTokens(n: number): string {
  return n >= 1_000
    ? `${(n / 1_000).toFixed(n >= 10_000 ? 0 : 1)}k`
    : String(n);
}

export function describePlan(plan: Plan, limit = 12): string[] {
  const applied = plan.decisions.filter((d) => d.action !== "keep");
  const lines = [
    `${applied.length} edit(s), −${kTokens(plan.savedTokens)} tokens est.` +
      ` · ${plan.decisions.length - applied.length} candidate(s) kept` +
      (plan.classifier
        ? ` · ${plan.shadow ? "shadow " : ""}classifier ${plan.classifier.model}: ${plan.classifier.calls} call(s)` +
          `${plan.classifier.cached ? `, ${plan.classifier.cached} cached` : ""}` +
          `${plan.classifier.errors ? `, ${plan.classifier.errors} error(s)` : ""}` +
          `${plan.classifier.timedOut ? ", timed out" : ""}` +
          ` · $${plan.classifier.costUsd.toFixed(4)}`
        : ""),
  ];
  const sorted = [...plan.decisions].sort((a, b) => b.estTokens - a.estTokens);
  for (const d of sorted.slice(0, limit)) {
    const v = d.verdict
      ? ` · p(needed)=${d.verdict.pNeeded.toFixed(2)} model:${d.verdict.action}`
      : "";
    const disagree =
      d.verdict && plan.shadow && d.verdict.action !== d.heuristicAction
        ? " ≠"
        : "";
    lines.push(
      `  ${d.action.padEnd(4)} ${kTokens(d.estTokens).padStart(5)} ${d.toolName}(${d.argsSummary.slice(0, 60)})` +
        ` [${d.reasons.join(",")} ${d.prior.toFixed(2)}]${v}${disagree}`,
    );
  }
  if (sorted.length > limit) lines.push(`  … ${sorted.length - limit} more`);
  return lines;
}
