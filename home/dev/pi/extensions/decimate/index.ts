// pi-decimate: fast, LLM-free context shrinking for cold prompt caches.
//
// Heuristics pick old tool results that are superseded, failed-and-retried or
// bulky; an optional classifier model ("decision model") scores the uncertain
// ones; the survivors are replaced with one-line stubs or head/tail trims via
// append-only `context_edit` entries (raw history is untouched, `/decimate
// restore` brings content back).
//
// Rewriting history invalidates the prompt cache from the first edit onwards,
// so decimation is meant for sends that are cold anyway. pi-cachemire's
// cache clock (globalThis.__piCachemire) is the coldness gate, and each
// decimated send's billed usage is checked afterwards to confirm the cache
// really was cold. `/decimate stats` reports payback and regret.
//
// Applying: edits can only be persisted at an actionable boundary, so a plan is
// *staged*, applied in-memory by the `context` hook to the next request, and
// persisted by that turn's `turn_end` — the sent context and the persisted
// projection match, and the next call reads it from cache. Staging itself is
// recorded right away as a `staged` ledger entry (closed by whatever ledger
// entry follows it, see ledger.ts), so a staged plan survives a restart and is
// re-staged when its branch is loaded again.
//
// Config: <agentDir>/extensions/decimate/config.json (read-only here); toggle state:
// $XDG_STATE_HOME/pi/decimate/state.json (see README.md).

import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  SessionBoundaryDraft,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { scanCandidates } from "./candidates";
import {
  classifyCandidates,
  resolveClassifier,
  type ClassifyUsage,
  type Verdict,
} from "./classify";
import { cacheColdness, type Coldness } from "./coldness";
import {
  configPath,
  loadConfig,
  saveToggle,
  statePath,
  type DecimateConfig,
} from "./config";
import {
  appliedRecords,
  buildReport,
  CUSTOM_TYPE,
  judgeOutcome,
  openStaged,
  recordDetails,
  recordFromPlan,
  recordSummary,
  renderReport,
  restoreEdits,
  skippedFromPlan,
  skippedRecords,
  standingSkip,
  type DroppedRecord,
  type LedgerRecord,
  type SkippedRecord,
  type StagedRecord,
  type StageSource,
} from "./ledger";
import {
  buildPlan,
  describePlan,
  kTokens,
  needsModel,
  stubText,
  type Edit,
  type Plan,
} from "./plan";

interface Staged {
  /** Plan id (`planId` of its ledger records); restores get an `r…` id. */
  id: string;
  source: StageSource;
  force: boolean;
  edits: Edit[];
  plan?: Plan;
  restorePlanIds?: string[];
}

interface Inflight extends Staged {
  coldness: Coldness;
  /** Edits whose targets were present in the request (the ones to persist). */
  applied: Edit[];
}

const STATUS_KEY = "decimate";

