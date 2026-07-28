// web-fetch: a local pi extension for fetching and reading web pages.
//
// One tool, `web-fetch`, with two content modes:
//
//   extract (default) — download the URL and convert it to readable text.
//                       HTML is run through Mozilla Readability (over a
//                       linkedom DOM); other textual types pass through.
//   raw               — return the body verbatim.
//
// An optional `prompt` parameter runs the fetched content through a small,
// separately-configured model to answer a specific question. The parameter is
// only exposed when `web-fetch.model` is set in the extension config — there is
// no default model.
//
// Caching: every download, extraction, and prompt answer is written under the
// cache root (see config.ts). Large or binary results are not inlined into the
// tool result; instead the tool returns a short summary plus the cache file
// path and instructs the agent to `read` it. The cache directory is granted
// read access via the permission system's `piInfrastructureReadPaths` (wired
// in ../../default.nix), so those follow-up reads don't trigger an approval
// prompt.
//
// Note on "temporary per-path allow": the permission system's live-authority
// chain cannot grant `external_directory`/`path` reads (the bounded-delegation
// checkpoint downgrades such allows to `defer`), so a dynamic authorizer link
// would not work here. Auto-allowing the cache root via `piInfrastructureReadPaths`
// is the supported mechanism and is what we use.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type, type TSchema } from "typebox";
import { basename } from "node:path";

import { loadConfig } from "./config";
import { Cache, hash } from "./cache";
import {
  extractHtml,
  fetchUrl,
  isHtml,
  isTextual,
  rawExtension,
} from "./web";
import { runPrompt } from "./model";

interface WebFetchDetails {
  url: string;
  finalUrl: string;
  status: number;
  contentType: string;
  mode: "extract" | "raw";
  rawPath: string;
  rawBytes: number;
  extractPath?: string;
  promptPath?: string;
  title?: string;
  inlined: boolean;
  fromCache: boolean;
}

function textResult(text: string, details: WebFetchDetails, isError = false) {
  return {
    content: [{ type: "text" as const, text }],
    details,
    isError,
  };
}

function errorResult(message: string) {
  return {
    content: [{ type: "text" as const, text: message }],
    details: {},
    isError: true,
  };
}

