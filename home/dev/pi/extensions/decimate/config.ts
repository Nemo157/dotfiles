// Two files, kept apart so the config can be read-only (e.g. Nix-managed):
//
// - config: <agentDir>/extensions/decimate/config.json — the
//   `programs.pi.extensionSettings` convention; never written here (global
//   only, no per-project layer for now). `auto`/`shadow` in it are the
//   defaults.
// - state:  $XDG_STATE_HOME/pi/decimate/state.json — written by
//   `/decimate auto|shadow on|off`; its toggles override the config defaults.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { getAgentDir } from "@earendil-works/pi-coding-agent";

export interface ClassifierConfig {
  /** Classifier model, e.g. { provider: "typesafe", id: "jev-latest" }. */
  provider: string;
  id: string;
  /** Hard budget for the whole classification batch. */
  timeoutMs: number;
  /** Tighter budget when classifying inline on an auto send. */
  autoTimeoutMs: number;
  /** Largest candidates first; the rest fall back to heuristics. */
  maxCandidates: number;
  /** p(needed) at or above this keeps the result verbatim. */
  tauKeep: number;
  /**
   * Action confidence at or above this accepts the model's stub/trim choice
   * (below `tauKeep`); otherwise stub at or below `tauStub`, else trim.
   */
  tauAction: number;
  /** p(needed) at or below this stubs when the action is uncertain. */
  tauStub: number;
  /** Heuristic priors at or above this skip the model (obvious cases). */
  autoAcceptPrior: number;
}

export interface DecimateConfig {
  /** Decimate automatically on cold sends (first send of a run, cold resume). */
  auto: boolean;
  /** Classifier scores and logs, heuristics decide. */
  shadow: boolean;
  /** User-message spans at the end of the branch that are never touched. */
  keepRecentTurns: number;
  /** Skip plans that save fewer estimated tokens than this. */
  minGainTokens: number;
  /** Tool results below this size are never candidates. */
  minChars: number;
  /** Tool results at or above this size are "bulky". */
  bulkyChars: number;
  /** Heuristic-only decisions apply at or above this prior. */
  heuristicThreshold: number;
  /** Precompute a plan when the cache is predicted to go cold (auto mode). */
  precompute: boolean;
  classifier?: ClassifierConfig;
}

const DEFAULTS: DecimateConfig = {
  auto: false,
  shadow: true,
  keepRecentTurns: 2,
  minGainTokens: 8_000,
  minChars: 400,
  bulkyChars: 4_000,
  heuristicThreshold: 0.6,
  precompute: true,
};

const CLASSIFIER_DEFAULTS: Omit<ClassifierConfig, "provider" | "id"> = {
  timeoutMs: 20_000,
  autoTimeoutMs: 4_000,
  maxCandidates: 40,
  tauKeep: 0.75,
  tauAction: 0.5,
  tauStub: 0.35,
  autoAcceptPrior: 0.9,
};

export function configPath(): string {
  return join(getAgentDir(), "extensions", "decimate", "config.json");
}

export function statePath(): string {
  const base = process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state");
  return join(base, "pi", "decimate", "state.json");
}

function readJson(path: string): Record<string, unknown> {
  try {
    const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : {};
  } catch {
    return {};
  }
}

function pick<T>(raw: Record<string, unknown>, key: string, fallback: T): T {
  const value = raw[key];
  return typeof value === typeof fallback ? (value as T) : fallback;
}

export function loadConfig(): DecimateConfig {
  const raw = readJson(configPath());
  const state = readJson(statePath());
  const cfg: DecimateConfig = {
    auto: pick(state, "auto", pick(raw, "auto", DEFAULTS.auto)),
    shadow: pick(state, "shadow", pick(raw, "shadow", DEFAULTS.shadow)),
    keepRecentTurns: pick(raw, "keepRecentTurns", DEFAULTS.keepRecentTurns),
    minGainTokens: pick(raw, "minGainTokens", DEFAULTS.minGainTokens),
    minChars: pick(raw, "minChars", DEFAULTS.minChars),
    bulkyChars: pick(raw, "bulkyChars", DEFAULTS.bulkyChars),
    heuristicThreshold: pick(
      raw,
      "heuristicThreshold",
      DEFAULTS.heuristicThreshold,
    ),
    precompute: pick(raw, "precompute", DEFAULTS.precompute),
  };
  const c = raw.classifier;
  if (c && typeof c === "object" && !Array.isArray(c)) {
    const cr = c as Record<string, unknown>;
    if (typeof cr.provider === "string" && typeof cr.id === "string") {
      cfg.classifier = {
        provider: cr.provider,
        id: cr.id,
        timeoutMs: pick(cr, "timeoutMs", CLASSIFIER_DEFAULTS.timeoutMs),
        autoTimeoutMs: pick(
          cr,
          "autoTimeoutMs",
          CLASSIFIER_DEFAULTS.autoTimeoutMs,
        ),
        maxCandidates: pick(
          cr,
          "maxCandidates",
          CLASSIFIER_DEFAULTS.maxCandidates,
        ),
        tauKeep: pick(cr, "tauKeep", CLASSIFIER_DEFAULTS.tauKeep),
        tauAction: pick(cr, "tauAction", CLASSIFIER_DEFAULTS.tauAction),
        tauStub: pick(cr, "tauStub", CLASSIFIER_DEFAULTS.tauStub),
        autoAcceptPrior: pick(
          cr,
          "autoAcceptPrior",
          CLASSIFIER_DEFAULTS.autoAcceptPrior,
        ),
      };
    }
  }
  return cfg;
}

/** Persist one toggle to the state file (the config file is never written). */
export function saveToggle(
  key: "auto" | "shadow",
  value: boolean,
): string | undefined {
  try {
    const state = readJson(statePath());
    state[key] = value;
    mkdirSync(dirname(statePath()), { recursive: true });
    writeFileSync(statePath(), `${JSON.stringify(state, null, 2)}\n`, "utf8");
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
}
