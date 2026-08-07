// file-upload: a local pi extension for uploading data over HTTP.
//
// One tool, `upload`, which sends a request body to an http(s) URL with
// either POST or PUT. The payload can come from two sources:
//
//   path — read the bytes of a local file (the common "upload this file"
//          case). The parameter is deliberately named `path` so the pi
//          permission system's built-in access-intent extractor sees it and
//          evaluates the shared `path` deny globs (*.age, **\/.ssh/**, …)
//          plus the `external_directory` gate on it, exactly as it does for
//          `read`/`write`.
//   body — an inline string supplied by the model, optionally base64-decoded
//          first (`encoding: "base64"`), for small JSON/text payloads or
//          synthesised binary content without a temp file.
//
// Exactly one of the two must be given.
//
// Two wire formats:
//
//   raw (default)     — the payload IS the request body, with `contentType`
//                       (or a sniffed default) as Content-Type. This is what
//                       S3/WebDAV-style `PUT` endpoints and most "raw body"
//                       APIs want.
//   form: true        — multipart/form-data with the payload as one file part
//                       (`fieldName`, `filename`), plus any extra text
//                       `fields`. This is what classic HTML-form upload
//                       endpoints want.
//
// Security notes: an upload is an exfiltration channel, so the tool is gated
// (`upload = "ask"` in ../../default.nix; it would also fall through to the
// `"*" = "ask"` default). Beyond that we rely entirely on the permission
// system's `path` / `external_directory` gates seeing `input.path` — no
// re-check inside execute(). Unlike ../file-tools (which re-aims the access
// extractor at `dest` and so must guard `source` itself), the gated slot here
// IS the file we read, and the bounded-delegation checkpoint never lets a
// live-authority link turn a `path` deny into an allow. A second, local copy
// of that check could only drift from the gate (it wouldn't do the gate's
// symlink-alias matching, and it fails open when the service is absent).

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import * as path from "node:path";

// ── limits ────────────────────────────────────────────────────────────────
/** Hard abort for the request. Uploads are slower than fetches, hence 2min. */
const TIMEOUT_MS = 120_000;
/** Payloads are buffered whole in memory, so cap what we're willing to read. */
const MAX_UPLOAD_BYTES = 32 * 1024 * 1024;
/** How much of the response body is handed back to the model. */
const MAX_RESPONSE_INLINE_BYTES = 16 * 1024;
const USER_AGENT = "pi-file-upload/1.0";

// ── helpers ───────────────────────────────────────────────────────────────
function expandTilde(p: string): string {
  if (p === "~") return homedir();
  if (p.startsWith("~/")) return `${homedir()}/${p.slice(2)}`;
  return p;
}

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

const EXT_TYPES: Record<string, string> = {
  ".json": "application/json",
  ".txt": "text/plain",
  ".md": "text/markdown",
  ".csv": "text/csv",
  ".html": "text/html",
  ".xml": "application/xml",
  ".yaml": "application/yaml",
  ".yml": "application/yaml",
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".zip": "application/zip",
  ".gz": "application/gzip",
  ".tar": "application/x-tar",
};

function sniffContentType(file: string | undefined, inlineText: boolean): string {
  if (file) {
    const t = EXT_TYPES[path.extname(file).toLowerCase()];
    if (t) return t;
    return "application/octet-stream";
  }
  return inlineText ? "text/plain; charset=utf-8" : "application/octet-stream";
}

function asStringRecord(v: unknown): Record<string, string> {
  if (!v || typeof v !== "object" || Array.isArray(v)) return {};
  const out: Record<string, string> = {};
  for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
    if (val === undefined || val === null) continue;
    out[k] = String(val);
  }
  return out;
}

interface UploadDetails {
  url?: string;
  method?: string;
  status?: number;
  statusText?: string;
  form?: boolean;
  source?: "path" | "body";
  sourcePath?: string;
  sentBytes?: number;
  contentType?: string;
  responseType?: string;
  responseBytes?: number;
  location?: string;
  elapsedMs?: number;
  /** Response body, already truncated to the inline limit. */
  responseText?: string;
  truncated?: boolean;
  /** Streaming marker for renderResult's partial branch. */
  phase?: "uploading";
  startedAt?: number;
}

