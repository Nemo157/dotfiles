// Session-scoped tri-state toggle for the built-in `edit` and `write` tools.
//
// Three states, cycled with `/edit-toggle` (or Ctrl+Alt+E):
//
//   ask    → transparent; normal `ask` prompts still surface as usual.
//            (default; this extension does nothing beyond showing the state)
//   allow  → auto-approve edit/write invocations for the rest of the session.
//   deny   → auto-deny edit/write invocations, and inject a per-turn note
//            (via the `context` event, not persisted) telling the model
//            those tools are disabled.
//
// How it works
// ------------
// pi-permission-system publishes a "live-authority chain" (ADR 0007) via
// PermissionsService.registerAuthorizer(name, authorize). Our link receives
// every request that would resolve to `ask` and returns allow / deny /
// defer based on the current toggle state. The link only activates when
// the operator names it in `authorizerChain` in the permission-system
// config — see ../../default.nix, which wires `authorizerChain =
// [ "edit-toggle" ]` alongside `edit = ask` / `write = ask`.
//
// The chain is only consulted for `ask`. That means:
//   - edit / write must be configured as `ask` in the permission config
//     for the toggle to have any effect. They already are.
//   - if a tool were configured `deny` in config, before_agent_start
//     would hide it from the model before the chain ever runs. Not the
//     case for us: `ask` keeps the tool exposed and we decide per call.
//
// Cache-friendly notification
// ---------------------------
// Instead of mutating the system prompt (which would invalidate every
// provider prefix cache), we append a transient tail user-role note in
// the `context` event whenever state === "deny". The note is only in the
// outgoing LLM payload — it is never stored in the session entries — so
// it disappears the moment the state flips back to ask/allow, and every
// earlier turn's bytes stay unchanged.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

type ToggleState = "ask" | "allow" | "deny";

// Tools this toggle governs. Matches the "edit tools" concept the user
// asked about. If new mutating built-in tools appear, add them here.
const TARGET_TOOLS = new Set(["edit", "write"]);

const NEXT_STATE: Record<ToggleState, ToggleState> = {
  ask: "allow",
  allow: "deny",
  deny: "ask",
};

// Tail note appended to the LLM payload whenever state === "deny". Not
// persisted; only added per-call via the `context` event handler below.
const DENY_NOTE =
  "[user] Edit tools (edit, write) are currently DISABLED for this session. " +
  "Do not attempt to call them; if a task requires file modifications, " +
  "describe what you would do and ask the user to re-enable them.";

// Symbol.for-backed accessor for the permission service (see
// pi-permission-system docs/cross-extension-api.md). Using the raw symbol
// keeps this extension free of any npm-package dependency — no local
// package.json / node_modules needed.
const SERVICE_KEY = Symbol.for("@gotgenes/pi-permission-system:service");

interface AuthorizerDetails {
  toolName?: string;
  // …other fields exist (surface, command, path, etc.) — not needed here.
}

type AuthorizerVerdict =
  | { kind: "allow" }
  | { kind: "deny"; reason?: string }
  | { kind: "defer" };

interface PermissionsService {
  registerAuthorizer(
    name: string,
    authorize: (
      details: AuthorizerDetails,
    ) => AuthorizerVerdict | Promise<AuthorizerVerdict>,
  ): () => void;
}

function getPermissionsService(): PermissionsService | undefined {
  return (globalThis as Record<symbol, unknown>)[SERVICE_KEY] as
    | PermissionsService
    | undefined;
}

function statusFor(state: ToggleState, ctx: ExtensionContext): string {
  const th = ctx.ui.theme;
  switch (state) {
    case "ask":
      return th.fg("muted", "edit: ask");
    case "allow":
      return th.fg("success", "edit: allow");
    case "deny":
      return th.fg("error", "edit: DENY");
  }
}

export default function editToggleExtension(pi: ExtensionAPI): void {
  let state: ToggleState = "ask";
  let dispose: (() => void) | undefined;

  function refreshStatus(ctx: ExtensionContext): void {
    ctx.ui.setStatus("edit-toggle", statusFor(state, ctx));
  }

  // Register (or re-register on /reload) our chain link. The permission
  // service publishes a fresh registry on every /reload, so re-registering
  // from the `permissions:ready` broadcast is the documented safe hook.
  function registerLink(): void {
    const permissions = getPermissionsService();
    if (!permissions) return;
    dispose?.();
    dispose = permissions.registerAuthorizer("edit-toggle", (details) => {
      const tool = details.toolName;
      if (!tool || !TARGET_TOOLS.has(tool)) return { kind: "defer" };
      if (state === "allow") return { kind: "allow" };
      if (state === "deny") {
        return {
          kind: "deny",
          reason:
            "Edit tools are disabled by the user (edit-toggle=deny). " +
            "Do not retry; wait for the user to re-enable them.",
        };
      }
      return { kind: "defer" };
    });
  }

  function setState(next: ToggleState, ctx: ExtensionContext): void {
    state = next;
    refreshStatus(ctx);
    ctx.ui.notify(`Edit policy: ${next}`, "info");
  }

  pi.events.on("permissions:ready", () => registerLink());

  pi.on("session_start", (_event, ctx) => {
    // Fallback in case load order put us before the permission service's
    // publish (permissions:ready would still fire, but this keeps a single
    // path for the initial status paint).
    registerLink();
    refreshStatus(ctx);
  });

  pi.on("session_shutdown", () => {
    dispose?.();
    dispose = undefined;
  });

  // Cache-friendly injection: append a transient tail note when state is
  // "deny". This runs on every `context` event (once per LLM call) but
  // the appended message is not stored in the session, so prior turns'
  // bytes stay identical and the provider prefix cache stays warm up to
  // the tail.
  pi.on("context", async (event) => {
    if (state !== "deny") return;
    return {
      messages: [
        ...event.messages,
        {
          role: "user",
          content: DENY_NOTE,
          timestamp: Date.now(),
        },
      ],
    };
  });

  pi.registerCommand("edit-toggle", {
    description:
      "Cycle edit-tool policy (ask → allow → deny), or pass ask|allow|deny to set directly",
    getArgumentCompletions: (prefix: string) =>
      (["ask", "allow", "deny"] as const)
        .filter((v) => v.startsWith(prefix))
        .map((v) => ({ value: v, label: v })),
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      if (trimmed === "ask" || trimmed === "allow" || trimmed === "deny") {
        setState(trimmed, ctx);
      } else if (trimmed.length === 0) {
        setState(NEXT_STATE[state], ctx);
      } else {
        ctx.ui.notify(
          `Unknown edit-toggle arg '${trimmed}'. Use ask|allow|deny.`,
          "error",
        );
      }
    },
  });

  pi.registerShortcut(Key.ctrlAlt("e"), {
    description: "Cycle edit-tool policy (ask → allow → deny)",
    handler: async (ctx) => setState(NEXT_STATE[state], ctx),
  });
}
