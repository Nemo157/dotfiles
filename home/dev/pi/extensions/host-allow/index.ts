// Per-host auto-approval for the network tools (`web-fetch`, `upload`).
//
// pi-permission-system matches extension tools only on their catch-all
// (`web-fetch = "ask"`), never on their arguments, so it can't express "allow
// fetches from docs.rs". This extension adds that as a live-authority chain
// link (like ../edit-toggle): on an `ask` for one of these tools it returns
// `allow` when the call's URL host is on an allowlist, and `defer` (so the
// normal prompt appears) otherwise. It never denies.
//
// Allowlists
// ----------
// Two scopes, unioned (a project can only add hosts, never remove any):
//
//   global   $PI_CODING_AGENT_DIR/extensions/host-allow/config.json
//            (written by `programs.pi.extensionSettings.host-allow`)
//   project  <cwd>/.pi/extensions/host-allow/config.json
//            honoured only while the project is trusted
//            (`ctx.isProjectTrusted()`), mirroring pi-permission-system's own
//            project scope, so an untrusted checkout can't allow its own hosts.
//
// Both files have the shape
//
//   { "web-fetch": ["docs.rs", "*.github.com"], "upload": ["0x0.st"] }
//
// An entry is a hostname matched exactly, or `*.domain` matching any
// subdomain of `domain` (not `domain` itself). Matching ignores case, the
// port, and a trailing dot. Files are re-read on every ask, so edits apply
// immediately.
//
// The agent must not be able to grant itself a host by writing the project
// file. ../../default.nix puts `path_write` on `.pi/` to `ask`, and the chain
// never lets a link (edit-toggle included) approve a `path`-family ask, so
// every write there needs explicit approval from you.
//
// Seeing the URL
// --------------
// The details a link receives don't include the raw tool input. They do
// carry the ask payload's evidence, which holds the tool's input preview
// verbatim and complete. So this extension also registers the input
// formatters for both tools. They render the URL JSON-quoted
// (`fetching "https://…"`), and the link parses it back from that exact
// shape. If the formatter is missing (registration lost to another
// extension), the evidence is the generic JSON preview, the parse fails, and
// the link defers. That fails safe.
//
// Scope limits
// ------------
// - Only local `tool`-kind asks are judged. A subagent's forwarded ask, or an
//   upload's `path`/`external_directory` ask on its source file, is deferred.
// - Redirects are followed by both tools, so an allowed host can redirect the
//   request elsewhere. Only list hosts you trust to that degree.

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";
import { getPermissionsService } from "@gotgenes/pi-permission-system";
import type {
  AuthorizerVerdict,
  PermissionsReadyEvent,
  PromptPermissionDetails,
} from "@gotgenes/pi-permission-system";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const LINK_NAME = "host-allow";
const TOOLS = ["web-fetch", "upload"] as const;
type GatedTool = (typeof TOOLS)[number];

function isGatedTool(name: unknown): name is GatedTool {
  return (TOOLS as readonly unknown[]).includes(name);
}

// ── config ────────────────────────────────────────────────────────────────

type HostLists = Record<GatedTool, string[]>;

function readHostLists(path: string): HostLists {
  const lists: HostLists = { "web-fetch": [], upload: [] };
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return lists; // missing / unreadable / invalid: contributes nothing
  }
  if (typeof raw !== "object" || raw === null) return lists;
  for (const tool of TOOLS) {
    const entries = (raw as Record<string, unknown>)[tool];
    if (!Array.isArray(entries)) continue;
    for (const entry of entries) {
      if (typeof entry === "string" && entry.trim()) {
        lists[tool].push(normalizeHost(entry));
      }
    }
  }
  return lists;
}

function normalizeHost(host: string): string {
  return host.trim().toLowerCase().replace(/\.$/, "");
}

function hostMatches(pattern: string, host: string): boolean {
  if (pattern.startsWith("*.")) {
    const domain = pattern.slice(2);
    return domain.length > 0 && host.endsWith(`.${domain}`);
  }
  return pattern === host;
}

// ── formatter ↔ link contract ─────────────────────────────────────────────
// The formatter's output starts with a verb and the JSON-quoted URL. The
// link parses the URL back out with QUOTED_URL. Keep the two in sync.

const QUOTED_URL = /^(?:fetching|POST|PUT) ("(?:[^"\\]|\\.)*")/;

function formatWebFetch(input: Record<string, unknown>): string | undefined {
  if (typeof input.url !== "string") return undefined;
  let s = `fetching ${JSON.stringify(input.url)}`;
  if (input.mode === "raw") s += " (raw)";
  if (typeof input.member === "string") {
    s += ` member ${JSON.stringify(input.member)}`;
  }
  return s;
}

