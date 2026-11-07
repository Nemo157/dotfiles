// Shared, session-scoped handle onto the pi-permission-system service, for
// extensions whose synchronous tool-execution paths have no session id in
// their ctx.
//
// The service lives in a process-global map keyed by session id (behind
// Symbol.for("@gotgenes/pi-permission-system:session-services"), surfaced via
// the package's getPermissionsService(sessionId)). We resolve the active
// node's service at session_start / permissions:ready and cache the reference
// so tool code can query the gates without threading the session id through
// every call. Each extension gets its own module copy (jiti isolates module
// state per extension), so a node-local cached reference is fine.
//
// Value-importing the package — rather than reaching into globalThis by
// Symbol.for directly — keeps this in lockstep with the real API: a signature,
// export, or accessor change now fails the typecheck (see typecheck.nix) and
// breaks loudly at load instead of silently rendering the permission helpers
// inert. The package deliberately routes its shareable state through
// Symbol.for()/globalThis, so loading a second copy here is safe and supported.
import { getPermissionsService } from "@gotgenes/pi-permission-system";
import type {
  PermissionsReadyEvent,
  PermissionsService,
} from "@gotgenes/pi-permission-system";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

let current: PermissionsService | undefined;

/** The cached permission service for the most recent session, or undefined. */
export function getService(): PermissionsService | undefined {
  return current;
}

function bind(sessionId: string | null | undefined): void {
  if (typeof sessionId !== "string") {
    current = undefined;
    return;
  }
  current = getPermissionsService(sessionId);
}

/**
 * Keep the cached reference pointing at the active node's service. Call once
 * per extension (from the factory) before any tool that queries the gates.
 * `session_shutdown` clears the reference so a torn-down node never serves a
 * stale service.
 */
export function bindCurrentSession(pi: ExtensionAPI): void {
  pi.events.on("permissions:ready", (raw) => {
    // Broadcast payloads carry no protocolVersion; read defensively.
    bind((raw as Partial<PermissionsReadyEvent>).sessionId);
  });
  pi.on("session_start", (_event, ctx) => {
    bind(ctx.sessionManager.getSessionId());
  });
  pi.on("session_shutdown", () => bind(undefined));
}
