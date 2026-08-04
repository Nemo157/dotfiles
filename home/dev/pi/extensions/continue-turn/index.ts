// Resume the assistant from the current point in the transcript, without
// adding a "continue" user message.
//
// Motivation
// ----------
// After Esc (`app.interrupt`) the agent stops but the transcript is intact:
// the aborted assistant message is there and every pending tool call got an
// "Operation aborted" tool result. The only built-in way to get the model
// going again is to send another user message, which pollutes the context.
//
// `/continue` (or Ctrl+Alt+C) triggers a fresh LLM call over exactly the
// existing transcript instead.
//
// How it works
// ------------
// pi has no "run a turn with no new message" API — but it does have
//
//   1. `pi.sendMessage(..., { triggerTurn: true })`, which appends a custom
//      message and starts a turn, and
//   2. the `context` event, which can drop messages before each LLM call.
//
// So we inject an empty, non-displayed custom message purely as a turn
// trigger and strip it again in `context`. The provider therefore sees the
// unmodified transcript, as if the interrupted turn had simply continued.
//
// Caveat
// ------
// This only makes sense when the transcript ends in something a model can
// continue from — in practice a tool result (i.e. the interruption happened
// at/after a tool call). If the last message is an assistant message, most
// providers either reject the request or treat it as a prefill, so we refuse
// and say so instead.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

// customType of the throwaway trigger message. Never reaches the LLM.
const TRIGGER_TYPE = "continue-turn-trigger";

type MessageLike = { role?: string };

function lastContextMessage(ctx: ExtensionContext): MessageLike | undefined {
  const entries = ctx.sessionManager.buildContextEntries() as Array<{
    type: string;
    message?: MessageLike;
    customType?: string;
  }>;
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i];
    if (entry.type === "message" && entry.message) return entry.message;
    if (entry.type === "custom_message" && entry.customType !== TRIGGER_TYPE) {
      return { role: "custom" };
    }
  }
  return undefined;
}

async function continueTurn(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
): Promise<void> {
  if (!ctx.isIdle()) {
    ctx.ui.notify("Agent is already running; nothing to continue.", "warning");
    return;
  }

  const last = lastContextMessage(ctx);
  if (!last) {
    ctx.ui.notify("Nothing to continue from — the context is empty.", "error");
    return;
  }
  if (last.role === "assistant") {
    ctx.ui.notify(
      "Transcript ends with an assistant message; there is nothing for the " +
        "model to continue from. Send a message instead.",
      "error",
    );
    return;
  }

  // Empty + display:false: invisible in the TUI, and stripped from the LLM
  // context by the `context` handler below. Its only job is to start a turn.
  pi.sendMessage(
    { customType: TRIGGER_TYPE, content: [], display: false },
    { triggerTurn: true },
  );
}

export default function continueTurnExtension(pi: ExtensionAPI): void {
  // Never let the trigger message reach the provider.
  pi.on("context", (event) => {
    const messages = event.messages.filter(
      (m: { role?: string; customType?: string }) =>
        !(m.role === "custom" && m.customType === TRIGGER_TYPE),
    );
    return { messages };
  });

  pi.registerCommand("continue", {
    description:
      "Resume the assistant from the current transcript (no user message)",
    handler: async (_args, ctx) => continueTurn(pi, ctx),
  });

  pi.registerShortcut(Key.ctrlAlt("c"), {
    description: "Resume the assistant from the current transcript",
    handler: async (ctx) => continueTurn(pi, ctx),
  });
}
