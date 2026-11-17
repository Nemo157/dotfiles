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
// projection match, and the next call reads it from cache.
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
  recordDetails,
  recordFromPlan,
  recordSummary,
  renderReport,
  type LedgerRecord,
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
  let firstSendOfRun = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let classifierMissingWarned = false;
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
    const text = staged
      ? `✂ staged −${kTokens(staged.plan?.savedTokens ?? 0)}`
      : cfg.auto
        ? `✂ auto${cfg.shadow && cfg.classifier ? " (shadow)" : ""}`
        : undefined;
    ctx.ui.setStatus(STATUS_KEY, text);
  }

  function clearTimer(): void {
    if (timer) clearTimeout(timer);
    timer = undefined;
  }

  async function makePlan(
    ctx: ExtensionContext,
    timeoutMs?: number,
  ): Promise<Plan> {
    const projection = ctx.sessionManager.buildSessionProjection();
    const scan = scanCandidates(projection.entries, cfg);
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

  function stagePlan(
    ctx: ExtensionContext,
    plan: Plan,
    source: StageSource,
    force = false,
  ): void {
    staged = { source, force, edits: plan.edits, plan };
    updateStatus(ctx);
  }

  function reset(ctx: ExtensionContext): void {
    staged = undefined;
    inflight = undefined;
    firstSendOfRun = false;
    clearTimer();
    updateStatus(ctx);
  }

  // --- lifecycle ------------------------------------------------------------------

  pi.on("session_start", async (event, ctx) => {
    cfg = loadConfig();
    reset(ctx);
    // Cold resume: build the plan in the background; the send still checks coldness.
    if (cfg.auto && (event.reason === "resume" || event.reason === "startup")) {
      void makePlan(ctx).then((plan) => {
        if (
          !staged &&
          !inflight &&
          plan.edits.length > 0 &&
          plan.savedTokens >= cfg.minGainTokens
        ) {
          stagePlan(ctx, plan, "resume");
        }
      });
    }
  });

  pi.on("session_tree", async (_event, ctx) => reset(ctx));
  pi.on("session_shutdown", async () => {
    clearTimer();
    staged = inflight = undefined;
  });

  pi.on("agent_start", async () => {
    firstSendOfRun = true;
    clearTimer();
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
      void makePlan(ctx).then((plan) => {
        if (
          !staged &&
          !inflight &&
          ctx.isIdle() &&
          plan.edits.length > 0 &&
          plan.savedTokens >= cfg.minGainTokens
        ) {
          stagePlan(ctx, plan, "auto");
        }
      });
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
      } else if (ctx.hasUI) {
        ctx.ui.notify(
          `decimate: staged plan dropped — cache is ${c.state} (${c.reason})`,
          "info",
        );
      }
      updateStatus(ctx);
    } else if (!inflight && cfg.auto && first) {
      const c = cacheColdness(ctx);
      if (c.state === "cold") {
        const plan = await makePlan(ctx, cfg.classifier?.autoTimeoutMs);
        if (plan.edits.length > 0 && plan.savedTokens >= cfg.minGainTokens) {
          inflight = {
            source: "auto",
            force: false,
            edits: plan.edits,
            plan,
            coldness: c,
            applied: [],
          };
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
      inflight = undefined;
      return;
    }
    // Later requests in the same turn (retries) re-apply; keep the widest set.
    if (applied.length >= inflight.applied.length) inflight.applied = applied;
    return { messages };
  });

  pi.on("turn_end", async (event, ctx) => {
    if (!inflight) return;
    const s = inflight;
    inflight = undefined;

    const drafts: SessionBoundaryDraft[] = s.applied.map((e) => ({
      type: "context_edit",
      targetId: e.entryId,
      replacement: { content: e.content },
    }));

    let data: LedgerRecord;
    if (s.source === "restore") {
      data = {
        kind: "restored",
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
    if (!rec || (rec.kind !== "applied" && rec.kind !== "restored"))
      return undefined;
    const warm = rec.kind === "applied" && rec.outcome?.verdict === "was-warm";
    const [label, ...rest] = recordSummary(rec).split(": ");
    let text =
      theme.fg(warm ? "warning" : "accent", `✂ ${label}`) +
      theme.fg("dim", `: ${rest.join(": ")}`);
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
    if (cfg.classifier)
      ctx.ui.notify("decimate: planning (classifier)…", "info");
    const plan = await makePlan(ctx);
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
    stagePlan(ctx, plan, "manual", force || c.state !== "cold");
    ctx.ui.notify(
      `decimate: staged — applies to your next prompt (/decimate cancel to drop)\n${report}`,
      "info",
    );
  }

  function restore(ctx: ExtensionCommandContext, which: string): void {
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
    const edits: Edit[] = [];
    for (const { rec } of targets) {
      for (const d of rec.decisions) {
        if (d.action === "keep") continue;
        const entry = ctx.sessionManager.getEntry(d.entryId);
        if (entry?.type !== "message") continue;
        const m = entry.message as {
          role?: string;
          toolCallId?: string;
          content?: unknown;
        };
        if (
          m.role !== "toolResult" ||
          !m.toolCallId ||
          !Array.isArray(m.content)
        )
          continue;
        edits.push({
          entryId: d.entryId,
          toolCallId: m.toolCallId,
          content: m.content as Edit["content"],
        });
      }
    }
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
    staged = {
      source: "restore",
      force: true,
      edits,
      restorePlanIds: targets.map((t) => t.rec.planId),
    };
    updateStatus(ctx);
    ctx.ui.notify(
      `decimate: restore of ${edits.length} result(s) from ${targets.length} decimation(s) staged for your next prompt` +
        " (this rewrites history: the next send re-writes the cache from the first restored result)",
      "info",
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
          const plan = await makePlan(ctx);
          ctx.ui.notify(
            `cache ${c.state}: ${c.reason} (${c.source})\n${describePlan(plan, 30).join("\n")}`,
            "info",
          );
          return;
        }
        case "cancel":
          staged = undefined;
          updateStatus(ctx);
          ctx.ui.notify("decimate: staged plan dropped", "info");
          return;
        case "status": {
          const c = cacheColdness(ctx);
          ctx.ui.notify(
            [
              `cache ${c.state}: ${c.reason} (${c.source})`,
              `auto ${cfg.auto ? "on" : "off"} · shadow ${cfg.shadow ? "on" : "off"} · classifier ${cfg.classifier ? `${cfg.classifier.provider}/${cfg.classifier.id}` : "none"}`,
              staged
                ? `staged (${staged.source}): ${staged.edits.length} edit(s)`
                : "nothing staged",
              `config: ${configPath()} · state: ${statePath()}`,
            ].join("\n"),
            "info",
          );
          return;
        }
        case "stats":
          ctx.ui.notify(renderReport(buildReport(ctx)).join("\n"), "info");
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