function result(text: string, details: UploadDetails, isError = false) {
  return { content: [{ type: "text" as const, text }], details, isError };
}

function fail(message: string, details: UploadDetails = {}) {
  return result(message, details, true);
}

// ── parameters ────────────────────────────────────────────────────────────
const parameters = Type.Object({
  url: Type.String({
    description: "Absolute http(s) URL to upload to.",
  }),
  method: Type.Optional(
    Type.Union([Type.Literal("POST"), Type.Literal("PUT")], {
      description: "HTTP method. Defaults to POST.",
    }),
  ),
  path: Type.Optional(
    Type.String({
      description:
        "Local file to upload; relative to cwd, `~` expands to $HOME. " +
        "Mutually exclusive with `body`.",
    }),
  ),
  body: Type.Optional(
    Type.String({
      description:
        "Inline payload instead of a file. Mutually exclusive with `path`.",
    }),
  ),
  encoding: Type.Optional(
    Type.Union([Type.Literal("utf8"), Type.Literal("base64")], {
      description:
        "How to interpret `body`: 'utf8' (default) or 'base64' (decoded to " +
        "binary first).",
    }),
  ),
  form: Type.Optional(
    Type.Boolean({
      description:
        "Send as multipart/form-data with the payload as one file part " +
        "instead of as the raw request body.",
    }),
  ),
  fieldName: Type.Optional(
    Type.String({
      description: "multipart field name for the file part (default 'file').",
    }),
  ),
  filename: Type.Optional(
    Type.String({
      description:
        "Filename advertised for the payload. Defaults to `path`'s basename.",
    }),
  ),
  fields: Type.Optional(
    Type.Record(Type.String(), Type.String(), {
      description: "Extra multipart text fields (only used with `form`).",
    }),
  ),
  contentType: Type.Optional(
    Type.String({
      description:
        "Content type of the payload. Sniffed from the file extension when " +
        "omitted.",
    }),
  ),
  headers: Type.Optional(
    Type.Record(Type.String(), Type.String(), {
      description:
        "Extra request headers, e.g. authorization (Content-Type is set " +
        "automatically in multipart mode).",
    }),
  ),
});

