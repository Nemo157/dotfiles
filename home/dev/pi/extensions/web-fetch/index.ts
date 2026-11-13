// web-fetch: a local pi extension for fetching and reading web pages.
//
// One tool, `web-fetch`, with two content modes:
//
//   extract (default) — download the URL and convert it to readable text.
//                       HTML is run through Mozilla Readability (over a
//                       linkedom DOM), PDFs through unpdf; other textual
//                       types pass through. Archives (zip/tar/7z, possibly
//                       compressed) are unpacked with bsdtar and returned
//                       as a file listing; `member` extracts one file from
//                       them. Single compressed files (.gz/.xz/…) are
//                       decompressed and then extracted as usual (see
//                       archive.ts).
//   raw               — return the body verbatim (JSON is pretty-printed so
//                       the cached file is greppable).
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
import { existsSync, readFileSync } from "node:fs";
import { basename } from "node:path";

import { loadConfig } from "./config";
import { Cache, hash } from "./cache";
import {
  archiveExtension,
  archiveKindFor,
  archiveRoot,
  containerKind,
  decompress,
  innerName,
  listTree,
  nameExtension,
  readFileHead,
  resolveMember,
  unpack,
  type ArchiveLimits,
} from "./archive";
import {
  extractHtml,
  extractPdf,
  fetchUrl,
  guessContentType,
  SNIFF_BYTES,
  urlFileName,
  isHtml,
  isPdf,
  isTextual,
  prettyJson,
  rawExtension,
} from "./web";
import { runPrompt, summarizeAnswer } from "./model";

// Show inlined content in the expanded row when it is small enough. Inlined
// content is already bounded by config.maxInlineBytes; this just guards the
// pathological single-giant-line case.
const MAX_PREVIEW_CHARS = 8_000;

type Phase = "fetching" | "unpacking" | "extracting" | "querying";

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
  /** Archive member that was extracted, if any. */
  member?: string;
  /** Set when the result is an unpacked archive's file listing. */
  archive?: {
    kind: string;
    root: string;
    files: number;
    totalBytes: number;
    listingPath: string;
  };
  inlined: boolean;
  fromCache: boolean;
  /** One-line condensation of the prompt answer, for the collapsed view. */
  answerSummary?: string;
  /** Why the prompt query failed, if it did (content is returned instead). */
  promptError?: string;
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

function textResult(text: string, details: WebFetchDetails) {
  return {
    content: [{ type: "text" as const, text }],
    details,
  };
}

// Failures throw. None of them has details worth keeping (a returned
// `isError: true` result would be needed for that), so renderResult just
// falls back to the message text.

