// Anthropic prompt-cache TTL countdown in the footer.
//
// Anthropic prompt caching keeps cache blocks alive for a bounded TTL after
// the last read/write:
//   - default cache blocks: 5 minutes
//   - extended-cache-ttl-2025-04-11 blocks: 1 hour (usage.cacheWrite1h)
//
// The API does not expose a literal "expires at" — we infer it. Any cache
// read or cache write refreshes the block, so we reset the timer on every
// assistant message that reports cacheRead > 0 or cacheWrite > 0. If the
// most recent write reported a cacheWrite1h portion we bump the assumed
// TTL to 1h; otherwise we assume 5m. Reads inherit the last known TTL
// bucket (there's no way to distinguish which bucket a read hit).
//
// Only runs while the active model is an Anthropic model. On any other
// provider the footer entry is cleared.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const TTL_5M_MS = 5 * 60 * 1000;
const TTL_1H_MS = 60 * 60 * 1000;
const TICK_MS = 1000;
const STATUS_KEY = "cache-ttl";

function isAnthropic(ctx: ExtensionContext): boolean {
  return ctx.model?.provider === "anthropic";
}

function formatRemaining(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}h${String(m).padStart(2, "0")}m`;
  return `${m}m${String(sec).padStart(2, "0")}s`;
}

export default function cacheTtlExtension(pi: ExtensionAPI): void {
  // Timestamp (ms) of the last cache read/write we observed. null means no
  // cache primed yet in this session.
  let lastCacheAt: number | null = null;
  // Assumed TTL bucket for the tracked cache block. Reset on writes; reads
  // inherit whatever was set previously.
  let ttlMs = TTL_5M_MS;
  let timer: ReturnType<typeof setInterval> | undefined;

  function paint(ctx: ExtensionContext): void {
    if (!isAnthropic(ctx)) {
      ctx.ui.setStatus(STATUS_KEY, "");
      return;
    }
    if (lastCacheAt == null) {
      ctx.ui.setStatus(STATUS_KEY, "");
      return;
    }
    const th = ctx.ui.theme;
    const remaining = lastCacheAt + ttlMs - Date.now();
    if (remaining <= 0) {
      ctx.ui.setStatus(STATUS_KEY, th.fg("error", "cache: expired"));
      return;
    }
    // Warn (error color) in the last 30s so it's visible before it flips.
    const color = remaining <= 30_000 ? "error" : "muted";
    ctx.ui.setStatus(STATUS_KEY, th.fg(color, `cache: ${formatRemaining(remaining)}`));
  }

  function startTicker(ctx: ExtensionContext): void {
    if (timer) return;
    timer = setInterval(() => paint(ctx), TICK_MS);
    // Node's setInterval returns a Timer with unref() in Node runtimes; guard
    // in case the harness uses a shim without it.
    (timer as unknown as { unref?: () => void }).unref?.();
  }

  function stopTicker(): void {
    if (timer) {
      clearInterval(timer);
      timer = undefined;
    }
  }

  pi.on("session_start", (_event, ctx) => {
    startTicker(ctx);
    paint(ctx);
  });

  pi.on("session_shutdown", () => {
    stopTicker();
  });

  pi.on("model_select", (_event, ctx) => {
    // Provider may have changed. Reset tracked state — a fresh Anthropic
    // session hasn't primed a cache yet, and non-Anthropic providers must
    // not display a stale countdown.
    lastCacheAt = null;
    ttlMs = TTL_5M_MS;
    paint(ctx);
  });

  pi.on("message_end", (event, ctx) => {
    if (!isAnthropic(ctx)) return;
    if (event.message.role !== "assistant") return;

    const usage = event.message.usage;
    if (!usage) return;

    const cacheWrite = usage.cacheWrite ?? 0;
    const cacheWrite1h = usage.cacheWrite1h ?? 0;
    const cacheRead = usage.cacheRead ?? 0;

    if (cacheWrite > 0) {
      // A cache block was (re)written this turn. If any portion used 1h
      // retention, upgrade the bucket; otherwise reset to 5m.
      ttlMs = cacheWrite1h > 0 ? TTL_1H_MS : TTL_5M_MS;
      lastCacheAt = Date.now();
    } else if (cacheRead > 0) {
      // A read refreshes the existing block's TTL for its own bucket.
      lastCacheAt = Date.now();
    }

    paint(ctx);
  });
}
