// Persisted decimation records (custom entries, never sent to the model) and
// the usefulness report derived from them plus the rest of the branch.
//
// Everything after the record is derived on demand from the branch itself —
// later billed calls (payback), later tool calls (regret) and restores — so
// nothing but the apply record needs persisting.

import type {
  ExtensionContext,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";
import { summarizeArgs } from "./candidates";
import type { ClassifyUsage } from "./classify";
import type { Coldness } from "./coldness";
import { kTokens, type Action, type Plan } from "./plan";

export const CUSTOM_TYPE = "decimate";

export interface RecordedDecision {
  entryId: string;
  toolName: string;
  path?: string;
  argsSummary: string;
  prior: number;
  heuristicAction: Action;
  action: Action;
  savedTokens: number;
  pNeeded?: number;
  modelAction?: Action;
}

export type ColdVerdict =
  | "cold-confirmed"
  | "was-warm"
  | "inconclusive"
  | "no-usage";

export interface Outcome {
  provider?: string;
  model?: string;
  input: number;
  cacheRead: number;
  cacheWrite: number;
  costUsd: number;
  verdict: ColdVerdict;
  /** Tokens not (re-)written on the cold send itself. */
  coldSendSavedUsd: number;
}

export interface AppliedRecord {
  kind: "applied";
  planId: string;
  source: StageSource;
  shadow: boolean;
  coldness: Coldness;
  savedTokens: number;
  prefixTokens: number;
  systemTokens: number;
  decisions: RecordedDecision[];
  classifier?: ClassifyUsage;
  outcome?: Outcome;
}

export interface RestoredRecord {
  kind: "restored";
  planIds: string[];
  entryIds: string[];
}

export type LedgerRecord = AppliedRecord | RestoredRecord;
export type StageSource = "manual" | "auto" | "resume" | "restore";

export function recordFromPlan(
  plan: Plan,
  source: StageSource,
  coldness: Coldness,
  systemTokens: number,
): AppliedRecord {
  return {
    kind: "applied",
    planId: plan.id,
    source,
    shadow: plan.shadow,
    coldness,
    savedTokens: plan.savedTokens,
    prefixTokens: plan.prefixTokens,
    systemTokens,
    classifier: plan.classifier,
    decisions: plan.decisions.map((d) => ({
      entryId: d.entryId,
      toolName: d.toolName,
      path: d.path,
      argsSummary: d.argsSummary,
      prior: d.prior,
      heuristicAction: d.heuristicAction,
      action: d.action,
      savedTokens: d.savedTokens,
      pNeeded: d.verdict ? Number(d.verdict.pNeeded.toFixed(3)) : undefined,
      modelAction: d.verdict?.action,
    })),
  };
}

// --- cold verification -------------------------------------------------------------

interface UsageLike {
  input: number;
  cacheRead: number;
  cacheWrite: number;
  cost?: { total: number };
}

/**
 * Did the decimated send really hit a cold cache? A warm cache would have
 * served the prefix before the earliest edit; the system prompt + tools may
 * still be read from another session's identical prefix, so that much is
 * tolerated. When the edit sits so early that both outcomes look alike, say so.
 */
export function judgeOutcome(
  usage: UsageLike | undefined,
  rec: Pick<AppliedRecord, "prefixTokens" | "systemTokens" | "savedTokens">,
  rates: { input: number; cacheWrite: number } | undefined,
  ident: { provider?: string; model?: string },
): Outcome {
  if (!usage) {
    return {
      ...ident,
      input: 0,
      cacheRead: 0,
      cacheWrite: 0,
      costUsd: 0,
      verdict: "no-usage",
      coldSendSavedUsd: 0,
    };
  }
  const distinguishing = rec.prefixTokens - rec.systemTokens;
  let verdict: ColdVerdict;
  if (distinguishing < 4_096) verdict = "inconclusive";
  else if (usage.cacheRead > rec.systemTokens * 1.3 + distinguishing * 0.5)
    verdict = "was-warm";
  else verdict = "cold-confirmed";
  const writePrice = rates
    ? rates.cacheWrite > 0
      ? rates.cacheWrite
      : rates.input
    : 0;
  return {
    ...ident,
    input: usage.input,
    cacheRead: usage.cacheRead,
    cacheWrite: usage.cacheWrite,
    costUsd: usage.cost?.total ?? 0,
    verdict,
    coldSendSavedUsd:
      verdict === "was-warm" ? 0 : (rec.savedTokens * writePrice) / 1e6,
  };
}

// --- summaries ---------------------------------------------------------------------

/** One line per record: the turn-end notice and the transcript entry. */
export function recordSummary(rec: LedgerRecord): string {
  if (rec.kind === "restored")
    return `decimate: restored ${rec.entryIds.length} result(s)`;
  const edits = rec.decisions.filter((d) => d.action !== "keep").length;
  const o = rec.outcome;
  return (
    `decimate (${rec.source}): −${kTokens(rec.savedTokens)}` +
    ` via ${edits} edit(s)` +
    (o ? ` · cache ${o.verdict}` : "") +
    (o && o.verdict !== "no-usage"
      ? ` (read ${kTokens(o.cacheRead)}, wrote ${kTokens(o.cacheWrite)})`
      : "") +
    (o?.verdict === "was-warm" ? " — warmth given up on this route" : "")
  );
}

/** Per-edit lines for the expanded transcript entry. */
export function recordDetails(rec: LedgerRecord): string[] {
  if (rec.kind === "restored")
    return [`from ${rec.planIds.length} decimation(s)`];
  const lines = rec.decisions
    .filter((d) => d.action !== "keep")
    .map(
      (d) =>
        `${d.action} ${d.toolName} ${d.path ?? d.argsSummary.slice(0, 60)}` +
        ` −${kTokens(d.savedTokens)} (prior ${d.prior.toFixed(2)})`,
    );
  if (rec.classifier) {
    const c = rec.classifier;
    lines.push(
      `classifier ${c.model}: ${c.calls} call(s), ${c.cached} cached` +
        ` · $${c.costUsd.toFixed(4)}`,
    );
  }
  return lines;
}

// --- report --------------------------------------------------------------------------

function ledgerRecord(entry: SessionEntry): LedgerRecord | undefined {
  if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE)
    return undefined;
  const data = entry.data as { kind?: unknown } | undefined;
  return data && (data.kind === "applied" || data.kind === "restored")
    ? (data as LedgerRecord)
    : undefined;
}