// Models sometimes fill optional params with a null placeholder, which can
// arrive as JSON null or (after schema coercion) the literal string "null".
// Treat those, and blank strings, as absent.
function normalizeOptional(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (trimmed.length === 0) return undefined;
  if (/^(null|undefined|none)$/i.test(trimmed)) return undefined;
  return trimmed;
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
          "'extract' (default) converts the page to readable text; 'raw' " +
          "returns the body verbatim.",
      }),
    ),
    refresh: Type.Optional(
      Type.Boolean({
        description: "Re-download even if a cached copy exists.",
      }),
    ),
    member: Type.Optional(
      Type.String({
        description:
          "For zip/tar/7z archives: path of one file inside the archive (as " +
          "listed by a previous call) to extract instead of the listing.",
      }),
    ),
  };

  if (promptEnabled) {
    properties.prompt = Type.Optional(
      Type.String({
        description:
          "Question to answer from the fetched content; a small model " +
          "answers and the tool returns that answer instead.",
      }),
    );
  }

  const description = [
    "Fetch a web page and return its content.",
    promptEnabled ? "Set 'prompt' to ask a question about the page." : "",
    "Large or binary results come back as a cache file path to read.",
    "'extract' supports HTML, PDF, and plain-text formats (JSON, XML, CSV, " +
      "Markdown, etc.).",
    "Archives (zip, tar, 7z, optionally compressed) are unpacked and " +
      "returned as a file listing plus a directory to browse with read/rg/fd; " +
      "set 'member' to extract one file. Single compressed files (.gz, .xz, " +
      "…) are decompressed and extracted.",
    "Do not fetch other binary formats (images, office documents, …) " +
      "unless you only need the file itself via 'raw'; if you need their " +
      "contents, ask the user how to extract them instead.",
  ]
    .filter(Boolean)
    .join(" ");

  pi.registerTool({
    name: "web-fetch",
    label: "Web Fetch",
    description,
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
        throw new Error(`Invalid URL: '${rawUrl}'`);
      }
      if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
        throw new Error(
          `Only http/https URLs are supported (got '${parsedUrl.protocol}').`,
        );
      }

      const mode: "extract" | "raw" =
        (params as { mode?: string }).mode === "raw" ? "raw" : "extract";
      const refresh = (params as { refresh?: boolean }).refresh === true;
      const question = promptEnabled
        ? normalizeOptional((params as { prompt?: unknown }).prompt)
        : undefined;
      // Canonicalized once resolved against an unpacked archive.
      let member = normalizeOptional((params as { member?: unknown }).member);
      if (mode === "raw" && member) {
        throw new Error("'member' is only supported in extract mode.");
      }

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
          throw new Error(
            `Fetch failed for ${rawUrl}: ${(err as Error).message}`,
          );
        }
        const ext = rawExtension(
          fetched.contentType,
          fetched.fileName,
          fetched.body,
        );
        const rawFile = `raw.${ext}`;
        // JSON is stored pretty-printed so the cache file is greppable.
        const body = prettyJson(fetched.contentType, fetched.body);
        // Drop artifacts derived from any previous download.
        cache.clear(key);
        cache.writeBytes(key, rawFile, body);
        meta = {
          url: rawUrl,
          finalUrl: fetched.finalUrl,
          status: fetched.status,
          contentType: fetched.contentType,
          mode,
          rawFile,
          fileName: fetched.fileName,
          fetchedAt: Date.now(),
          rawBytes: body.byteLength,
        };
        cache.writeMeta(key, meta);
        rawBody = body;
        fromCache = false;
      }

      if (!meta || !rawBody) {
        throw new Error("web-fetch: internal error (no content)");
      }

      const rawPath = cache.path(key, meta.rawFile);

      const details: WebFetchDetails = {
        url: rawUrl,
        finalUrl: meta.finalUrl,
        status: meta.status,
        contentType: meta.contentType || "(unknown)",
        mode,
        rawPath,
        rawBytes: meta.rawBytes,
        title: meta.title,
        member,
        inlined: false,
        fromCache,
      };

      // Appended to early returns for non-extractable content, so a dropped
      // prompt is visible rather than silently ignored.
      const promptIgnoredNote = question
        ? "\n\n(prompt ignored: content not extractable)"
        : "";
      const fetchedLine =
        `Fetched ${meta.finalUrl} (HTTP ${meta.status}, ${meta.contentType || "unknown type"}, ` +
        `${meta.rawBytes} bytes)`;

      // ── Produce the primary text payload ─────────────────────────────────
      let primaryText: string;
      let payloadKind: "extract" | "raw";
      // File the payload was read from (the download, a decompressed stream,
      // or an archive member) and the cached extraction of it, if any.
      let contentPath = rawPath;
      let extractPath: string | undefined;

      if (mode === "raw") {
        payloadKind = "raw";
        if (!isTextual(meta.contentType)) {
          // Binary raw content: never inline; hand back the cache path.
          const summary =
            `${fetchedLine}. Binary/non-text content saved to:\n${rawPath}` +
            promptIgnoredNote;
          return textResult(summary, details);
        }
        primaryText = rawBody.toString("utf8");
      } else {
        payloadKind = "extract";
        // What to extract: the download itself, or for archives a
        // decompressed stream / one unpacked member.
        // Archive members and decompressed files are only sniffed via their
        // head here and read in full once their content is needed.
        let body: Buffer | undefined = rawBody;
        let head = rawBody;
        let contentType = meta.contentType;
        // Top-level extractions are recorded in meta (with their title);
        // member extractions are cached by name, their titles in
        // meta.memberTitles.
        let extractFile = "extract.txt";
        let topLevel = true;

        // Name hint for the download (cache entries from before it was
        // recorded fall back to the URL).
        const fileName =
          meta.fileName ?? urlFileName(meta.finalUrl) ?? "content";
        const kind = archiveKindFor(rawBody, fileName, meta.contentType);
        if (kind) {
          const limits: ArchiveLimits = {
            bsdtar: config.bsdtar,
            bsdcat: config.bsdcat,
            maxBytes: config.maxArchiveBytes,
            maxEntries: config.maxArchiveEntries,
          };
          let root: string | undefined;
          let pruned = meta.archivePruned ?? 0;
          if (meta.archiveDir && existsSync(cache.path(key, meta.archiveDir))) {
            root = archiveRoot(cache.path(key, meta.archiveDir));
          } else if (
            !meta.decompressedFile ||
            !cache.has(key, meta.decompressedFile)
          ) {
            emitProgress({ url: rawUrl, mode, phase: "unpacking", startedAt });
            try {
              const container = await containerKind(
                rawPath,
                kind,
                limits,
                signal,
              );
              if (container) {
                const unpacked = await unpack(
                  rawPath,
                  cache.path(key, "archive"),
                  limits,
                  signal,
                );
                root = unpacked.root;
                pruned = unpacked.pruned;
                meta.archiveDir = "archive";
                meta.archivePruned = pruned;
              } else {
                const ext = nameExtension(innerName(fileName)) ?? "bin";
                const decompressedFile = `decompressed.${ext}`;
                await decompress(
                  rawPath,
                  cache.path(key, decompressedFile),
                  limits,
                  signal,
                );
                meta.decompressedFile = decompressedFile;
              }
            } catch (err) {
              // A cancelled call should fail, not report a broken archive.
              if (signal?.aborted) throw err;
              const summary =
                `${fetchedLine}. Unpacking the ${archiveExtension(kind)} archive failed ` +
                `(${(err as Error).message}); raw file saved to:\n${rawPath}` +
                promptIgnoredNote;
              return textResult(summary, details);
            }
            cache.writeMeta(key, meta);
          }

          if (root !== undefined) {
            if (!member) {
              // Container without a member: return the file listing.
              const listing = listTree(root, formatBytes);
              const listingPath = cache.writeText(
                key,
                "listing.txt",
                listing.lines.join("\n") + "\n",
              );
              details.archive = {
                kind,
                root,
                files: listing.files,
                totalBytes: listing.totalBytes,
                listingPath,
              };
              const shown = listing.lines.slice(0, config.maxListingEntries);
              const more = listing.lines.length - shown.length;
              const text =
                `${fetchedLine}.\nUnpacked ${kind} archive: ${listing.files} files, ` +
                `${formatBytes(listing.totalBytes)}, root:\n${root}\n\n` +
                shown.join("\n") +
                (more > 0
                  ? `\n… ${more} more entries; full listing: ${listingPath}`
                  : "") +
                (pruned > 0
                  ? `\n(${pruned} symlinks/special files were dropped)`
                  : "") +
                `\n\nBrowse the files under the root with read/rg/fd, or call ` +
                `web-fetch again with 'member' set to one of the paths above ` +
                `to extract that file (HTML/PDF/text).` +
                (question
                  ? "\n\n(prompt ignored: set 'member' to ask about one file)"
                  : "");
              details.inlined = true;
              return textResult(text, details);
            }
            try {
              const resolved = resolveMember(root, member);
              contentPath = resolved.path;
              member = resolved.name;
              details.member = member;
              details.title = meta.memberTitles?.[member];
            } catch (err) {
              throw new Error(
                `${(err as Error).message}; call without 'member' to list the archive.`,
              );
            }
            body = undefined;
            head = readFileHead(contentPath, SNIFF_BYTES + 1);
            contentType = guessContentType(
              member,
              head,
              head.length > SNIFF_BYTES,
            );
            extractFile = `member-${hash(member)}.txt`;
            topLevel = false;
          } else {
            if (member) {
              throw new Error(
                "'member' only applies to zip/tar/7z archives; this is a " +
                  "single compressed file.",
              );
            }
            contentPath = cache.path(key, meta.decompressedFile!);
            body = undefined;
            head = readFileHead(contentPath, SNIFF_BYTES + 1);
            contentType = guessContentType(
              innerName(fileName),
              head,
              head.length > SNIFF_BYTES,
            );
          }
          details.contentType = `${details.contentType} → ${contentType}`;
        } else if (member) {
          throw new Error("'member' only applies to archives.");
        }

        const readBody = () => (body ??= readFileSync(contentPath));
        const html = isHtml(contentType);
        const pdf = !html && isPdf(contentType, head);
        if (html || pdf) {
          // A fresh download clears the key dir, so a cached extraction is
          // always derived from the current body.
          let cachedExtract = cache.readText(key, extractFile);
          if (cachedExtract === undefined) {
            emitProgress({ url: rawUrl, mode, phase: "extracting", startedAt });
            let extraction;
            if (pdf) {
              try {
                extraction = await extractPdf(readBody());
              } catch (err) {
                const summary =
                  `${fetchedLine}. PDF text extraction failed (${(err as Error).message}); ` +
                  `file saved to:\n${contentPath}` +
                  promptIgnoredNote;
                return textResult(summary, details);
              }
            } else {
              extraction = extractHtml(
                readBody().toString("utf8"),
                meta.finalUrl,
              );
            }
            const header = extraction.title ? `# ${extraction.title}\n\n` : "";
            cachedExtract = header + extraction.text;
            cache.writeText(key, extractFile, cachedExtract);
            details.title = extraction.title;
            if (topLevel) {
              meta.extractFile = extractFile;
              meta.title = extraction.title;
              cache.writeMeta(key, meta);
            } else if (member && extraction.title) {
              meta.memberTitles = {
                ...meta.memberTitles,
                [member]: extraction.title,
              };
              cache.writeMeta(key, meta);
            }
          }
          primaryText = cachedExtract;
          extractPath = cache.path(key, extractFile);
        } else if (isTextual(contentType)) {
          // Textual but not HTML: nothing to extract, use the body as-is.
          primaryText = readBody().toString("utf8");
        } else {
          const summary =
            `${fetchedLine}${member ? `, member '${member}'` : ""}. Content is ` +
            `not text and cannot be extracted; file saved to:\n${contentPath}` +
            promptIgnoredNote;
          return textResult(summary, details);
        }
      }

      details.extractPath = extractPath;

      // ── Optional prompt query over the content ───────────────────────────
      let failNote = "";
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
          const promptFile = `prompt-${hash(`${member ?? ""}\n${question}`)}.txt`;
          const promptPath = cache.writeText(
            key,
            promptFile,
            `Q: ${question}\n\n${result.answer}\n`,
          );
          details.promptPath = promptPath;
          details.inlined = true;
          try {
            details.answerSummary = await summarizeAnswer({
              modelSpec: config.model!,
              question,
              answer: result.answer,
              signal,
            });
          } catch {
            // Summary is best-effort; the collapsed view falls back without it.
          }
          const note = result.truncated
            ? "\n\n(Note: the document was truncated before querying.)"
            : "";
          const text =
            `Answer for ${meta.finalUrl}:\n\n${result.answer}${note}\n\n` +
            `Full ${payloadKind} content cached at: ${extractPath ?? contentPath}`;
          return textResult(text, details);
        } catch (err) {
          // Fall through to returning the content itself on model failure.
          details.promptError = (err as Error).message;
          failNote = `\n\n[web-fetch: prompt query failed: ${details.promptError}]`;
        }
      }

      // ── Inline vs. path decision ─────────────────────────────────────────
      const bytes = Buffer.byteLength(primaryText, "utf8");
      const pathForContent = extractPath ?? contentPath;
      if (bytes > config.maxInlineBytes) {
        const summary =
          `Fetched ${meta.finalUrl} (HTTP ${meta.status}, ${meta.contentType || "unknown type"}).\n` +
          `${payloadKind === "extract" ? "Extracted" : "Raw"} text is ${bytes} bytes ` +
          `(> ${config.maxInlineBytes} inline limit), saved to:\n${pathForContent}\n\n` +
          `Read that file (use offset/limit for large files) to view the content.` +
          failNote;
        details.inlined = false;
        return textResult(summary, details);
      }

      details.inlined = true;
      const heading =
        `${meta.finalUrl} (HTTP ${meta.status})` +
        (member ? ` → ${member}` : "") +
        (details.title ? ` — ${details.title}` : "") +
        `\n[${payloadKind}, ${bytes} bytes; cached at ${basename(pathForContent)}]\n\n`;
      return textResult(heading + primaryText + failNote, details);
    },

    // ── Custom TUI display ───────────────────────────────────────────────
    renderCall(args, theme, context) {
      const text =
        (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
      const a = args as {
        url?: string;
        mode?: string;
        refresh?: boolean;
        prompt?: unknown;
        member?: unknown;
      };
      let s = theme.fg("toolTitle", theme.bold("web-fetch "));
      s += theme.fg("accent", a.url ?? "…");
      if (a.mode === "raw") s += " " + theme.fg("muted", "[raw]");
      if (a.refresh) s += " " + theme.fg("warning", "[refresh]");
      const member = normalizeOptional(a.member);
      if (member) s += " " + theme.fg("muted", `→ ${member}`);
      const prompt = normalizeOptional(a.prompt);
      if (prompt) {
        s += "\n" + theme.fg("dim", `? ${prompt}`);
      }
      text.setText(s);
      return text;
    },

    renderResult(result, opts, theme, context) {
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
            theme.fg(
              "warning",
              `⋮ Fetching ${body}${elapsedSuffix(p.startedAt)}`,
            ),
            0,
            0,
          );
        }
        const label =
          p.phase === "unpacking"
            ? "Unpacking…"
            : p.phase === "extracting"
              ? "Extracting…"
              : "Querying model…";
        return new Text(
          theme.fg("warning", `⋮ ${label}${elapsedSuffix(p.startedAt)}`),
          0,
          0,
        );
      }

      const d = result.details as WebFetchDetails | undefined;

      // ── Errors / missing details: fall back to the textual content ─────
      if (context.isError || !d || typeof d.status !== "number") {
        const first = result.content?.[0];
        const msg =
          first && first.type === "text" ? first.text : "web-fetch: error";
        return new Text(theme.fg(context.isError ? "error" : "dim", msg), 0, 0);
      }

      const statusColor =
        d.status >= 400 ? "error" : d.status >= 300 ? "warning" : "success";
      let summary = theme.fg(statusColor, `HTTP ${d.status}`);
      summary += theme.fg(
        "dim",
        ` · ${d.contentType} · ${formatBytes(d.rawBytes)}`,
      );
      summary += theme.fg("muted", d.fromCache ? " · cached" : " · fetched");
      if (d.member) summary += "\n" + theme.fg("muted", `member: ${d.member}`);
      if (d.archive) {
        summary +=
          "\n" +
          theme.fg(
            "accent",
            `${d.archive.kind} archive: ${d.archive.files} files, ${formatBytes(d.archive.totalBytes)}`,
          );
      }
      if (d.title) summary += "\n" + theme.fg("accent", d.title);
      // Condensed prompt answer, shown in both collapsed and expanded views.
      if (d.answerSummary) summary += "\n" + theme.fg("text", d.answerSummary);
      if (d.promptError) {
        summary += "\n" + theme.fg("error", `prompt failed: ${d.promptError}`);
      }

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
      if (d.extractPath)
        lines.push(theme.fg("dim", `extract: ${d.extractPath}`));
      lines.push(theme.fg("dim", `raw:     ${d.rawPath}`));
      if (d.archive) {
        lines.push(theme.fg("dim", `root:    ${d.archive.root}`));
        lines.push(theme.fg("dim", `listing: ${d.archive.listingPath}`));
      }
      if (d.promptPath) lines.push(theme.fg("dim", `answer:  ${d.promptPath}`));
      if (!d.inlined) {
        lines.push(
          theme.fg("warning", "content not inlined — read the cached file"),
        );
      }

      // Show the inlined payload (as sent to the agent) when it is small
      // enough. No separate preview is stored: we read result.content.
      if (d.inlined) {
        const first = result.content?.[0];
        const payload = first && first.type === "text" ? first.text : undefined;
        if (payload && payload.length <= MAX_PREVIEW_CHARS) {
          lines.push(theme.fg("dim", "───"));
          lines.push(payload.trimEnd());
        }
      }
      return new Text(lines.join("\n"), 0, 0);
    },
  });
}