export default function decimateExtension(pi: ExtensionAPI): void {
  let cfg: DecimateConfig = loadConfig();
  let staged: Staged | undefined;
  let inflight: Inflight | undefined;
  /** planId of the branch's open `staged` entry (the only one rendered). */
  let openStageId: string | undefined;
  /** Drops and skips decided mid-run, persisted at the next boundary. */
  let pendingRecords: Array<DroppedRecord | SkippedRecord> = [];
  /**
   * Gain of the last auto plan skipped as too small (0: nothing eligible);
   * shown until the next run.
   */
  let skippedGain: number | undefined;
  let firstSendOfRun = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let classifierMissingWarned = false;
  /** A manual `/decimate apply` is waiting on the classifier. */
  let planning = false;
  const verdictCache = new Map<string, Verdict>();

  // --- helpers -----------------------------------------------------------------

  function headTokens(ctx: ExtensionContext): number {
    const active = new Set(pi.getActiveTools());
    const toolChars = pi
      .getAllTools()
      .filter((t) => active.has(t.name))
      .reduce((n, t) => n + JSON.stringify(t).length, 0);
    return Math.ceil((ctx.getSystemPrompt().length + toolChars) / 4);
  }

  function updateStatus(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;
    const text = planning
      ? "✂ planning…"
      : staged
        ? `✂ staged −${kTokens(staged.plan?.savedTokens ?? 0)}`
        : cfg.auto
          ? `✂ auto${cfg.shadow && cfg.classifier ? " (shadow)" : ""}` +
            (skippedGain === 0
              ? " (nothing eligible)"
              : skippedGain !== undefined
                ? ` (−${kTokens(skippedGain)} < ${kTokens(cfg.minGainTokens)})`
                : "")
          : undefined;
    ctx.ui.setStatus(STATUS_KEY, text);
  }

  function clearTimer(): void {
    if (timer) clearTimeout(timer);
    timer = undefined;
  }

  /**
   * `ahead`: planned before the send it is for, whose user message isn't on
   * the branch yet (see `scanCandidates`). Inline planning in the `context`
   * hook already sees it.
   */
  async function makePlan(
    ctx: ExtensionContext,
    opts: { ahead: boolean; timeoutMs?: number },
  ): Promise<Plan> {
    const { ahead, timeoutMs } = opts;
    const projection = ctx.sessionManager.buildSessionProjection();
    const scan = scanCandidates(projection.entries, cfg, ahead);
    let verdicts: Map<string, Verdict> | undefined;
    let usage: ClassifyUsage | undefined;

    const ccfg = cfg.classifier;
    if (ccfg) {
      const model = resolveClassifier(ctx, ccfg);
      if (!model) {
        if (!classifierMissingWarned && ctx.hasUI) {
          ctx.ui.notify(
            `decimate: classifier ${ccfg.provider}/${ccfg.id} not found; using heuristics only`,
            "warning",
          );
        }
        classifierMissingWarned = true;
      } else {
        const ask = scan.candidates.filter((c) => needsModel(c, ccfg));
        if (ask.length === 0) {
          verdicts = new Map();
        } else {
          ({ verdicts, usage } = await classifyCandidates(
            ctx,
            model,
            ask,
            scan.task,
            stubText,
            {
              timeoutMs: timeoutMs ?? ccfg.timeoutMs,
              maxCandidates: ccfg.maxCandidates,
              cache: verdictCache,
            },
          ));
        }
      }
    }

    return buildPlan({
      candidates: scan.candidates,
      messageTokens: scan.messageTokens,
      leafId: ctx.sessionManager.getLeafId(),
      cfg,
      verdicts,
      classifier: usage,
      systemTokens: headTokens(ctx),
    });
  }

  /**
   * Stage `next` and record it at once. Only call while idle: the record is
   * closed by the next ledger entry, which must belong to this plan's send.
   */
  function stage(ctx: ExtensionContext, next: Staged, savedTokens: number) {
    const record: StagedRecord = {
      kind: "staged",
      planId: next.id,
      source: next.source,
      force: next.force,
      supersedes: openStageId,
      savedTokens,
      edits: next.edits.length,
      plan: next.plan,
      restorePlanIds: next.restorePlanIds,
    };
    staged = next;
    // Set before appending: the renderer runs on append.
    openStageId = next.id;
    pi.appendEntry(CUSTOM_TYPE, record);
    updateStatus(ctx);
  }

  function stagePlan(
    ctx: ExtensionContext,
    plan: Plan,
    source: StageSource,
    force = false,
  ): void {
    stage(
      ctx,
      { id: plan.id, source, force, edits: plan.edits, plan },
      plan.savedTokens,
    );
  }

  /**
   * Note an auto plan that saved too little: the status bar shows its gain
   * (or that nothing was eligible) until the next run, and a `skipped` record
   * keeps it (and any classifier spend) in `/decimate stats`. Plans with
   * neither edits nor classifier calls aren't recorded. Mid-run records wait
   * for the next boundary.
   */
  function skipPlan(
    ctx: ExtensionContext,
    plan: Plan,
    source: StageSource,
    midRun: boolean,
  ): void {
    skippedGain = plan.edits.length > 0 ? plan.savedTokens : 0;
    if (plan.edits.length === 0 && !plan.classifier?.calls) {
      updateStatus(ctx);
      return;
    }
    const rec = skippedFromPlan(plan, source, cfg.minGainTokens);
    if (midRun) pendingRecords.push(rec);
    else pi.appendEntry(CUSTOM_TYPE, rec);
    updateStatus(ctx);
  }

  /**
   * Whether an auto plan would only repeat the branch's standing `skipped`
   * record (nothing plan-relevant appended since, same config). Manual
   * `/decimate apply` always re-plans.
   */
  function stillSkipped(ctx: ExtensionContext): boolean {
    const s = standingSkip(ctx.sessionManager.getBranch());
    if (!s || s.savedTokens >= cfg.minGainTokens || s.shadow !== cfg.shadow)
      return false;
    if (skippedGain === undefined) {
      skippedGain = s.savedTokens;
      updateStatus(ctx);
    }
    return true;
  }

  /** Background (idle) auto planning: stage the plan, or record why not. */
  function planInBackground(ctx: ExtensionContext, source: StageSource): void {
    if (stillSkipped(ctx)) return;
    void makePlan(ctx, { ahead: true }).then((plan) => {
      if (staged || inflight || !ctx.isIdle()) return;
      if (plan.edits.length > 0 && plan.savedTokens >= cfg.minGainTokens)
        stagePlan(ctx, plan, source);
      else skipPlan(ctx, plan, source, false);
    });
  }

  /** Drop the staged plan now (idle only; mid-run use `pendingRecords`). */
  function dropStaged(ctx: ExtensionContext, reason: string): void {
    const s = staged;
    staged = undefined;
    if (s && s.id === openStageId) {
      openStageId = undefined;
      pi.appendEntry(CUSTOM_TYPE, {
        kind: "dropped",
        planId: s.id,
        reason,
      } satisfies DroppedRecord);
    }
    updateStatus(ctx);
  }

  /** Mid-run drop of a recorded plan, persisted at the next boundary. */
  function queueDrop(id: string, reason: string): void {
    if (id !== openStageId) return;
    openStageId = undefined;
    pendingRecords.push({ kind: "dropped", planId: id, reason });
  }

  function takePending(): SessionBoundaryDraft[] {
    const drafts = pendingRecords.map(
      (data): SessionBoundaryDraft => ({
        type: "custom",
        customType: CUSTOM_TYPE,
        data,
      }),
    );
    pendingRecords = [];
    return drafts;
  }

  function reset(ctx: ExtensionContext): void {
    staged = undefined;
    inflight = undefined;
    openStageId = undefined;
    pendingRecords = [];
    skippedGain = undefined;
    firstSendOfRun = false;
    clearTimer();
    updateStatus(ctx);
  }

  /**
   * Re-stage the branch's open `staged` entry, e.g. one staged before the
   * session was closed. Returns whether a plan is staged afterwards.
   */
  function resumeStaged(ctx: ExtensionContext): boolean {
    const branch = ctx.sessionManager.getBranch();
    const rec = openStaged(branch);
    openStageId = rec?.planId;
    if (!rec) return false;
    const edits =
      rec.source === "restore"
        ? restoreEdits(branch, rec.restorePlanIds ?? [], (id) =>
            ctx.sessionManager.getEntry(id),
          )
        : (rec.plan?.edits ?? []);
    staged = {
      id: rec.planId,
      source: rec.source,
      force: rec.force,
      edits,
      plan: rec.plan,
      restorePlanIds: rec.restorePlanIds,
    };
    if (edits.length === 0) {
      dropStaged(ctx, "nothing left to apply");
      return false;
    }
    updateStatus(ctx);
    return true;
  }

  // --- lifecycle ------------------------------------------------------------------

  pi.on("session_start", async (event, ctx) => {
    cfg = loadConfig();
    reset(ctx);
    if (resumeStaged(ctx)) return;
    // Cold resume: build the plan in the background; the send still checks coldness.
    if (cfg.auto && (event.reason === "resume" || event.reason === "startup")) {
      planInBackground(ctx, "resume");
    }
  });

  pi.on("session_tree", async (_event, ctx) => {
    reset(ctx);
    resumeStaged(ctx);
  });
  pi.on("session_shutdown", async () => {
    clearTimer();
    staged = inflight = undefined;
  });

  pi.on("agent_start", async (_event, ctx) => {
    firstSendOfRun = true;
    clearTimer();
    if (skippedGain !== undefined) {
      skippedGain = undefined;
      updateStatus(ctx);
    }
  });

  // Auto mode: precompute a plan for the moment the cache is predicted to go
  // cold, so the next (cold) send doesn't wait on the classifier.
  pi.on("agent_settled", async (_event, ctx) => {
    clearTimer();
    if (!cfg.auto || !cfg.precompute || staged) return;
    const c = cacheColdness(ctx);
    if (c.coldAt === undefined) return;
    const delay = Math.max(0, c.coldAt - Date.now()) + 1_000;
    timer = setTimeout(() => {
      timer = undefined;
      if (staged || !ctx.isIdle() || cacheColdness(ctx).state !== "cold")
        return;
      planInBackground(ctx, "auto");
    }, delay);
    timer.unref?.();
  });

  pi.on("context", async (event, ctx) => {
    const first = firstSendOfRun;
    firstSendOfRun = false;

    if (!inflight && staged) {
      const s = staged;
      staged = undefined;
      const c = cacheColdness(ctx);
      const ok =
        s.source === "restore" ||
        s.force ||
        (s.source === "manual" ? c.state !== "warm" : c.state === "cold");
      if (ok) {
        inflight = { ...s, coldness: c, applied: [] };
      } else {
        queueDrop(s.id, `cache ${c.state}: ${c.reason}`);
        if (ctx.hasUI)
          ctx.ui.notify(
            `decimate: staged plan dropped — cache is ${c.state} (${c.reason})`,
            "info",
          );
      }
      updateStatus(ctx);
    } else if (!inflight && cfg.auto && first) {
      const c = cacheColdness(ctx);
      if (c.state === "cold" && !stillSkipped(ctx)) {
        const plan = await makePlan(ctx, {
          ahead: false,
          timeoutMs: cfg.classifier?.autoTimeoutMs,
        });
        if (plan.edits.length > 0 && plan.savedTokens >= cfg.minGainTokens) {
          inflight = {
            id: plan.id,
            source: "auto",
            force: false,
            edits: plan.edits,
            plan,
            coldness: c,
            applied: [],
          };
        } else {
          skipPlan(ctx, plan, "auto", true);
        }
      }
    }

    if (!inflight) return;
    const byCall = new Map(inflight.edits.map((e) => [e.toolCallId, e]));
    const applied: Edit[] = [];
    const messages = event.messages.map((m) => {
      const r = m as { role?: string; toolCallId?: string };
      const edit =
        r.role === "toolResult" && r.toolCallId
          ? byCall.get(r.toolCallId)
          : undefined;
      if (!edit) return m;
      applied.push(edit);
      return { ...m, content: edit.content } as typeof m;
    });
    if (applied.length === 0) {
      queueDrop(inflight.id, "no target results left in context");
      inflight = undefined;
      return;
    }
    // Later requests in the same turn (retries) re-apply; keep the widest set.
    if (applied.length >= inflight.applied.length) inflight.applied = applied;
    return { messages };
  });

  pi.on("agent_before_settle", async (event) => {
    const drops = takePending();
    if (drops.length === 0) return;
    return { entries: [...event.entries, ...drops] };
  });

  pi.on("turn_end", async (event, ctx) => {
    const drops = takePending();
    if (!inflight) {
      if (drops.length === 0) return;
      return { entries: [...event.entries, ...drops] };
    }
    const s = inflight;
    inflight = undefined;
    if (s.id === openStageId) openStageId = undefined;

    const drafts: SessionBoundaryDraft[] = [
      ...drops,
      ...s.applied.map(
        (e): SessionBoundaryDraft => ({
          type: "context_edit",
          targetId: e.entryId,
          replacement: { content: e.content },
        }),
      ),
    ];

    let data: LedgerRecord;
    if (s.source === "restore") {
      data = {
        kind: "restored",
        stageId: s.id,
        planIds: s.restorePlanIds ?? [],
        entryIds: s.applied.map((e) => e.entryId),
      };
    } else {
      const plan = s.plan as Plan;
      const appliedIds = new Set(s.applied.map((e) => e.entryId));
      const effective: Plan = {
        ...plan,
        decisions: plan.decisions.map((d) =>
          d.action !== "keep" && !appliedIds.has(d.entryId)
            ? { ...d, action: "keep" as const, savedTokens: 0 }
            : d,
        ),
      };
      effective.savedTokens = effective.decisions.reduce(
        (n, d) => n + d.savedTokens,
        0,
      );
      const rec = recordFromPlan(
        effective,
        s.source,
        s.coldness,
        headTokens(ctx),
      );
      const msg = event.message as {
        role?: string;
        provider?: string;
        model?: string;
        usage?: {
          input: number;
          cacheRead: number;
          cacheWrite: number;
          cost?: { total: number };
        };
      };
      // Errored/aborted sends report zero (or partial) usage, which would
      // look like a cold cache: treat them as unjudgeable.
      rec.outcome = judgeOutcome(
        event.outcome === "completed" && msg.role === "assistant"
          ? msg.usage
          : undefined,
        rec,
        ctx.model?.cost,
        {
          provider: msg.provider,
          model: msg.model,
        },
      );
      data = rec;
    }
    drafts.push({ type: "custom", customType: CUSTOM_TYPE, data });
    // The entry itself shows up in the transcript (renderer below); only a
    // cache that turned out warm needs extra attention.
    if (
      ctx.hasUI &&
      data.kind === "applied" &&
      data.outcome?.verdict === "was-warm"
    )
      ctx.ui.notify(recordSummary(data), "warning");
    updateStatus(ctx);
    return { entries: [...event.entries, ...drafts] };
  });

  // --- transcript ------------------------------------------------------------------

  // One line where the decimation happened; the per-edit list when expanded.
  pi.registerEntryRenderer<LedgerRecord>(CUSTOM_TYPE, (entry, opts, theme) => {
    const rec = entry.data;
    if (!rec) return undefined;
    // Closed staged plans and drops are bookkeeping; the open staged plan and
    // what actually applied are what the transcript shows. A staged entry that
    // closes while on screen disappears on the next re-render. Skipped plans
    // only show when they cost a classifier call.
    const skippedPaid = rec.kind === "skipped" && !!rec.classifier?.calls;
    const shown =
      rec.kind === "applied" ||
      rec.kind === "restored" ||
      skippedPaid ||
      (rec.kind === "staged" && rec.planId === openStageId);
    if (!shown) return undefined;
    const warm = rec.kind === "applied" && rec.outcome?.verdict === "was-warm";
    const [label, ...rest] = recordSummary(rec).split(": ");
    const color = warm ? "warning" : skippedPaid ? "dim" : "accent";
    let text =
      theme.fg(color, `✂ ${label}`) + theme.fg("dim", `: ${rest.join(": ")}`);
    if (opts.expanded) {
      for (const line of recordDetails(rec))
        text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    return new Text(text, 1, 0);
  });

  // --- command ----------------------------------------------------------------------

  async function apply(
    ctx: ExtensionCommandContext,
    force: boolean,
  ): Promise<void> {
    if (!ctx.isIdle()) {
      ctx.ui.notify("decimate: wait until the agent is idle", "warning");
      return;
    }
    const c = cacheColdness(ctx);
    if (c.state === "warm" && !force) {
      const until = c.coldAt
        ? ` (cold at ${new Date(c.coldAt).toLocaleTimeString()})`
        : "";
      ctx.ui.notify(
        `decimate: cache is warm — ${c.reason}${until}. Decimating now re-writes ~${kTokens(c.expectedRead ?? 0)}` +
          " prompt tokens; use `/decimate apply --force` to do it anyway.",
        "warning",
      );
      return;
    }
    planning = true;
    updateStatus(ctx);
    let plan: Plan;
    try {
      plan = await makePlan(ctx, { ahead: true });
    } finally {
      planning = false;
      updateStatus(ctx);
    }
    const report = describePlan(plan).join("\n");
    if (plan.edits.length === 0) {
      ctx.ui.notify(`decimate: nothing to decimate\n${report}`, "info");
      return;
    }
    if (c.state !== "cold") {
      const ok = await ctx.ui.confirm(
        `Decimate with cache ${c.state}?`,
        `${c.reason} (${c.source}).\nIf the cache is still warm, the next send re-writes ~${kTokens(c.expectedRead ?? 0)}` +
          ` prompt tokens from the first edit on.\n\n${report}`,
      );
      if (!ok) return;
    }
    // The staged entry in the transcript reports it; no notice needed.
    stagePlan(ctx, plan, "manual", force || c.state !== "cold");
  }

  function restore(ctx: ExtensionCommandContext, which: string): void {
    if (!ctx.isIdle()) {
      ctx.ui.notify("decimate: wait until the agent is idle", "warning");
      return;
    }
    const branch = ctx.sessionManager.getBranch();
    const restored = new Set<string>();
    for (const e of branch) {
      if (e.type === "custom" && e.customType === CUSTOM_TYPE) {
        const d = e.data as LedgerRecord | undefined;
        if (d?.kind === "restored")
          for (const id of d.planIds) restored.add(id);
      }
    }
    const open = appliedRecords(branch).filter(
      ({ rec }) => !restored.has(rec.planId),
    );
    const targets = which === "all" ? open : open.slice(-1);
    if (targets.length === 0) {
      ctx.ui.notify("decimate: nothing to restore on this branch", "info");
      return;
    }
    const planIds = targets.map((t) => t.rec.planId);
    const edits = restoreEdits(branch, planIds, (id) =>
      ctx.sessionManager.getEntry(id),
    );
    if (edits.length === 0) {
      // Staging nothing would be dropped silently by the context hook, with no
      // `restored` record, leaving the decimation looking open.
      ctx.ui.notify(
        "decimate: none of the decimated results can be restored" +
          " (source entries missing or not tool results)",
        "warning",
      );
      return;
    }
    stage(
      ctx,
      {
        id: `r${Date.now().toString(36)}`,
        source: "restore",
        force: true,
        edits,
        restorePlanIds: planIds,
      },
      0,
    );
  }

  function toggle(
    ctx: ExtensionCommandContext,
    key: "auto" | "shadow",
    arg: string | undefined,
  ): void {
    const value =
      arg === undefined ? !cfg[key] : arg === "on" || arg === "true";
    cfg[key] = value;
    const err = saveToggle(key, value);
    updateStatus(ctx);
    ctx.ui.notify(
      `decimate: ${key} ${value ? "on" : "off"}${err ? ` (not saved to ${statePath()}: ${err})` : ""}`,
      err ? "warning" : "info",
    );
  }

  const SUBCOMMANDS = [
    "apply",
    "preview",
    "cancel",
    "status",
    "stats",
    "restore",
    "auto",
    "shadow",
  ];

  pi.registerCommand("decimate", {
    description:
      "Shrink context by stubbing old tool results (best on a cold cache)",
    getArgumentCompletions: (prefix) =>
      SUBCOMMANDS.filter((s) => s.startsWith(prefix.trim())).map((s) => ({
        value: s,
        label: s,
      })),
    handler: async (args, ctx) => {
      const words = args.trim().split(/\s+/).filter(Boolean);
      const force = words.includes("--force");
      const [sub = "apply", arg] = words.filter((w) => w !== "--force");
      switch (sub) {
        case "apply":
          return apply(ctx, force);
        case "preview": {
          const c = cacheColdness(ctx);
          const plan = await makePlan(ctx, { ahead: true });
          ctx.ui.notify(
            `cache ${c.state}: ${c.reason} (${c.source})\n${describePlan(plan, 30).join("\n")}`,
            "info",
          );
          return;
        }
        case "cancel":
          if (!staged) {
            ctx.ui.notify("decimate: nothing staged", "info");
            return;
          }
          if (!ctx.isIdle()) {
            ctx.ui.notify("decimate: wait until the agent is idle", "warning");
            return;
          }
          dropStaged(ctx, "cancelled");
          ctx.ui.notify("decimate: staged plan dropped", "info");
          return;
        case "status": {
          const c = cacheColdness(ctx);
          ctx.ui.notify(
            [
              `cache ${c.state}: ${c.reason} (${c.source})`,
              `auto ${cfg.auto ? "on" : "off"} · shadow ${cfg.shadow ? "on" : "off"} · classifier ${cfg.classifier ? `${cfg.classifier.provider}/${cfg.classifier.id}` : "none"}`,
              staged
                ? `staged ${staged.id} (${staged.source}): ${staged.edits.length} edit(s)`
                : "nothing staged",
              `config: ${configPath()} · state: ${statePath()}`,
            ].join("\n"),
            "info",
          );
          return;
        }
        case "stats":
          ctx.ui.notify(
            renderReport(
              buildReport(ctx),
              skippedRecords(ctx.sessionManager.getBranch()),
            ).join("\n"),
            "info",
          );
          return;
        case "restore":
          return restore(ctx, arg ?? "last");
        case "auto":
        case "shadow":
          return toggle(ctx, sub, arg);
        default:
          ctx.ui.notify(
            `decimate: unknown subcommand "${sub}" (${SUBCOMMANDS.join(", ")})`,
            "warning",
          );
      }
    },
  });
}