export function appliedRecords(
  branch: SessionEntry[],
): Array<{ index: number; rec: AppliedRecord }> {
  const out: Array<{ index: number; rec: AppliedRecord }> = [];
  branch.forEach((entry, index) => {
    const rec = ledgerRecord(entry);
    if (rec?.kind === "applied") out.push({ index, rec });
  });
  return out;
}

interface ToolCallLike {
  name: string;
  args: Record<string, unknown>;
}

function toolCallsOf(entry: SessionEntry): ToolCallLike[] {
  if (entry.type !== "message") return [];
  const m = entry.message as { role?: string; content?: unknown };
  if (m.role !== "assistant" || !Array.isArray(m.content)) return [];
  const out: ToolCallLike[] = [];
  for (const b of m.content as Array<{
    type?: string;
    name?: unknown;
    arguments?: unknown;
  }>) {
    if (b.type === "toolCall" && typeof b.name === "string") {
      const args =
        b.arguments && typeof b.arguments === "object"
          ? (b.arguments as Record<string, unknown>)
          : {};
      out.push({ name: b.name, args });
    }
  }
  return out;
}

export interface RecordReport {
  rec: AppliedRecord;
  callsAfter: number;
  readSavedUsd: number;
  regrets: RecordedDecision[];
  restored: boolean;
}

