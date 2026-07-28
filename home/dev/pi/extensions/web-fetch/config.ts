// Configuration for the web-fetch extension.
//
// Config is read once at extension load from
//   $PI_CODING_AGENT_DIR/extensions/web-fetch/config.json
// (the path the home-manager `programs.pi.extensionSettings.web-fetch`
// option writes to — see modules/home-manager/pi.nix). Reading it is
// best-effort: a missing or malformed file just yields defaults, with the
// `prompt` capability disabled (see `model`).
//
// The cache directory follows the XDG base-dir spec: it defaults to
// `$XDG_CACHE_HOME/pi/web-fetch` (falling back to `~/.cache/pi/web-fetch`),
// and can be overridden with `cacheDir`. Whatever directory is used must
// also be granted read access in the permission config — the Nix module
// wires the same path into `pi-permission-system.piInfrastructureReadPaths`
// so the agent can `read` cached artifacts without an approval prompt.

import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export interface WebFetchConfig {
  /**
   * Model spec ("provider/id" or "provider/id:thinking") used to answer the
   * optional `prompt` parameter. When unset the `prompt` parameter is not
   * exposed at all — there is no default model.
   */
  model?: string;
  /** Absolute directory for cached downloads / extractions / prompt answers. */
  cacheDir: string;
  /** Results whose text payload exceeds this many bytes are returned as a
   *  cache path instead of inline content. */
  maxInlineBytes: number;
  /** HTTP fetch timeout in milliseconds. */
  timeoutMs: number;
  /** User-Agent header sent with every fetch. */
  userAgent: string;
  /** Content longer than this (characters) is truncated before being sent to
   *  the small model for the `prompt` query. */
  maxPromptChars: number;
}

const DEFAULT_MAX_INLINE_BYTES = 32 * 1024;
const DEFAULT_TIMEOUT_MS = 30_000;
const DEFAULT_USER_AGENT =
  "pi-web-fetch/1.0 (+https://github.com/earendil-works/pi)";
const DEFAULT_MAX_PROMPT_CHARS = 100_000;

function num(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? value
    : fallback;
}

function str(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function defaultCacheDir(): string {
  const base = process.env.XDG_CACHE_HOME || join(homedir(), ".cache");
  return join(base, "pi", "web-fetch");
}

export function loadConfig(): WebFetchConfig {
  let raw: Record<string, unknown> = {};
  try {
    const path = join(
      getAgentDir(),
      "extensions",
      "web-fetch",
      "config.json",
    );
    raw = JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
  } catch {
    // No config file (or unreadable / invalid JSON): fall back to defaults.
    raw = {};
  }

  return {
    model: str(raw.model),
    cacheDir: str(raw.cacheDir) ?? defaultCacheDir(),
    maxInlineBytes: num(raw.maxInlineBytes, DEFAULT_MAX_INLINE_BYTES),
    timeoutMs: num(raw.timeoutMs, DEFAULT_TIMEOUT_MS),
    userAgent: str(raw.userAgent) ?? DEFAULT_USER_AGENT,
    maxPromptChars: num(raw.maxPromptChars, DEFAULT_MAX_PROMPT_CHARS),
  };
}
