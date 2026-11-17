// "Is the prompt cache cold right now?" — the gate for free decimation.
//
// Primary source: pi-cachemire's process-global state (globalThis.__piCachemire,
// pine-of-glass 0.18.x). Read-only and shape-checked: if cachemire is absent or
// its shape drifts, fall back to a conservative estimate from the branch.
//
// The global is created with defaults as soon as cachemire loads, but only a
// UI session claims it (`__piCachemireOwner`) and keeps it updated. Without an
// owner, or in a non-UI session (print/RPC, in-process subagents), it is
// either untouched defaults ("no billed call yet" → falsely cold) or another
// session's clock, so it is ignored there.

import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export type ColdState = "cold" | "warm" | "unknown";

export interface Coldness {
  state: ColdState;
  reason: string;
  source: "cachemire" | "fallback";
  /** When the cache is predicted to become provably cold (warm states only). */
  coldAt?: number;
  /** Last provider-known prompt size (what a warm decimation would re-write). */
  expectedRead?: number;
}

type CacheWindow =
  | { kind: "contract"; ttlMs: number; graceMs?: number }
  | { kind: "minimum"; minMs: number }
  | { kind: "maximum"; maxMs: number }
  | { kind: "bounded"; minMs: number; maxMs: number }
  | { kind: "unknown" };

interface CachemireView {
  window: CacheWindow;
  lastRefreshedAt?: number;
  compacted: boolean;
  inCompaction: boolean;
  modelSwitched: boolean;
  expectedRead: number;
}

function cachemireView(ctx: ExtensionContext): CachemireView | undefined {
  const g = globalThis as {
    __piCachemire?: unknown;
    __piCachemireOwner?: unknown;
  };
  if (!ctx.hasUI || g.__piCachemireOwner === undefined) return undefined;
  const s = g.__piCachemire;
  if (!s || typeof s !== "object") return undefined;
  const r = s as Record<string, unknown>;
  const w = r.window as { kind?: unknown } | undefined;
  if (!w || typeof w.kind !== "string") return undefined;
  if (typeof r.compacted !== "boolean" || typeof r.modelSwitched !== "boolean")
    return undefined;
  return {
    window: w as CacheWindow,
    lastRefreshedAt:
      typeof r.lastRefreshedAt === "number" ? r.lastRefreshedAt : undefined,
    compacted: r.compacted,
    inCompaction: r.inCompaction === true,
    modelSwitched: r.modelSwitched,
    expectedRead: typeof r.expectedRead === "number" ? r.expectedRead : 0,
  };
}

function fmt(ms: number): string {
  const s = Math.round(ms / 1000);
  if (s < 90) return `${s}s`;
  const m = Math.round(s / 60);
  if (m < 90) return `${m}m`;
  return `${(m / 60).toFixed(1)}h`;
}

export function cacheColdness(
  ctx: ExtensionContext,
  now = Date.now(),
): Coldness {
  const v = cachemireView(ctx);
  if (v) return fromCachemire(v, now);
  return fallback(ctx, now);
}