export default function webFetchExtension(pi: ExtensionAPI): void {
  const config = loadConfig();
  const cache = new Cache(config.cacheDir);
  const promptEnabled = Boolean(config.model);

  const properties: Record<string, TSchema> = {
    url: Type.String({
      description: "Absolute http(s) URL to fetch.",
    }),
    mode: Type.Optional(
      StringEnum(["extract", "raw"], {
        description:
          "Content mode. 'extract' (default) converts the page to readable " +
          "text (HTML via Readability). 'raw' returns the body verbatim.",
      }),
    ),
    refresh: Type.Optional(
      Type.Boolean({
        description:
          "Re-download even if a cached copy exists (default false).",
      }),
    ),
  };

  if (promptEnabled) {
    properties.prompt = Type.Optional(
      Type.String({
        description:
          "Optional question to answer using only the fetched content, via a " +
          "small model. When set, the tool returns the model's answer.",
      }),
    );
  }

  const description = [
    "Fetch a web page and return its content.",
    "Modes: 'extract' (default) converts to readable text; 'raw' returns the body verbatim.",
    promptEnabled
      ? "Set 'prompt' to ask a specific question about the page; a small model answers using only the fetched content."
      : "",
    "Large or binary results are cached and returned as a file path to read instead of inline content.",
  ]
    .filter(Boolean)
    .join(" ");

  pi.registerTool({
    name: "web-fetch",
    label: "Web Fetch",
    description,
    promptSnippet:
      "Fetch a URL as readable text (extract) or raw; large results come back as a cache path to read.",
    parameters: Type.Object(properties),
    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      const rawUrl = String((params as { url?: unknown }).url ?? "").trim();
      let parsedUrl: URL;
      try {
        parsedUrl = new URL(rawUrl);
      } catch {
        return errorResult(`Invalid URL: '${rawUrl}'`);
      }
      if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
        return errorResult(
          `Only http/https URLs are supported (got '${parsedUrl.protocol}').`,
        );
      }

      const mode: "extract" | "raw" =
        (params as { mode?: string }).mode === "raw" ? "raw" : "extract";
      const refresh = (params as { refresh?: boolean }).refresh === true;
      const question =
        promptEnabled &&
        typeof (params as { prompt?: unknown }).prompt === "string" &&
        (params as { prompt: string }).prompt.trim().length > 0
          ? (params as { prompt: string }).prompt.trim()
          : undefined;

      const key = hash(`${mode}:${rawUrl}`);

      // ── Download (or reuse cache) ────────────────────────────────────────
      let meta = cache.readMeta(key);
      let fromCache = false;
      let rawBody: Buffer | undefined;

      if (!refresh && meta && cache.has(key, meta.rawFile)) {
        fromCache = true;
        rawBody = cache.readBytes(key, meta.rawFile);
      }

      if (!meta || !rawBody) {
        let fetched;
        try {
          fetched = await fetchUrl(rawUrl, {
            timeoutMs: config.timeoutMs,
            userAgent: config.userAgent,
            signal,
          });
        } catch (err) {
          return errorResult(
            `Fetch failed for ${rawUrl}: ${(err as Error).message}`,
          );
        }
        const ext = rawExtension(fetched.contentType, fetched.finalUrl);
        const rawFile = `raw.${ext}`;
        cache.writeBytes(key, rawFile, fetched.body);
        meta = {
          url: rawUrl,
          finalUrl: fetched.finalUrl,
          status: fetched.status,
          contentType: fetched.contentType,
          mode,
          rawFile,
          fetchedAt: Date.now(),
          rawBytes: fetched.body.byteLength,
        };
        rawBody = fetched.body;
        fromCache = false;
      }

      if (!meta || !rawBody) {
        return errorResult("web-fetch: internal error (no content)");
      }

      const rawPath = cache.path(key, meta.rawFile);
      const textual = isTextual(meta.contentType);

      const details: WebFetchDetails = {
        url: rawUrl,
        finalUrl: meta.finalUrl,
        status: meta.status,
        contentType: meta.contentType || "(unknown)",
        mode,
        rawPath,
        rawBytes: meta.rawBytes,
        title: meta.title,
        inlined: false,
        fromCache,
      };

      // ── Produce the primary text payload ─────────────────────────────────
      let primaryText: string;
      let payloadKind: "extract" | "raw";

      if (mode === "raw") {
        payloadKind = "raw";
        if (!textual) {
          // Binary raw content: never inline; hand back the cache path.
          const summary =
            `Fetched ${meta.finalUrl} (HTTP ${meta.status}, ${meta.contentType || "unknown type"}, ` +
            `${meta.rawBytes} bytes). Binary/non-text content saved to:\n${rawPath}`;
          return textResult(summary, details);
        }
        primaryText = rawBody.toString("utf8");
      } else {
        payloadKind = "extract";
        if (isHtml(meta.contentType)) {
          let cachedExtract = meta.extractFile
            ? cache.readText(key, meta.extractFile)
            : undefined;
          if (cachedExtract === undefined) {
            const extraction = extractHtml(rawBody.toString("utf8"), meta.finalUrl);
            const extractFile = "extract.txt";
            const header = extraction.title ? `# ${extraction.title}\n\n` : "";
            cachedExtract = header + extraction.text;
            cache.writeText(key, extractFile, cachedExtract);
            meta.extractFile = extractFile;
            meta.title = extraction.title;
            details.title = extraction.title;
            cache.writeMeta(key, meta);
          }
          primaryText = cachedExtract;
        } else if (textual) {
          // Textual but not HTML: nothing to extract, use the body as-is.
          primaryText = rawBody.toString("utf8");
        } else {
          const summary =
            `Fetched ${meta.finalUrl} (HTTP ${meta.status}, ${meta.contentType || "unknown type"}, ` +
            `${meta.rawBytes} bytes). Content is not text and cannot be extracted; raw file saved to:\n${rawPath}`;
          return textResult(summary, details);
        }
      }

      details.extractPath =
        payloadKind === "extract" && meta.extractFile
          ? cache.path(key, meta.extractFile)
          : undefined;

      // ── Optional prompt query over the content ───────────────────────────
      if (question) {
        try {
          const result = await runPrompt({
            modelSpec: config.model!,
            url: meta.finalUrl,
            content: primaryText,
            question,
            maxChars: config.maxPromptChars,
            signal,
          });
          const promptFile = `prompt-${hash(question)}.txt`;
          const promptPath = cache.writeText(
            key,
            promptFile,
            `Q: ${question}\n\n${result.answer}\n`,
          );
          details.promptPath = promptPath;
          details.inlined = true;
          const note = result.truncated
            ? "\n\n(Note: the document was truncated before querying.)"
            : "";
          const text =
            `Answer for ${meta.finalUrl}:\n\n${result.answer}${note}\n\n` +
            `Full ${payloadKind} content cached at: ${details.extractPath ?? rawPath}`;
          return textResult(text, details);
        } catch (err) {
          // Fall through to returning the content itself on model failure.
          const failNote =
            `\n\n[web-fetch: prompt query failed: ${(err as Error).message}]`;
          primaryText = primaryText + failNote;
        }
      }

      // ── Inline vs. path decision ─────────────────────────────────────────
      const bytes = Buffer.byteLength(primaryText, "utf8");
      const pathForContent = details.extractPath ?? rawPath;
      if (bytes > config.maxInlineBytes) {
        const summary =
          `Fetched ${meta.finalUrl} (HTTP ${meta.status}, ${meta.contentType || "unknown type"}).\n` +
          `${payloadKind === "extract" ? "Extracted" : "Raw"} text is ${bytes} bytes ` +
          `(> ${config.maxInlineBytes} inline limit), saved to:\n${pathForContent}\n\n` +
          `Read that file (use offset/limit for large files) to view the content.`;
        details.inlined = false;
        return textResult(summary, details);
      }

      details.inlined = true;
      const heading =
        `${meta.finalUrl} (HTTP ${meta.status})` +
        (details.title ? ` — ${details.title}` : "") +
        `\n[${payloadKind}, ${bytes} bytes; cached at ${basename(pathForContent)}]\n\n`;
      return textResult(heading + primaryText, details);
    },
  });
}
