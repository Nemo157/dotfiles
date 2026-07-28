// HTTP fetching, content-type classification, and HTML → text extraction.

import { Readability } from "@mozilla/readability";
import { parseHTML } from "linkedom";

export interface FetchResult {
  finalUrl: string;
  status: number;
  contentType: string;
  body: Buffer;
}

/**
 * Fetch a URL with a hard timeout, following redirects. `signal` (the agent
 * turn's abort signal) cancels the request when the user hits Esc.
 */
export async function fetchUrl(
  url: string,
  opts: { timeoutMs: number; userAgent: string; signal?: AbortSignal },
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
    const body = Buffer.from(await res.arrayBuffer());
    return {
      finalUrl: res.url || url,
      status: res.status,
      contentType: (res.headers.get("content-type") ?? "").toLowerCase(),
      body,
    };
  } finally {
    clearTimeout(timer);
    opts.signal?.removeEventListener("abort", onAbort);
  }
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

/** A reasonable file extension for the raw cache artifact. */
export function rawExtension(contentType: string, url: string): string {
  if (isHtml(contentType)) return "html";
  if (contentType.includes("json")) return "json";
  if (contentType.includes("xml")) return "xml";
  if (contentType.includes("csv")) return "csv";
  if (contentType.includes("markdown")) return "md";
  if (contentType.startsWith("text/")) return "txt";
  if (contentType.includes("pdf")) return "pdf";
  const m = /\.([a-z0-9]{1,8})(?:$|[?#])/i.exec(url);
  return m ? m[1].toLowerCase() : "bin";
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
    const reader = new Readability(document as unknown as Document);
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