function fromCachemire(v: CachemireView, now: number): Coldness {
  const base = { source: "cachemire" as const, expectedRead: v.expectedRead };
  if (v.inCompaction)
    return { ...base, state: "unknown", reason: "compaction in progress" };
  if (v.lastRefreshedAt === undefined)
    return {
      ...base,
      state: "cold",
      reason: "no billed call on this branch yet",
    };
  if (v.compacted)
    return {
      ...base,
      state: "cold",
      reason: "history compacted since the last call",
    };
  // A switch-back can still hit the old model's entry; cachemire itself only claims "may be warm".
  if (v.modelSwitched)
    return {
      ...base,
      state: "unknown",
      reason: "model switched since the last call",
    };

  const since = now - v.lastRefreshedAt;
  const ago = `${fmt(since)} since last refresh`;
  const w = v.window;
  switch (w.kind) {
    case "contract": {
      const expiry = w.ttlMs + (w.graceMs ?? 0);
      return since >= expiry
        ? {
            ...base,
            state: "cold",
            reason: `${fmt(w.ttlMs)} TTL expired (${ago})`,
          }
        : {
            ...base,
            state: "warm",
            reason: `${fmt(w.ttlMs)} TTL, ${fmt(expiry - since)} left`,
            coldAt: v.lastRefreshedAt + expiry,
          };
    }
    case "minimum":
      return since < w.minMs
        ? {
            ...base,
            state: "warm",
            reason: `within ${fmt(w.minMs)} retention minimum (${ago})`,
          }
        : {
            ...base,
            state: "unknown",
            reason: `past ${fmt(w.minMs)} retention minimum; provider may still hold it`,
          };
    case "maximum":
      return since >= w.maxMs
        ? {
            ...base,
            state: "cold",
            reason: `${fmt(w.maxMs)} retention maximum reached`,
          }
        : {
            ...base,
            state: "unknown",
            reason: `below ${fmt(w.maxMs)} retention maximum (${ago})`,
            coldAt: v.lastRefreshedAt + w.maxMs,
          };
    case "bounded":
      if (since < w.minMs) {
        return {
          ...base,
          state: "warm",
          reason: `within ${fmt(w.minMs)} retention minimum`,
          coldAt: v.lastRefreshedAt + w.maxMs,
        };
      }
      return since >= w.maxMs
        ? {
            ...base,
            state: "cold",
            reason: `${fmt(w.maxMs)} retention maximum reached`,
          }
        : {
            ...base,
            state: "unknown",
            reason: `between ${fmt(w.minMs)} minimum and ${fmt(w.maxMs)} maximum`,
            coldAt: v.lastRefreshedAt + w.maxMs,
          };
    default:
      return {
        ...base,
        state: "unknown",
        reason: "retention unknown for this route",
      };
  }
}

const LONGEST_KNOWN_RETENTION_MS = 24 * 3_600_000;

/** Without cachemire: last refresh from the branch, TTL only for direct Anthropic. */
function fallback(ctx: ExtensionContext, now: number): Coldness {
  let last: { at: number; api?: string } | undefined;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "usage" && entry.kind === "cache_warm") {
      last = { at: Date.parse(entry.timestamp), api: last?.api };
    } else if (entry.type === "message") {
      const m = entry.message as {
        role?: string;
        timestamp?: number;
        api?: string;
        usage?: { cacheRead?: number; cacheWrite?: number };
      };
      if (
        m.role === "assistant" &&
        m.usage &&
        ((m.usage.cacheRead ?? 0) > 0 || (m.usage.cacheWrite ?? 0) > 0)
      ) {
        last = { at: m.timestamp ?? Date.parse(entry.timestamp), api: m.api };
      }
    }
  }
  if (!last)
    return {
      state: "cold",
      reason: "no cached call on this branch",
      source: "fallback",
    };
  const since = now - last.at;
  if (since >= LONGEST_KNOWN_RETENTION_MS) {
    return {
      state: "cold",
      reason: `${fmt(since)} idle, past any known retention`,
      source: "fallback",
    };
  }
  if (last.api === "anthropic-messages") {
    const ttl = process.env.PI_CACHE_RETENTION === "long" ? 3_600_000 : 300_000;
    const expiry = ttl + 10_000;
    return since >= expiry
      ? {
          state: "cold",
          reason: `${fmt(ttl)} TTL expired (est., no cachemire)`,
          source: "fallback",
        }
      : {
          state: "warm",
          reason: `${fmt(ttl)} TTL, ${fmt(expiry - since)} left (est.)`,
          source: "fallback",
          coldAt: last.at + expiry,
        };
  }
  return {
    state: "unknown",
    reason: "cachemire not loaded; retention unknown",
    source: "fallback",
  };
}
