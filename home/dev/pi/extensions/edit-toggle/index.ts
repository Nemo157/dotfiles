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
// Cache-friendly notification
// ---------------------------
// Rather than re-injecting a note on every LLM call, we inject a single
// persistent message at the start of an assistant turn (via
// `before_agent_start`) only when the edit capability has flipped between
// allowed (ask/allow) and denied (deny) since the last note the agent
// actually saw. Because the note is injected once per transition (not per
// call), earlier turns' bytes stay unchanged and the provider prefix cache
// stays warm.
//
// State persistence
// -----------------
// The state that the note announced is stored *on the note itself*, in the
// custom message's `details` (persisted on the `custom_message` entry and
// never sent to the LLM). This matters for rewinds: pi appends the note as
// a child of the user message, so navigating back drops note and record
// together, and the next turn re-announces.
//
// A separate `pi.appendEntry` record would NOT survive that correctly.
// `before_agent_start` runs before the user message is persisted (it is
// only written on `message_end`), so an entry appended there becomes the
// *parent* of the user message — and rewinding to a user message sets the
// leaf to `targetEntry.parentId`, i.e. lands exactly on that entry. The
// record would then outlive the note it belongs to and suppress
// re-injection. So `appendEntry` is used only for silent ask↔allow changes
// (no note to attach to, and no bearing on whether a note is due).
//
// Both records are always re-read from the current *context* entries
// (`sessionManager.buildContextEntries()`) rather than cached in a
// variable or read from `getEntries()` (which returns every entry, from
// all branches). Sessions branch — the user can go back to an earlier
// message and take a different path — and a branch that forked before the
// note must be treated as not having it. `buildContextEntries()` is also
// compaction-aware (unlike `getBranch()`, which walks the raw parent chain
// and would still report notes the model can no longer see), which is
// exactly the question being asked here.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

type ToggleState = "ask" | "allow" | "deny";

// Tools this toggle governs. Covers the built-in edit/write tools, the
// filesystem-mutation tools registered by the `file-tools` extension, and
// the repo-mutating jj tools from `cli-tools` (all recoverable via the jj
// oplog), so flipping to "deny" locks down all file and repo changes. If
// new mutating tools appear, add them here.
const TARGET_TOOLS = new Set([
  "edit",
  "write",
  "mv",
  "rm",
  "cp",
  "mkdir",
  "cut-lines",
  "paste-lines",
  "jj-describe",
  "jj-commit",
  "jj-new",
  "jj-squash",
  "jj-restore",
  "jj-rebase",
]);

const NEXT_STATE: Record<ToggleState, ToggleState> = {
  ask: "allow",
  allow: "deny",
  deny: "ask",
};

// Persistent notes injected once, at turn start, when the edit capability
// flips. See `before_agent_start` below.
const DENY_NOTE =
  "<system-reminder>Editing (edit, write, the mv/rm/cp/mkdir/" +
  "cut-lines/paste-lines file tools, and the jj describe/commit/new/" +
  "squash/restore/rebase tools) is disabled, so the user likely " +
  "wants to plan or discuss rather than change files. Don't call these " +
  "tools; describe what you would do instead. The user knows editing is " +
  "off, so don't ask them to re-enable it — unless they clearly expect you " +
  "to be editing, in which case note that it's disabled.</system-reminder>";

const ENABLE_NOTE =
  "<system-reminder>Editing (edit, write, the mv/rm/cp/mkdir/" +
  "cut-lines/paste-lines file tools, and the jj describe/commit/new/" +
  "squash/restore/rebase tools) is enabled again; use these tools as needed.</system-reminder>";

// customType for the injected note message (carries the announced state in
// its `details`) and for the silent state-only entry.
const NOTE_MESSAGE = "edit-toggle-note";
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
  let dispose: (() => void) | undefined;

  function asState(value: unknown): ToggleState | undefined {
    return value === "ask" || value === "allow" || value === "deny"
      ? value
      : undefined;
  }

  // State the agent was last *told* about, read off the note messages still
  // in context, or undefined if it has not been told anything on this
  // branch (in which case it assumes the allowed state).
  function lastAnnouncedState(ctx: ExtensionContext): ToggleState | undefined {
    const last = ctx.sessionManager
      .buildContextEntries()
      .filter(
        (e: { type: string; customType?: string }) =>
          e.type === "custom_message" && e.customType === NOTE_MESSAGE,
      )
      .pop() as { details?: { state?: unknown } } | undefined;
    return asState(last?.details?.state);
  }

  // Last state recorded in context by either mechanism (note message or
  // silent state entry), whichever comes last, or "ask" if neither is
  // present. Used to restore the policy on session_start and to decide
  // whether a silent record is still needed.
  function lastRecordedState(ctx: ExtensionContext): ToggleState {
    const last = ctx.sessionManager
      .buildContextEntries()
      .filter(
        (e: { type: string; customType?: string }) =>
          (e.type === "custom" && e.customType === STATE_ENTRY) ||
          (e.type === "custom_message" && e.customType === NOTE_MESSAGE),
      )
      .pop() as
      | { data?: { state?: unknown }; details?: { state?: unknown } }
      | undefined;
    return asState(last?.details?.state ?? last?.data?.state) ?? "ask";
  }

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
    state = lastRecordedState(ctx);

    refreshStatus(ctx);
  });

  pi.on("session_shutdown", () => {
    dispose?.();
    dispose = undefined;
  });

  // At the start of each assistant turn: if the allowed/denied category
  // flipped since the last note the agent saw, inject a fresh note carrying
  // the new state in its `details`. Otherwise, if the exact state changed
  // since the last record, persist it silently so /reload and resume can
  // restore it.
  pi.on("before_agent_start", async (_event, ctx) => {
    const current = state;

    // No note on this branch yet ⇒ the agent assumes the allowed state.
    const announced = lastAnnouncedState(ctx) ?? "ask";
    if (isAllowed(current) !== isAllowed(announced)) {
      return {
        message: {
          customType: NOTE_MESSAGE,
          content: isAllowed(current) ? ENABLE_NOTE : DENY_NOTE,
          display: false,
          details: { state: current },
        },
      };
    }

    if (current !== lastRecordedState(ctx)) {
      pi.appendEntry(STATE_ENTRY, { state: current });
    }
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
