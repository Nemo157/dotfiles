// Decision-model scoring of candidates via pi's classifier models
// (`ctx.modelRegistry.classify()`): one call per candidate, three typed
// questions, hard batch deadline, verdicts cached per (entry, task context).

import { createHash } from "node:crypto";
import type {
  ClassifierApi,
  ClassifierModel,
  ClassifierQuestion,
  JsonObject,
} from "@earendil-works/pi-ai";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Candidate, TaskContext } from "./candidates";
import type { ClassifierConfig } from "./config";

export type ModelAction = "keep" | "trim" | "stub";

export interface Verdict {
  /** Probability the exact content is still needed. */
  pNeeded: number;
  action: ModelAction;
  actionConfidence: number;
  /** Probability the proposed stub preserves everything still needed. */
  pStubOk: number;
}

export interface ClassifyUsage {
  model: string;
  calls: number;
  cached: number;
  errors: number;
  skipped: number;
  timedOut: boolean;
  inputTokens: number;
  costUsd: number;
  ms: number;
}

const QUESTIONS: Record<string, ClassifierQuestion> = {
  needed: {
    type: "bool",
    instructions:
      "A coding agent's conversation is being shortened to save context. `candidate` is an old tool result " +
      "from that conversation; `task` is what the agent is working on now; `laterInSession` says what happened " +
      "to the same file afterwards. Will the agent still need the exact content of this tool result to finish " +
      "its current task — would losing it force the agent to redo work or risk a mistake?",
    criteria: {
      true: "The exact content is still needed for the current task",
      false:
        "The content is no longer needed verbatim (obsolete, superseded, or cheap to fetch again)",
    },
  },
  action: {
    type: "choice",
    instructions:
      "Choose what to do with this old tool result to shorten the conversation without hurting the current task.",
    criteria: {
      keep: "Keep it in full: it holds information the current task depends on that is not available elsewhere",
      trim: "Keep only its beginning and end: the gist still matters, the middle does not",
      stub: "Replace it with the one-line `proposedStub`: it is superseded, obsolete, or cheap to re-fetch",
    },
  },
  stubOk: {
    type: "bool",
    instructions:
      "Does `proposedStub` preserve everything about this tool result that the agent still needs for its current task?",
    criteria: {
      true: "Yes, the stub is enough",
      false: "No, the stub loses something the agent still needs",
    },
  },
};

function headTail(text: string, max: number): string {
  if (text.length <= max) return text;
  const head = Math.floor(max * 0.65);
  const tail = max - head;
  return `${text.slice(0, head)}\n… [${text.length - max} chars elided] …\n${text.slice(-tail)}`;
}

export function taskHash(task: TaskContext): string {
  return createHash("sha1")
    .update(JSON.stringify(task))
    .digest("hex")
    .slice(0, 12);
}

function stateFor(c: Candidate, task: TaskContext, stub: string): JsonObject {
  return {
    task: {
      recentUserRequests: task.recentUserRequests,
      recentlyModifiedFiles: task.recentlyModifiedFiles,
    },
    candidate: {
      tool: c.toolName,
      arguments: c.argsSummary,
      isError: c.isError,
      sizeChars: c.chars,
      images: c.images,
      ageInUserTurns: c.age,
      content: headTail(c.text, 3_000),
    },
    laterInSession: {
      sameFileReadAgain: c.later.rereads,
      sameFileModified: c.later.edits,
      mentionedLater: c.later.mentioned,
    },
    proposedStub: stub,
  };
}

export function resolveClassifier(
  ctx: ExtensionContext,
  cfg: ClassifierConfig,
): ClassifierModel<ClassifierApi> | undefined {
  return ctx.modelRegistry.getModelOfType("classifier", cfg.provider, cfg.id);
}

export async function classifyCandidates(
  ctx: ExtensionContext,
  model: ClassifierModel<ClassifierApi>,
  candidates: Candidate[],
  task: TaskContext,
  stubFor: (c: Candidate) => string,
  opts: {
    timeoutMs: number;
    maxCandidates: number;
    cache: Map<string, Verdict>;
  },
): Promise<{ verdicts: Map<string, Verdict>; usage: ClassifyUsage }> {
  const started = Date.now();
  const th = taskHash(task);
  const verdicts = new Map<string, Verdict>();
  const usage: ClassifyUsage = {
    model: `${model.provider}/${model.id}`,
    calls: 0,
    cached: 0,
    errors: 0,
    skipped: 0,
    timedOut: false,
    inputTokens: 0,
    costUsd: 0,
    ms: 0,
  };

  // Largest first: that's where a wrong call costs the most either way.
  const ordered = [...candidates].sort((a, b) => b.estTokens - a.estTokens);
  const queue = ordered.slice(0, opts.maxCandidates);
  usage.skipped = ordered.length - queue.length;

  const controller = new AbortController();
  const timer = setTimeout(() => {
    usage.timedOut = true;
    controller.abort();
  }, opts.timeoutMs);

  const worker = async (): Promise<void> => {
    for (let c = queue.shift(); c; c = queue.shift()) {
      if (controller.signal.aborted) {
        usage.skipped++;
        continue;
      }
      const key = `${c.entryId}:${th}`;
      const hit = opts.cache.get(key);
      if (hit) {
        verdicts.set(c.entryId, hit);
        usage.cached++;
        continue;
      }
      usage.calls++;
      const result = await ctx.modelRegistry.classify(
        model,
        { state: stateFor(c, task, stubFor(c)), questions: QUESTIONS },
        { signal: controller.signal },
      );
      usage.inputTokens += result.usage?.input ?? 0;
      usage.costUsd += result.usage?.cost.total ?? 0;
      if (result.stopReason !== "stop") {
        usage.errors++;
        continue;
      }
      const needed = result.answers.needed;
      const action = result.answers.action;
      const stubOk = result.answers.stubOk;
      if (
        needed?.type !== "bool" ||
        action?.type !== "choice" ||
        stubOk?.type !== "bool"
      ) {
        usage.errors++;
        continue;
      }
      const choice: ModelAction =
        action.choice === "keep" ||
        action.choice === "trim" ||
        action.choice === "stub"
          ? action.choice
          : "keep";
      const verdict: Verdict = {
        pNeeded: needed.probability,
        action: choice,
        actionConfidence: action.confidence,
        pStubOk: stubOk.probability,
      };
      opts.cache.set(key, verdict);
      verdicts.set(c.entryId, verdict);
    }
  };

  try {
    await Promise.all([worker(), worker(), worker(), worker()]);
  } finally {
    clearTimeout(timer);
  }
  usage.ms = Date.now() - started;
  return { verdicts, usage };
}
