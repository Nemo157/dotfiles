// Runs the optional `prompt` query over fetched content using a small model.
//
// The model is configured via `web-fetch.model` ("provider/id" or
// "provider/id:thinking"). We resolve it against a lazily-created
// `ModelRuntime` (which owns auth resolution from auth.json / env vars) and
// issue a single non-streaming completion with the document as context. No
// tools, no session — just one question in, one answer out.

import { ModelRuntime } from "@earendil-works/pi-coding-agent";
import type { ModelThinkingLevel, ThinkingLevel } from "@earendil-works/pi-ai";

const THINKING_LEVELS = new Set([
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

export interface ModelSpec {
  provider: string;
  id: string;
  thinking?: ModelThinkingLevel;
}

/** Parse "provider/id" or "provider/id:thinking". Returns undefined if the
 *  provider or id is missing. */
export function parseModelSpec(spec: string): ModelSpec | undefined {
  const slash = spec.indexOf("/");
  if (slash <= 0) return undefined;
  const provider = spec.slice(0, slash);
  let id = spec.slice(slash + 1);
  let thinking: ModelThinkingLevel | undefined;
  const colon = id.lastIndexOf(":");
  if (colon >= 0) {
    const suffix = id.slice(colon + 1);
    if (THINKING_LEVELS.has(suffix)) {
      thinking = suffix as ModelThinkingLevel;
      id = id.slice(0, colon);
    }
  }
  if (!provider || !id) return undefined;
  return { provider, id, thinking };
}

let runtimePromise: Promise<ModelRuntime> | undefined;
function getRuntime(): Promise<ModelRuntime> {
  if (!runtimePromise) runtimePromise = ModelRuntime.create();
  return runtimePromise;
}

const SYSTEM_PROMPT =
  "You answer a question about a single web document. Use only the document " +
  "text provided; do not use outside knowledge. If the answer is not present " +
  "in the document, say so plainly. Be concise and quote the relevant details.";

const SUMMARY_SYSTEM_PROMPT =
  "You are given a question and an assistant's answer to it. Condense the " +
  "answer into a single plain-text line (no more than ~20 words) phrased as a " +
  "direct summarized answer to that question. Omit preamble, markdown, and " +
  "quotes. Reply with the one-line summary and nothing else.";

/** Collect the text parts of a completion message into a trimmed string. */
function messageText(message: {
  content: { type: string }[];
}): string {
  return (message.content as { type: string; text?: string }[])
    .filter((c): c is { type: "text"; text: string } => c.type === "text")
    .map((c) => c.text)
    .join("")
    .trim();
}

export interface PromptResult {
  answer: string;
  truncated: boolean;
}

/**
 * Answer `question` about `content` using the configured small model.
 * Throws if the model spec is invalid, the model is unknown, or the provider
 * returns an error.
 */
export async function runPrompt(opts: {
  modelSpec: string;
  url: string;
  content: string;
  question: string;
  maxChars: number;
  signal?: AbortSignal;
}): Promise<PromptResult> {
  const parsed = parseModelSpec(opts.modelSpec);
  if (!parsed) {
    throw new Error(`Invalid web-fetch model spec: '${opts.modelSpec}'`);
  }

  const runtime = await getRuntime();
  const model = runtime.getModel(parsed.provider, parsed.id);
  if (!model) {
    throw new Error(`web-fetch model not found: '${opts.modelSpec}'`);
  }

  const truncated = opts.content.length > opts.maxChars;
  const content = truncated
    ? opts.content.slice(0, opts.maxChars)
    : opts.content;

  const user =
    `Source URL: ${opts.url}\n\n` +
    `Question: ${opts.question}\n\n` +
    `--- BEGIN DOCUMENT ---\n${content}\n--- END DOCUMENT ---` +
    (truncated ? "\n\n[Document truncated for length.]" : "");

  // `reasoning` accepts a ThinkingLevel; "off" means "no thinking", which the
  // API expresses as an absent reasoning option.
  const reasoning: ThinkingLevel | undefined =
    parsed.thinking && parsed.thinking !== "off" ? parsed.thinking : undefined;

  const message = await runtime.completeSimple(
    model,
    {
      systemPrompt: SYSTEM_PROMPT,
      messages: [{ role: "user", content: user, timestamp: Date.now() }],
    },
    { signal: opts.signal, reasoning },
  );

  if (message.stopReason === "error") {
    throw new Error(message.errorMessage ?? "small model returned an error");
  }

  return { answer: messageText(message), truncated };
}

/**
 * Reduce a longer answer to a single-line summary using the same small model.
 * Used only for the collapsed TUI summary; never sent to the agent.
 */
export async function summarizeAnswer(opts: {
  modelSpec: string;
  question: string;
  answer: string;
  signal?: AbortSignal;
}): Promise<string> {
  const parsed = parseModelSpec(opts.modelSpec);
  if (!parsed) {
    throw new Error(`Invalid web-fetch model spec: '${opts.modelSpec}'`);
  }

  const runtime = await getRuntime();
  const model = runtime.getModel(parsed.provider, parsed.id);
  if (!model) {
    throw new Error(`web-fetch model not found: '${opts.modelSpec}'`);
  }

  const reasoning: ThinkingLevel | undefined =
    parsed.thinking && parsed.thinking !== "off" ? parsed.thinking : undefined;

  const user =
    `Question: ${opts.question}\n\n` +
    `Answer:\n${opts.answer}`;

  const message = await runtime.completeSimple(
    model,
    {
      systemPrompt: SUMMARY_SYSTEM_PROMPT,
      messages: [{ role: "user", content: user, timestamp: Date.now() }],
    },
    { signal: opts.signal, reasoning },
  );

  if (message.stopReason === "error") {
    throw new Error(message.errorMessage ?? "small model returned an error");
  }

  // Collapse any stray newlines the model may emit into a single line.
  return messageText(message).replace(/\s*\n\s*/g, " ").trim();
}
