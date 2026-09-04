// Tell the agent today's date, and keep it correct across midnight.
//
// Models have no clock. Rather than baking the date into the system prompt
// (which is rebuilt every turn, so a rollover invalidates the whole cached
// prefix), we inject a persistent `<system-reminder>` message at the start
// of an assistant turn — but only when the date differs from the last one
// announced in this session's context. Same-day sessions therefore pay for
// exactly one message and every later turn's bytes stay unchanged, keeping
// the provider prefix cache warm.
//
// The announced date is stored on the reminder itself, in the custom
// message's `details` (persisted on the `custom_message` entry, never sent
// to the LLM). No separate `pi.appendEntry` record: `before_agent_start`
// runs before the user message is persisted, so such an entry would become
// the *parent* of the user message, and rewinding to a user message sets
// the leaf to `targetEntry.parentId` — landing on the record and
// suppressing re-injection after the reminder itself was rewound away.
// Keeping the record on the message makes the two inseparable. (See
// ../edit-toggle/index.ts, which hit exactly that bug.)
//
// The lookup uses `sessionManager.buildContextEntries()`, which follows the
// current branch and is compaction-aware, so it answers the actual question:
// does the model still see a date reminder, and which date did it state?
//
// Only the date is announced, never the time of day: the reminder is
// written once and would be stale within the turn.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const NOTE_MESSAGE = "current-date-note";

interface Today {
  date: string;
  text: string;
}

function today(): Today {
  const now = new Date();
  // Local-time ISO date; toISOString() would be UTC and can be a day off.
  const date = [
    now.getFullYear(),
    String(now.getMonth() + 1).padStart(2, "0"),
    String(now.getDate()).padStart(2, "0"),
  ].join("-");
  const weekday = now.toLocaleDateString("en-US", { weekday: "long" });
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  return { date, text: `${weekday}, ${date}${tz ? ` (${tz})` : ""}` };
}

// Date last announced to the agent, read off the reminder messages still in
// context, or undefined if this branch has none.
function lastAnnouncedDate(ctx: ExtensionContext): string | undefined {
  const last = ctx.sessionManager
    .buildContextEntries()
    .filter(
      (e: { type: string; customType?: string }) =>
        e.type === "custom_message" && e.customType === NOTE_MESSAGE,
    )
    .pop() as { details?: { date?: unknown } } | undefined;
  const date = last?.details?.date;
  return typeof date === "string" ? date : undefined;
}

export default function currentDateExtension(pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (_event, ctx) => {
    const { date, text } = today();
    if (lastAnnouncedDate(ctx) === date) return;

    return {
      message: {
        customType: NOTE_MESSAGE,
        content:
          `<system-reminder>Today's date is ${text}. This reminder is ` +
          `injected once per day; if the session runs past midnight a new ` +
          `one follows. Don't mention it unless the date is relevant.` +
          `</system-reminder>`,
        display: false,
        details: { date },
      },
    };
  });
}