export default function fileUploadExtension(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "upload",
    label: "Upload",
    description:
      "Upload a local file (`path`) or inline string (`body`) to an http(s) " +
      "URL with POST or PUT, as the raw body or (`form: true`) as " +
      "multipart/form-data.",
    parameters,
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const p = params as {
        url?: unknown;
        method?: unknown;
        path?: unknown;
        body?: unknown;
        encoding?: unknown;
        form?: unknown;
        fieldName?: unknown;
        filename?: unknown;
        fields?: unknown;
        contentType?: unknown;
        headers?: unknown;
      };
      const startedAt = Date.now();

      // ── URL ────────────────────────────────────────────────────────────
      const rawUrl = String(p.url ?? "").trim();
      let url: URL;
      try {
        url = new URL(rawUrl);
      } catch {
        return fail(`Invalid URL: '${rawUrl}'`);
      }
      if (url.protocol !== "http:" && url.protocol !== "https:") {
        return fail(
          `Only http/https URLs are supported (got '${url.protocol}').`,
        );
      }

      const method = String(p.method ?? "POST").toUpperCase();
      if (method !== "POST" && method !== "PUT") {
        return fail(`Unsupported method '${method}' (use POST or PUT).`);
      }

      // ── payload ────────────────────────────────────────────────────────
      const rawPath =
        typeof p.path === "string" && p.path.trim().length > 0
          ? p.path.trim()
          : undefined;
      const hasBody = typeof p.body === "string";
      if (rawPath && hasBody) {
        return fail("upload: pass either `path` or `body`, not both.");
      }
      if (!rawPath && !hasBody) {
        return fail("upload: one of `path` or `body` is required.");
      }

      let payload: Buffer;
      let sourcePath: string | undefined;
      let inlineText = false;

      if (rawPath) {
        sourcePath = path.resolve(ctx.cwd, expandTilde(rawPath));
        let size: number;
        try {
          const st = await stat(sourcePath);
          if (st.isDirectory()) {
            return fail(`upload: ${rawPath} is a directory.`);
          }
          size = st.size;
        } catch {
          return fail(`upload: no such file: ${rawPath}`);
        }
        if (size > MAX_UPLOAD_BYTES) {
          return fail(
            `upload: ${rawPath} is ${formatBytes(size)}, over the ` +
              `${formatBytes(MAX_UPLOAD_BYTES)} limit.`,
          );
        }
        payload = await readFile(sourcePath);
      } else {
        const text = String(p.body ?? "");
        if (p.encoding === "base64") {
          payload = Buffer.from(text, "base64");
        } else {
          payload = Buffer.from(text, "utf8");
          inlineText = true;
        }
        if (payload.byteLength > MAX_UPLOAD_BYTES) {
          return fail(
            `upload: inline body is ${formatBytes(payload.byteLength)}, over ` +
              `the ${formatBytes(MAX_UPLOAD_BYTES)} limit.`,
          );
        }
      }

      const form = p.form === true;
      const filename =
        (typeof p.filename === "string" && p.filename.trim()) ||
        (sourcePath ? path.basename(sourcePath) : "upload.bin");
      const contentType =
        (typeof p.contentType === "string" && p.contentType.trim()) ||
        sniffContentType(sourcePath ?? (form ? filename : undefined), inlineText);

      const details: UploadDetails = {
        url: rawUrl,
        method,
        form,
        source: sourcePath ? "path" : "body",
        sourcePath,
        sentBytes: payload.byteLength,
        contentType,
      };

      // ── request ────────────────────────────────────────────────────────
      const headers = asStringRecord(p.headers);
      // Normalise header casing so our own defaults don't duplicate a
      // caller-supplied header under different casing.
      const lower = new Set(Object.keys(headers).map((k) => k.toLowerCase()));
      let requestBody: BodyInit;

      if (form) {
        const fd = new FormData();
        for (const [k, v] of Object.entries(asStringRecord(p.fields))) {
          fd.append(k, v);
        }
        const field =
          (typeof p.fieldName === "string" && p.fieldName.trim()) || "file";
        fd.append(
          field,
          new Blob([new Uint8Array(payload)], { type: contentType }),
          filename,
        );
        requestBody = fd;
        // fetch derives the multipart boundary itself; a manual Content-Type
        // would break the body framing.
        for (const k of Object.keys(headers)) {
          if (k.toLowerCase() === "content-type") delete headers[k];
        }
      } else {
        requestBody = new Uint8Array(payload);
        if (!lower.has("content-type")) headers["content-type"] = contentType;
      }
      if (!lower.has("user-agent")) headers["user-agent"] = USER_AGENT;
      if (!lower.has("accept")) headers["accept"] = "*/*";

      onUpdate?.({
        content: [{ type: "text", text: "uploading" }],
        details: { ...details, phase: "uploading", startedAt },
      });

      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
      const onAbort = () => controller.abort();
      signal?.addEventListener("abort", onAbort, { once: true });

      let res: Response;
      try {
        res = await fetch(url, {
          method,
          headers,
          body: requestBody,
          redirect: "follow",
          signal: controller.signal,
        });
      } catch (err) {
        return fail(
          `upload: ${method} ${rawUrl} failed: ${(err as Error).message}`,
          details,
        );
      } finally {
        clearTimeout(timer);
        signal?.removeEventListener("abort", onAbort);
      }

      // ── response ───────────────────────────────────────────────────────
      let responseText = "";
      try {
        responseText = await res.text();
      } catch {
        responseText = "";
      }
      const responseBytes = Buffer.byteLength(responseText, "utf8");
      const truncated = responseBytes > MAX_RESPONSE_INLINE_BYTES;
      const shown = truncated
        ? responseText.slice(0, MAX_RESPONSE_INLINE_BYTES)
        : responseText;

      details.status = res.status;
      details.statusText = res.statusText;
      details.responseType = (res.headers.get("content-type") ?? "").toLowerCase();
      details.responseBytes = responseBytes;
      details.location = res.headers.get("location") ?? undefined;
      details.responseText = shown;
      details.truncated = truncated;
      details.elapsedMs = Date.now() - startedAt;

      const lines = [
        `${method} ${rawUrl} → HTTP ${res.status}${res.statusText ? ` ${res.statusText}` : ""}`,
        `sent ${formatBytes(payload.byteLength)} ${
          form ? `as multipart field (filename ${filename})` : `as ${contentType}`
        }${sourcePath ? ` from ${sourcePath}` : " from inline body"}`,
      ];
      if (details.location) lines.push(`location: ${details.location}`);
      if (shown.trim().length > 0) {
        lines.push("", "response body:", shown.trimEnd());
        if (truncated) {
          lines.push(
            `[truncated: ${responseBytes} bytes total, showing ${MAX_RESPONSE_INLINE_BYTES}]`,
          );
        }
      } else {
        lines.push("(empty response body)");
      }

      return result(lines.join("\n"), details, res.status >= 400);
    },

    renderCall(args, theme, _context) {
      const a = args as Record<string, unknown>;
      const method = String(a.method ?? "POST").toUpperCase();
      let s = theme.fg("toolTitle", theme.bold("upload "));
      s += theme.fg("text", `${method} `);
      s += theme.fg("accent", typeof a.url === "string" ? a.url : "…");
      const src =
        typeof a.path === "string" && a.path.length > 0
          ? a.path
          : typeof a.body === "string"
            ? "(inline body)"
            : undefined;
      if (src) s += theme.fg("muted", " ← ") + theme.fg("accent", src);
      if (a.form === true) s += " " + theme.fg("muted", "[multipart]");
      return new Text(s, 0, 0);
    },

    renderResult(res, opts, theme, _context) {
      const d = res.details as UploadDetails | undefined;

      if (opts.isPartial) {
        const elapsed = d?.startedAt
          ? ` (${((Date.now() - d.startedAt) / 1000).toFixed(1)}s)`
          : "";
        const size = d?.sentBytes !== undefined ? ` ${formatBytes(d.sentBytes)}` : "";
        return new Text(
          theme.fg("warning", `⋮ Uploading${size}${elapsed}`),
          0,
          0,
        );
      }

      if (res.isError || !d || typeof d.status !== "number") {
        const first = res.content?.[0];
        const msg =
          first && first.type === "text" ? first.text : "upload: error";
        return new Text(theme.fg(res.isError ? "error" : "dim", msg), 0, 0);
      }

      const color =
        d.status >= 400 ? "error" : d.status >= 300 ? "warning" : "success";
      let summary = theme.fg(color, `HTTP ${d.status}`);
      summary += theme.fg(
        "dim",
        ` · sent ${formatBytes(d.sentBytes ?? 0)}${d.form ? " (multipart)" : ""}`,
      );
      if (d.elapsedMs !== undefined) {
        summary += theme.fg("muted", ` · ${(d.elapsedMs / 1000).toFixed(1)}s`);
      }

      if (!opts.expanded) return new Text(summary, 0, 0);

      const lines = [summary];
      lines.push(theme.fg("muted", `${d.method} ${d.url}`));
      lines.push(
        theme.fg(
          "dim",
          `source:  ${d.sourcePath ?? "(inline body)"} · ${d.contentType}`,
        ),
      );
      if (d.location) lines.push(theme.fg("dim", `location: ${d.location}`));
      if (d.responseText && d.responseText.trim().length > 0) {
        lines.push(theme.fg("dim", "───"));
        lines.push(d.responseText.trimEnd());
        if (d.truncated) lines.push(theme.fg("warning", "(response truncated)"));
      }
      return new Text(lines.join("\n"), 0, 0);
    },
  });
}