export function buildReport(ctx: ExtensionContext): RecordReport[] {
  const branch = ctx.sessionManager.getBranch();
  const restoredPlans = new Map<string, number>();
  branch.forEach((entry, index) => {
    const rec = ledgerRecord(entry);
    if (rec?.kind === "restored")
      for (const id of rec.planIds) restoredPlans.set(id, index);
  });

  return appliedRecords(branch).map(({ index, rec }) => {
    const end = restoredPlans.get(rec.planId) ?? branch.length;
    const edited = rec.decisions.filter((d) => d.action !== "keep");
    let callsAfter = 0;
    let readSavedUsd = 0;
    const regretted = new Set<string>();

    for (let i = index + 1; i < end; i++) {
      const entry = branch[i];
      if (entry.type === "message") {
        const m = entry.message as {
          role?: string;
          provider?: string;
          model?: string;
          usage?: UsageLike;
        };
        if (
          m.role === "assistant" &&
          m.usage &&
          m.usage.input + m.usage.cacheRead + m.usage.cacheWrite > 0
        ) {
          callsAfter++;
          // The record is written at the cold send's turn_end, so every billed
          // call after it is a later call (the cold send itself is `outcome`).
          if (m.provider && m.model) {
            const price =
              ctx.modelRegistry.find(m.provider, m.model)?.cost.cacheRead ?? 0;
            readSavedUsd += (rec.savedTokens * price) / 1e6;
          }
        }
      }
      for (const call of toolCallsOf(entry)) {
        for (const d of edited) {
          if (regretted.has(d.entryId)) continue;
          const p = call.args.path ?? call.args.file_path;
          const samePath =
            d.path !== undefined &&
            typeof p === "string" &&
            p.replace(/^\.\//, "") === d.path;
          const sameCall =
            call.name === d.toolName &&
            summarizeArgs(call.args) === d.argsSummary;
          if (
            (d.toolName === "read" && call.name === "read" && samePath) ||
            sameCall
          )
            regretted.add(d.entryId);
        }
      }
    }

    return {
      rec,
      callsAfter,
      readSavedUsd,
      regrets: edited.filter((d) => regretted.has(d.entryId)),
      restored: restoredPlans.has(rec.planId),
    };
  });
}

export function renderReport(reports: RecordReport[]): string[] {
  if (reports.length === 0) return ["no decimations on this branch"];
  const lines: string[] = [];
  let totalSaved = 0;
  let totalCost = 0;
  let totalEdits = 0;
  let totalRegrets = 0;
  let modelWouldKeep = 0;
  let heuristicWouldKeep = 0;
  let shadowCompared = 0;
  let shadowDisagree = 0;

  for (const r of reports) {
    const { rec } = r;
    const edits = rec.decisions.filter((d) => d.action !== "keep");
    const coldSave = rec.outcome?.coldSendSavedUsd ?? 0;
    const clsCost = rec.classifier?.costUsd ?? 0;
    const net = coldSave + r.readSavedUsd - clsCost;
    totalSaved += coldSave + r.readSavedUsd;
    totalCost += clsCost;
    totalEdits += edits.length;
    totalRegrets += r.regrets.length;
    for (const d of r.regrets) {
      if (d.modelAction === "keep") modelWouldKeep++;
      if (d.heuristicAction === "keep") heuristicWouldKeep++;
    }
    for (const d of rec.decisions) {
      if (d.modelAction === undefined) continue;
      shadowCompared++;
      if (d.modelAction !== d.heuristicAction) shadowDisagree++;
    }
    lines.push(
      `${rec.planId} ${rec.source}${rec.shadow ? " (shadow)" : ""} · −${kTokens(rec.savedTokens)} · ${edits.length} edit(s)` +
        ` · ${rec.coldness.state}: ${rec.coldness.reason}`,
      `  cold send: ${rec.outcome ? `${rec.outcome.verdict}, read ${kTokens(rec.outcome.cacheRead)} wrote ${kTokens(rec.outcome.cacheWrite)} in ${kTokens(rec.outcome.input)}` : "pending"}` +
        ` · ${r.callsAfter} later call(s)` +
        ` · saved $${(coldSave + r.readSavedUsd).toFixed(4)}${clsCost ? ` − classifier $${clsCost.toFixed(4)}` : ""} = net $${net.toFixed(4)}`,
      `  regret: ${r.regrets.length}/${edits.length}${r.restored ? " · restored" : ""}` +
        (r.regrets.length
          ? ` (${r.regrets.map((d) => `${d.toolName} ${d.path ?? d.argsSummary.slice(0, 40)}`).join("; ")})`
          : ""),
    );
  }

  lines.push(
    `total: ${reports.length} decimation(s) · ${totalEdits} edit(s) · regret ${totalRegrets}/${totalEdits}` +
      ` · saved $${totalSaved.toFixed(4)} − classifier $${totalCost.toFixed(4)}`,
  );
  if (shadowCompared > 0) {
    lines.push(
      `classifier vs heuristics: disagree on ${shadowDisagree}/${shadowCompared}` +
        ` · of ${totalRegrets} regretted edit(s) the model would have kept ${modelWouldKeep}, heuristics ${heuristicWouldKeep}`,
    );
  }
  return lines;
}