function formatUpload(input: Record<string, unknown>): string | undefined {
  if (typeof input.url !== "string") return undefined;
  const method =
    typeof input.method === "string" && input.method.toUpperCase() === "PUT"
      ? "PUT"
      : "POST";
  let s = `${method} ${JSON.stringify(input.url)}`;
  if (typeof input.path === "string") {
    s += ` from file ${JSON.stringify(input.path)}`;
  } else if (typeof input.body === "string") {
    // Size only: the body may hold secrets and the prompt is logged.
    s += ` with a ${input.body.length}-character inline body`;
  }
  if (input.form === true) s += " as multipart form";
  return s;
}

/** The hostname of the URL the ask's tool will contact, or undefined. */
function askedHost(details: PromptPermissionDetails): string | undefined {
  const preview = details.payload.evidence.find((e) => e.label === "input");
  const quoted = preview?.text.match(QUOTED_URL)?.[1];
  if (!quoted) return undefined;
  try {
    // Same normalisation the tools apply before fetching.
    const url = new URL(String(JSON.parse(quoted)).trim());
    if (url.protocol !== "http:" && url.protocol !== "https:") return undefined;
    return normalizeHost(url.hostname);
  } catch {
    return undefined;
  }
}

// ── extension ─────────────────────────────────────────────────────────────

export default function hostAllowExtension(pi: ExtensionAPI): void {
  const disposers: Array<() => void> = [];
  // Refreshed at every session_start. Project trust is re-queried per ask
  // because a trust grant can land mid-session.
  let session: ExtensionContext | undefined;

  function allowedHosts(tool: GatedTool): string[] {
    const hosts = [
      ...readHostLists(
        join(getAgentDir(), "extensions", LINK_NAME, "config.json"),
      )[tool],
    ];
    const ctx = session;
    let trusted = false;
    try {
      trusted = ctx?.isProjectTrusted() ?? false;
    } catch {
      trusted = false; // stale context: treat as untrusted
    }
    if (ctx && trusted) {
      hosts.push(
        ...readHostLists(
          join(
            ctx.cwd,
            CONFIG_DIR_NAME,
            "extensions",
            LINK_NAME,
            "config.json",
          ),
        )[tool],
      );
    }
    return hosts;
  }

  function teardown(): void {
    for (const dispose of disposers.splice(0)) {
      try {
        dispose();
      } catch {
        // best-effort
      }
    }
  }

  // Each /reload publishes a fresh service with empty registries, so
  // re-register from scratch every time (disposing any previous generation).
  function register(sessionId: string | null | undefined): void {
    const permissions =
      typeof sessionId === "string"
        ? getPermissionsService(sessionId)
        : undefined;
    if (!permissions) return;
    teardown();

    const formatters: Record<
      GatedTool,
      (input: Record<string, unknown>) => string | undefined
    > = { "web-fetch": formatWebFetch, upload: formatUpload };
    for (const tool of TOOLS) {
      try {
        disposers.push(
          permissions.registerToolInputFormatter(tool, (input) => {
            try {
              return formatters[tool](input);
            } catch {
              return undefined; // a throwing formatter breaks the prompt
            }
          }),
        );
      } catch {
        // Already claimed: the link then can't parse the URL and defers.
      }
    }

    try {
      disposers.push(
        permissions.registerAuthorizer(
          LINK_NAME,
          async (details, _query, log): Promise<AuthorizerVerdict> => {
            const tool = details.toolName;
            if (!isGatedTool(tool)) return { kind: "defer" };
            // Only the tool's own ask (not a path / external_directory ask on
            // an upload's source file, nor a subagent's forwarded ask).
            const request = details.payload.request;
            if (
              details.payload.kind !== "tool" ||
              request.surface !== tool ||
              details.forwarding
            ) {
              return { kind: "defer" };
            }
            const host = askedHost(details);
            if (!host) return { kind: "defer" };
            const pattern = allowedHosts(tool).find((p) =>
              hostMatches(p, host),
            );
            if (!pattern) return { kind: "defer" };
            log.review("host_allow.allowed", { tool, host, pattern });
            return { kind: "allow" };
          },
        ),
      );
    } catch {
      // Name already registered on this node; leave it.
    }
  }

  pi.events.on("permissions:ready", (raw) => {
    register((raw as Partial<PermissionsReadyEvent>).sessionId);
  });

  pi.on("session_start", (_event, ctx) => {
    session = ctx;
    register(ctx.sessionManager.getSessionId());
  });

  pi.on("session_shutdown", () => {
    teardown();
    session = undefined;
  });
}
