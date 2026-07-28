// web-fetch: a local pi extension for fetching and reading web pages.
//
// One tool, `web-fetch`, with two content modes:
//
//   extract (default) — download the URL and convert it to readable text.
//                       HTML is run through Mozilla Readability (over a
//                       linkedom DOM); other textual types pass through.
//   raw               — return the body verbatim.
//
// TUI display: the tool renders a custom header (`renderCall`) showing the
// URL, mode, refresh, and prompt, and a custom result view (`renderResult`)
// with a compact status/type/size summary that expands to the final URL and
// cache artifact paths. While running it uses pi's partial rendering to stream
// live progress — download bytes/percentage during fetch, then the extract and
// model-query phases.
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
import { keyHint } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Text } from "@earendil-works/pi-tui";
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

type Phase = "fetching" | "extracting" | "querying";

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

/** Details attached to partial (streaming) updates, driving renderResult. */
interface WebFetchProgress {
  url: string;
  mode: "extract" | "raw";
  phase: Phase;
  startedAt: number;
  receivedBytes?: number;
  totalBytes?: number;
}

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

function elapsedSuffix(startedAt: number): string {
  return ` (${((Date.now() - startedAt) / 1000).toFixed(1)}s)`;
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
    async execute(_toolCallId, params, signal, onUpdate, _ctx) {
      const startedAt = Date.now();
      const emitProgress = (progress: WebFetchProgress) => {
        onUpdate?.({
          content: [{ type: "text" as const, text: progress.phase }],
          details: progress,
        });
      };
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
        // Throttle progress updates so a chatty stream doesn't flood pi with
        // re-renders; always let the first (0-byte) tick through.
        let lastEmit = 0;
        try {
          fetched = await fetchUrl(rawUrl, {
            timeoutMs: config.timeoutMs,
            userAgent: config.userAgent,
            signal,
            onProgress: (received, total) => {
              const now = Date.now();
              if (received !== 0 && now - lastEmit < 100) return;
              lastEmit = now;
              emitProgress({
                url: rawUrl,
                mode,
                phase: "fetching",
                startedAt,
                receivedBytes: received,
                totalBytes: total,
              });
            },
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
            emitProgress({ url: rawUrl, mode, phase: "extracting", startedAt });
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
          emitProgress({ url: rawUrl, mode, phase: "querying", startedAt });
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

    // ── Custom TUI display ───────────────────────────────────────────────
    renderCall(args, theme, context) {
      const text =
        (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
      const a = args as {
        url?: string;
        mode?: string;
        refresh?: boolean;
        prompt?: string;
      };
      let s = theme.fg("toolTitle", theme.bold("web-fetch "));
      s += theme.fg("accent", a.url ?? "…");
      if (a.mode === "raw") s += " " + theme.fg("muted", "[raw]");
      if (a.refresh) s += " " + theme.fg("warning", "[refresh]");
      if (a.prompt && a.prompt.trim().length > 0) {
        s += "\n" + theme.fg("dim", `? ${a.prompt.trim()}`);
      }
      text.setText(s);
      return text;
    },

    renderResult(result, opts, theme, _context) {
      // ── Streaming: show phase + download progress ──────────────────────
      if (opts.isPartial) {
        const p = result.details as WebFetchProgress | undefined;
        if (!p) return new Text(theme.fg("warning", "⋮ Fetching…"), 0, 0);
        if (p.phase === "fetching") {
          const got = p.receivedBytes ?? 0;
          let body: string;
          if (p.totalBytes && p.totalBytes > 0) {
            const pct = Math.min(100, Math.round((got / p.totalBytes) * 100));
            body = `${formatBytes(got)} / ${formatBytes(p.totalBytes)} (${pct}%)`;
          } else {
            body = `${formatBytes(got)} downloaded`;
          }
          return new Text(
            theme.fg("warning", `⋮ Fetching ${body}${elapsedSuffix(p.startedAt)}`),
            0,
            0,
          );
        }
        const label = p.phase === "extracting" ? "Extracting…" : "Querying model…";
        return new Text(
          theme.fg("warning", `⋮ ${label}${elapsedSuffix(p.startedAt)}`),
          0,
          0,
        );
      }

      const d = result.details as WebFetchDetails | undefined;

      // ── Errors / missing details: fall back to the textual content ─────
      if (result.isError || !d || typeof d.status !== "number") {
        const first = result.content?.[0];
        const msg =
          first && first.type === "text" ? first.text : "web-fetch: error";
        return new Text(theme.fg(result.isError ? "error" : "dim", msg), 0, 0);
      }

      const statusColor =
        d.status >= 400 ? "error" : d.status >= 300 ? "warning" : "success";
      let summary = theme.fg(statusColor, `HTTP ${d.status}`);
      summary += theme.fg(
        "dim",
        ` · ${d.contentType} · ${formatBytes(d.rawBytes)}`,
      );
      summary += theme.fg("muted", d.fromCache ? " · cached" : " · fetched");
      if (d.title) summary += "\n" + theme.fg("accent", d.title);

      if (!opts.expanded) {
        const hint = theme.fg(
          "dim",
          ` — ${keyHint("app.tools.expand", "to expand")}`,
        );
        return new Text(summary + hint, 0, 0);
      }

      // ── Expanded: URLs, mode, and cache artifact paths ─────────────────
      const lines: string[] = [summary];
      if (d.finalUrl && d.finalUrl !== d.url) {
        lines.push(theme.fg("dim", `url:     ${d.url}`));
        lines.push(theme.fg("muted", `final:   ${d.finalUrl}`));
      } else {
        lines.push(theme.fg("muted", `url:     ${d.finalUrl || d.url}`));
      }
      lines.push(theme.fg("dim", `mode:    ${d.mode}`));
      if (d.extractPath) lines.push(theme.fg("dim", `extract: ${d.extractPath}`));
      lines.push(theme.fg("dim", `raw:     ${d.rawPath}`));
      if (d.promptPath) lines.push(theme.fg("dim", `answer:  ${d.promptPath}`));
      if (!d.inlined) {
        lines.push(theme.fg("warning", "content not inlined — read the cached file"));
      }
      return new Text(lines.join("\n"), 0, 0);
    },
  });
}
