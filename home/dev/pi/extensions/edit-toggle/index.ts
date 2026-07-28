// Session-scoped tri-state toggle for the built-in `edit` and `write` tools.
//
// Three states, cycled with `/edit-toggle` (or Ctrl+Alt+E):
//
//   ask    → transparent; normal `ask` prompts still surface as usual.
//            (default; this extension does nothing beyond showing the state)
//   allow  → auto-approve edit/write invocations for the rest of the session.
//   deny   → auto-deny edit/write invocations.
//
// "allowed" means ask/allow; "denied" means deny. Before the first turn
// the agent is assumed to be in the allowed state.
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
// State persistence
// -----------------
// The toggle state is recorded to the session with `pi.appendEntry` at
// the start of an assistant turn (`before_agent_start`) whenever it
// differs from the last recorded state, and restored on `session_start`.
// This lets the policy survive /reload and session resume without writing
// an entry on every keypress.
//
// Cache-friendly notification
// ---------------------------
// Rather than re-injecting a note on every LLM call, we inject a single
// persistent message at the start of an assistant turn (via
// `before_agent_start`) only when the edit capability has flipped between
// allowed (ask/allow) and denied (deny) since the previously recorded
// state. The previous "allowed vs denied" category is derived from that
// last persisted state — no separate flag is stored. Because the note is
// injected once per transition (not per call), earlier turns' bytes stay
// unchanged and the provider prefix cache stays warm.

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

// Persistent notes injected once, at turn start, when the edit capability
// flips. See `before_agent_start` below.
const DENY_NOTE =
  "<system-reminder>Editing (edit, write) is disabled, so the user likely " +
  "wants to plan or discuss rather than change files. Don't call these " +
  "tools; describe what you would do instead. The user knows editing is " +
  "off, so don't ask them to re-enable it — unless they clearly expect you " +
  "to be editing, in which case note that it's disabled.</system-reminder>";

const ENABLE_NOTE =
  "<system-reminder>Editing (edit, write) is enabled again; use these tools " +
  "as needed.</system-reminder>";

// customType used for the persisted state entry.
const STATE_ENTRY = "edit-toggle";

// allowed = ask/allow; denied = deny.
function isAllowed(s: ToggleState): boolean {
  return s !== "deny";
}

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
  // State as of the last agent turn start (mirrors the last persisted
  // entry). Defaults to "ask" — i.e. allowed — before the first turn.
  let lastTurnState: ToggleState = "ask";
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

    // Restore the last persisted state (recorded at a previous turn start).
    const entries = ctx.sessionManager.getEntries();
    const last = entries
      .filter(
        (e: { type: string; customType?: string }) =>
          e.type === "custom" && e.customType === STATE_ENTRY,
      )
      .pop() as { data?: { state?: ToggleState } } | undefined;
    const restored = last?.data?.state;
    if (restored === "ask" || restored === "allow" || restored === "deny") {
      state = restored;
      lastTurnState = restored;
    }

    refreshStatus(ctx);
  });

  pi.on("session_shutdown", () => {
    dispose?.();
    dispose = undefined;
  });

  // At the start of each assistant turn, record the current state if it
  // changed since the last turn, and — if the allowed/denied category
  // flipped — inject a single persistent message telling the agent.
  pi.on("before_agent_start", async () => {
    const current = state;
    if (current === lastTurnState) return;

    const flipped = isAllowed(current) !== isAllowed(lastTurnState);
    lastTurnState = current;
    pi.appendEntry(STATE_ENTRY, { state: current });

    if (!flipped) return;
    return {
      message: {
        customType: "edit-toggle-note",
        content: isAllowed(current) ? ENABLE_NOTE : DENY_NOTE,
        display: false,
      },
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
