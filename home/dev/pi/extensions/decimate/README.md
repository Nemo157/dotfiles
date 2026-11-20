# pi-decimate

LLM-free context shrinking, meant for sends that hit a **cold prompt cache**
(where rewriting history costs nothing extra).

Old tool results are replaced via append-only `context_edit` entries — raw
history is untouched and `/decimate restore` brings content back. v1 never
omits messages, so tool calls always keep their paired results.

**Side effect on thinking (Anthropic):** signed thinking blocks are bound to
the conversation before them. Editing a tool result makes every later
thinking block fail that check, and the API drops them from the prompt
(`thinking_dropped` input transformation; it may instead keep them where
the check isn't enforced). So a decimation also discards the model's
reasoning from the earliest edit onwards: more tokens saved than the plan
estimates (one session: −33.8k measured results, −44k billed, the rest its
11k of earlier reasoning), but lost continuity. The earlier the first edit,
the more reasoning goes with it.

## Pipeline

1. **Heuristics** (`candidates.ts`) score old tool results outside the last
   `keepRecentTurns` user turns. The turn being sent counts as one of them,
   so the default 2 protects the last completed turn; plans made ahead of the
   send (precompute, resume, `/decimate apply`) count the upcoming turn too.
   A session with a single completed turn has nothing eligible:
   - `superseded-read` — file re-read later covering the same lines, or
     modified later (prior 0.85–0.95)
   - `failed-retry` — error result whose retry (same tool and `path`)
     succeeded (0.85)
   - `stale-bulky` — ≥ `bulkyChars` or images, grows with age (0.45–0.8)
   - `stale` — any other result ≥ `minChars` (0.3): below
     `heuristicThreshold`, so only the classifier can remove it
2. **Decision model** (`classify.ts`, optional) — candidates below
   `autoAcceptPrior` are scored by a pi classifier model: `needed` (bool),
   `action` (keep/trim/stub, with confidence). `p(needed) ≥ tauKeep` keeps;
   otherwise a stub/trim choice with confidence `≥ tauAction` is taken,
   anything else stubs at `p(needed) ≤ tauStub` and trims above. The model sees each candidate with an outline of
   the conversation (every user request and the agent's closing reply,
   clipped to a budget). Verdicts are cached per
   entry + task-context hash. In **shadow** mode the model scores and is
   logged, heuristics decide.
3. **Plan** (`plan.ts`) — stub (one line) or trim (head + tail).
4. **Apply** — staged, applied in-memory by the `context` hook to the next
   request, persisted at that turn's `turn_end` together with a `decimate`
   ledger entry. The ledger entry renders in the transcript as one line
   (tokens saved, edit count, cache verdict); expand it for the per-edit
   list. It is never sent to the model.

## Staging records

Staging is persisted immediately as a `staged` ledger entry (the full plan,
or for restores the decimations to undo). The session is append-only, so a
staged plan stays open only while it is the branch's latest `decimate`
entry; the next one closes it: the `applied`/`restored` record of its send,
a `dropped` record (`/decimate cancel`, cache warm at send time, targets no
longer in context), or a newer `staged` plan replacing it (`supersedes`).
Only the open staged entry renders in the transcript; closed ones and drops
are hidden. When a branch is loaded (startup, resume, `/tree`) its open
staged plan is re-staged, so closing the session before the next prompt
doesn't lose it; in auto mode this also stops each resume recording a new
plan. Staging, `restore` and `cancel` require an idle agent.

## Cachemire integration

- **Gate** (`coldness.ts`): reads `globalThis.__piCachemire` (window,
  `lastRefreshedAt`, compaction/model-switch flags) → `cold` / `warm` /
  `unknown`. Only trusted in a UI session that owns cachemire's state
  (`__piCachemireOwner`); otherwise (no cachemire, print/RPC, in-process
  subagents): Anthropic TTL estimate or >24h idle.
  - manual: warm refuses (unless `--force`), unknown asks, cold applies
  - auto: only `cold`
- **Token counts** (`candidates.ts`): a tool result's size is *measured*
  where billed usage allows, as pi-contextimate does: between two replies of
  the same model with only tool results in between, whose later cache read
  proves the earlier prompt was reused, the prompt growth minus the replayed
  reply is exactly those results (split by size across parallel calls).
  Everything else is estimated at a chars/token ratio calibrated per plan
  from the latest billed prompt on the branch (input + cache read + cache
  write vs. the chars of system prompt, tools and preceding messages),
  preferring a reply from the current model; 4 when there is none. Code-heavy
  sessions often land near 2, so a fixed 4 would halve every estimate.
  `/decimate preview` marks measured sizes `=` and estimates `~`.
- **Verification** (`ledger.ts`): the decimated send's billed `cacheRead` is
  compared with the estimated prefix before the first edit →
  `cold-confirmed` / `was-warm` / `inconclusive`.
- **Usefulness** (`/decimate stats`), derived from the branch: cold-send
  saving, cache-read savings on later calls, classifier cost, regret (later
  re-reads / identical re-runs of decimated results, restores), and
  classifier-vs-heuristic disagreement on regretted edits.

Note: cachemire will label the decimated send a `history rewritten` miss; on a
cold send the real cause is the TTL. A cachemire patch recognising decimation
is a possible follow-up.

## Auto mode

`/decimate auto on`: decimates on the first send of a run when the cache is
cold, on cold resume (plan precomputed at `session_start`), and precomputes a
plan when the cache clock predicts expiry (`precompute`). Inline
classification on an auto send is capped at `classifier.autoTimeoutMs`.

An auto plan saving less than `minGainTokens` is not staged. Its gain shows
in the status bar (`✂ auto (−3k < 8k)`, or `✂ auto (nothing eligible)` when
no result qualified) until the next run, and a `skipped` ledger entry
records it for `/decimate stats` (count, classifier spend) unless it had
neither edits nor classifier calls.
Skipped entries render in the transcript only when they cost classifier
calls, and never close an open staged plan. While a `skipped` entry is still
the branch's latest plan-relevant entry (only usage, labels, session info,
model/thinking changes or other extensions' custom entries after it) and
`minGainTokens`/`shadow` are unchanged, auto mode doesn't re-plan: the
result would be the same. `/decimate apply` always re-plans.

## Commands

`/decimate [apply] [--force]` · `preview` · `cancel` · `status` · `stats` ·
`restore [last|all]` · `auto [on|off]` · `shadow [on|off]`

## Config: `<agentDir>/extensions/decimate/config.json` (global only)

Set via `programs.pi.extensionSettings.decimate` in Nix.

```json
{
  "auto": false,
  "shadow": true,
  "keepRecentTurns": 2,
  "minGainTokens": 8000,
  "minChars": 400,
  "bulkyChars": 4000,
  "heuristicThreshold": 0.6,
  "precompute": true,
  "classifier": {
    "provider": "typesafe",
    "id": "jev-latest",
    "timeoutMs": 20000,
    "autoTimeoutMs": 4000,
    "maxCandidates": 40,
    "tauKeep": 0.75,
    "tauAction": 0.5,
    "tauStub": 0.35,
    "autoAcceptPrior": 0.9
  }
}
```

The extension never writes the config file, so it can be read-only (e.g.
Nix-managed). `auto`/`shadow` there are only defaults.

## State: `$XDG_STATE_HOME/pi/decimate/state.json`

Written by `/decimate auto|shadow on|off`; its toggles override the config
defaults. Delete it to fall back to the config.
