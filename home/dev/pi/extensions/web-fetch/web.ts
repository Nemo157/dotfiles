// HTTP fetching, content-type classification, and HTML/PDF → text extraction.

import { Readability } from "@mozilla/readability";
import { parseHTML } from "linkedom";
import { extractText, getDocumentProxy } from "unpdf";

import {
  archiveExtension,
  archiveKind,
  archiveKindFor,
  innerName,
  nameExtension,
} from "./archive";

export interface FetchResult {
  finalUrl: string;
  status: number;
  contentType: string;
  /** File name from Content-Disposition, else the URL's last path segment. */
  fileName: string;
  body: Buffer;
}

/**
 * Parse the file name out of a Content-Disposition header, preferring the
 * RFC 5987 `filename*=charset''percent-encoded` form over `filename=`.
 */
export function dispositionFileName(
  header: string | null | undefined,
): string | undefined {
  if (!header) return undefined;
  const ext = /filename\*\s*=\s*([^']*)'[^']*'([^;]+)/i.exec(header);
  if (ext) {
    try {
      const value = ext[2].trim().replace(/^"(.*)"$/, "$1");
      const name =
        ext[1].trim().toLowerCase() === "utf-8" || ext[1].trim() === ""
          ? decodeURIComponent(value)
          : unescape(value);
      const clean = sanitizeName(name);
      if (clean) return clean;
    } catch {
      // Malformed encoding: fall back to the plain parameter.
    }
  }
  const plain =
    /(?:^|;)\s*filename\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^;]*))/i.exec(header);
  if (plain) {
    const name =
      plain[1] !== undefined
        ? plain[1].replace(/\\(.)/g, "$1")
        : plain[2].trim();
    return sanitizeName(name);
  }
  return undefined;
}

/** Last path segment of a URL, percent-decoded. */
export function urlFileName(url: string): string | undefined {
  try {
    const seg = new URL(url).pathname.split("/").filter(Boolean).pop();
    return seg ? sanitizeName(decodeURIComponent(seg)) : undefined;
  } catch {
    return undefined;
  }
}

/** Reduce a name to its basename; it is only used as a hint, never a path. */
function sanitizeName(name: string): string | undefined {
  const base = name.split(/[\\/]/).pop()?.trim();
  return base && base !== "." && base !== ".." ? base : undefined;
}

/** Best file name for a download: Content-Disposition, final URL, request URL. */
export function downloadFileName(
  disposition: string | null | undefined,
  finalUrl: string,
  url: string,
): string {
  return (
    dispositionFileName(disposition) ??
    urlFileName(finalUrl) ??
    urlFileName(url) ??
    "content"
  );
}

/**
 * Fetch a URL with a hard timeout, following redirects. `signal` (the agent
 * turn's abort signal) cancels the request when the user hits Esc.
 */
export async function fetchUrl(
  url: string,
  opts: {
    timeoutMs: number;
    userAgent: string;
    signal?: AbortSignal;
    /**
     * Called as the response body streams in. `total` is the
     * Content-Length when the server advertises one, otherwise undefined.
     */
    onProgress?: (received: number, total?: number) => void;
  },
): Promise<FetchResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), opts.timeoutMs);
  const onAbort = () => controller.abort();
  opts.signal?.addEventListener("abort", onAbort, { once: true });
  try {
    const res = await fetch(url, {
      method: "GET",
      redirect: "follow",
      headers: { "user-agent": opts.userAgent, accept: "*/*" },
      signal: controller.signal,
    });
    const contentType = (res.headers.get("content-type") ?? "").toLowerCase();
    const lenHeader = res.headers.get("content-length");
    const total = lenHeader ? Number(lenHeader) || undefined : undefined;

    const body = res.body
      ? await drainStream(res.body, total, opts.onProgress)
      : Buffer.from(await res.arrayBuffer());

    const finalUrl = res.url || url;
    return {
      finalUrl,
      status: res.status,
      contentType,
      fileName: downloadFileName(
        res.headers.get("content-disposition"),
        finalUrl,
        url,
      ),
      body,
    };
  } finally {
    clearTimeout(timer);
    opts.signal?.removeEventListener("abort", onAbort);
  }
}

/** Read a web ReadableStream to completion, reporting cumulative bytes. */
async function drainStream(
  stream: ReadableStream<Uint8Array>,
  total: number | undefined,
  onProgress?: (received: number, total?: number) => void,
): Promise<Buffer> {
  const reader = stream.getReader();
  const chunks: Buffer[] = [];
  let received = 0;
  onProgress?.(0, total);
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value && value.byteLength > 0) {
        chunks.push(Buffer.from(value));
        received += value.byteLength;
        onProgress?.(received, total);
      }
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks);
}

const TEXTUAL = [
  "text/",
  "application/json",
  "application/xml",
  "application/xhtml",
  "application/javascript",
  "application/ld+json",
  "+json",
  "+xml",
];

export function isTextual(contentType: string): boolean {
  return TEXTUAL.some((t) => contentType.includes(t));
}

export function isHtml(contentType: string): boolean {
  return contentType.includes("text/html") || contentType.includes("xhtml");
}

/**
 * PDF detection by content type, falling back to the `%PDF-` magic bytes for
 * servers that send PDFs as application/octet-stream.
 */
export function isPdf(contentType: string, body?: Buffer): boolean {
  if (contentType.includes("application/pdf")) return true;
  return (
    body !== undefined && body.subarray(0, 5).toString("latin1") === "%PDF-"
  );
}

