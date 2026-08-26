// Configuration for the cli-tools extension.
//
// Read once, lazily, from
//   $PI_CODING_AGENT_DIR/extensions/cli-tools/config.json
// (the path the home-manager `programs.pi.extensionSettings.cli-tools`
// option writes to — see modules/home-manager/pi.nix). Reading it is
// best-effort: a missing or malformed file just yields defaults.
//
// `tarCacheDir` follows the XDG base-dir spec, defaulting to
// `$XDG_CACHE_HOME/pi/tar` (falling back to `~/.cache/pi/tar`). Whatever
// directory ends up in use must also be granted read access in the
// permission config — the Nix module wires the same path into
// `pi-permission-system.piInfrastructureReadPaths` so the agent can `read`
// (or `upload`) the archives the `tar` tool produces without tripping the
// `external_directory` gate.

import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export interface CliToolsConfig {
  /** Absolute directory the `tar` tool writes archives into. */
  tarCacheDir: string;
}

function str(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function defaultTarCacheDir(): string {
  const base = process.env.XDG_CACHE_HOME || join(homedir(), ".cache");
  return join(base, "pi", "tar");
}

let cached: CliToolsConfig | undefined;

export function loadConfig(): CliToolsConfig {
  if (cached) return cached;

  let raw: Record<string, unknown> = {};
  try {
    const path = join(getAgentDir(), "extensions", "cli-tools", "config.json");
    raw = JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
  } catch {
    // No config file (or unreadable / invalid JSON): fall back to defaults.
    raw = {};
  }

  cached = {
    tarCacheDir: str(raw.tarCacheDir) ?? defaultTarCacheDir(),
  };
  return cached;
}