/**
 * A reasonable file extension for the raw cache artifact. The magic bytes
 * decide whether the body is an archive; otherwise the content type, then
 * the file name, pick the extension.
 */
export function rawExtension(
  contentType: string,
  fileName: string,
  body?: Buffer,
): string {
  const archive = body && archiveKindFor(body, fileName, contentType);
  if (archive) return archiveExtension(archive);
  // A zip-based document (see archiveKindFor) keeps its own extension; its
  // OOXML content type would otherwise match "xml" below.
  if (body && archiveKind(body) === "zip") {
    return nameExtension(fileName) ?? "zip";
  }
  // Not compressed (fetch may already have undone a Content-Encoding), so a
  // `.gz`-style suffix on the name no longer applies.
  const nameExt = nameExtension(innerName(fileName));
  if (isHtml(contentType)) return "html";
  if (contentType.includes("json")) return "json";
  if (contentType.includes("xml")) return "xml";
  if (contentType.includes("csv")) return "csv";
  if (contentType.includes("markdown")) return "md";
  if (contentType.startsWith("text/")) return "txt";
  if (contentType.includes("pdf")) return "pdf";
  return nameExt ?? "bin";
}

/** How many leading bytes guessContentType needs to see. */
export const SNIFF_BYTES = 8192;

/**
 * Infer a content type for a file without HTTP headers (an archive member or
 * a decompressed stream) from its name and its first SNIFF_BYTES bytes
 * (`truncated`: the file continues past `head`).
 */
export function guessContentType(
  name: string,
  head: Buffer,
  truncated: boolean,
): string {
  if (isPdf("", head)) return "application/pdf";
  const ext = nameExtension(name);
  if (ext === "html" || ext === "htm" || ext === "xhtml") return "text/html";
  if (ext === "json") return "application/json";
  if (ext === "xml" || ext === "svg") return "application/xml";
  if (ext === "pdf") return "application/pdf";
  return looksLikeText(head, truncated)
    ? "text/plain"
    : "application/octet-stream";
}

/** Heuristic: no NUL bytes and valid UTF-8 in the first SNIFF_BYTES. */
function looksLikeText(head: Buffer, truncated: boolean): boolean {
  const sample = head.subarray(0, SNIFF_BYTES);
  if (sample.includes(0)) return false;
  try {
    // In stream mode a multi-byte sequence split at the end of a truncated
    // sample is held back rather than rejected.
    new TextDecoder("utf-8", { fatal: true }).decode(sample, {
      stream: truncated || sample.length < head.length,
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Pretty-print JSON bodies (2-space indent) so the cached artifact is
 * line-oriented and greppable. Returns the body unchanged if it is not JSON
 * or fails to parse (e.g. NDJSON, truncated responses).
 */
export function prettyJson(contentType: string, body: Buffer): Buffer {
  if (!contentType.includes("json")) return body;
  try {
    const parsed: unknown = JSON.parse(body.toString("utf8"));
    return Buffer.from(JSON.stringify(parsed, null, 2) + "\n", "utf8");
  } catch {
    return body;
  }
}

export interface Extraction {
  title?: string;
  text: string;
}

/** Normalize whitespace: collapse runs of blank lines, trim trailing spaces. */
function normalize(text: string): string {
  return text
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/**
 * Extract readable text from HTML using Mozilla Readability over a linkedom
 * DOM. Falls back to the document's body text when Readability finds no
 * article (e.g. non-article pages).
 */
export function extractHtml(html: string, _url?: string): Extraction {
  const { document } = parseHTML(html);
  try {
    // linkedom's document is structurally close enough for Readability but
    // not typed as a DOM `Document` (no DOM lib here, so name it via the
    // constructor's own parameter type).
    const reader = new Readability(
      document as unknown as ConstructorParameters<typeof Readability>[0],
    );
    const article = reader.parse();
    const text = article?.textContent ? normalize(article.textContent) : "";
    if (text.length > 0) {
      return { title: article?.title ?? undefined, text };
    }
  } catch {
    // Readability can throw on malformed documents; fall through to body text.
  }
  const bodyText = document.body?.textContent ?? "";
  const title = document.title || undefined;
  return { title, text: normalize(bodyText) };
}

/**
 * Extract text from a PDF with unpdf (bundled serverless pdf.js). Each page
 * is prefixed with a `--- page N ---` marker so page numbers can be cited. The title comes
 * from the document's /Info dictionary when present.
 */
export async function extractPdf(body: Buffer): Promise<Extraction> {
  // pdf.js may transfer/detach the buffer it is given, so pass a copy.
  const pdf = await getDocumentProxy(new Uint8Array(body));
  try {
    const { text } = await extractText(pdf, { mergePages: false });
    const pages = (Array.isArray(text) ? text : [text]).map(normalize);
    let title: string | undefined;
    try {
      const { info } = await pdf.getMetadata();
      const t = (info as unknown as { Title?: unknown } | undefined)?.Title;
      if (typeof t === "string" && t.trim()) title = t.trim();
    } catch {
      // Metadata is optional; ignore malformed /Info dictionaries.
    }
    const marked = pages.map((p, i) => `--- page ${i + 1} ---\n\n${p}`);
    return { title, text: marked.join("\n\n") };
  } finally {
    await pdf.loadingTask.destroy();
  }
}
