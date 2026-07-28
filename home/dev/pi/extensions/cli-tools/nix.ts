// Nix flake wrappers.
//
// So far just one read-oriented metadata tool. It's named `nix-flake-info`
// rather than mirroring any single `nix` subcommand so it can aggregate
// several kinds of flake metadata over time. The structured output is
// namespaced under `details.nixFlake` with one key per category (currently
// just `inputs`), leaving room to add more categories without reshaping the
// existing ones.

import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
  buildDefaultSpec,
  commandOk,
  type CliRenderResult,
  type CliToolDef,
  type CliToolDetails,
  type StructuredCliToolDef,
} from "./shared";

// --- nix flake archive --json parsing ------------------------------------

/**
 * Shape of `nix flake archive --json`. It also carries nested `inputs`, but
 * we only surface the top-level input store paths (the `map_values(.path)`
 * of the equivalent jq one-liner).
 */
interface FlakeArchive {
  path?: string;
  inputs?: Record<string, { path?: string } | undefined>;
}

/**
 * Structured details attached under `details.nixFlake`. One key per metadata
 * category so more can be added later without breaking existing consumers.
 */
export interface NixFlakeExtraDetails {
  nixFlake: {
    /** Top-level input name -> store path (present only once fetched). */
    inputs: Record<string, string>;
  };
}

type NixFlakeDetails = CliToolDetails & NixFlakeExtraDetails;

function parseInputs(stdout: string): Record<string, string> {
  const inputs: Record<string, string> = {};
  let data: FlakeArchive;
  try {
    data = JSON.parse(stdout) as FlakeArchive;
  } catch {
    return inputs;
  }
  for (const [name, node] of Object.entries(data.inputs ?? {})) {
    if (node && typeof node.path === "string") inputs[name] = node.path;
  }
  return inputs;
}

// --- postProcess: JSON -> NixFlakeDetails + LLM text ---------------------

function formatFlakeInfo(raw: {
  stdout: string;
  stderr: string;
  exitCode: number | null;
  timedOut: boolean;
}): { content: string; details: NixFlakeExtraDetails; isError: boolean } {
  const empty: NixFlakeExtraDetails = { nixFlake: { inputs: {} } };

  if (raw.timedOut) {
    return { content: "nix flake archive timed out", details: empty, isError: true };
  }
  if (raw.exitCode !== 0) {
    const stderr = raw.stderr.trim();
    return {
      content:
        stderr.length > 0
          ? stderr
          : `nix flake archive failed (exit ${raw.exitCode})`,
      details: empty,
      isError: true,
    };
  }

  const inputs = parseInputs(raw.stdout);
  const names = Object.keys(inputs);
  const content =
    names.length === 0
      ? "No flake inputs."
      : names.map((name) => `${name}\t${inputs[name]}`).join("\n");

  return { content, details: { nixFlake: { inputs } }, isError: false };
}

// --- renderResult: compact summary + expandable listing ------------------

const renderResult: CliRenderResult<NixFlakeDetails> = (
  result,
  opts,
  theme,
  context,
) => {
  const details = result.details as NixFlakeDetails | undefined;
  const nixFlake = details?.nixFlake;

  if (!nixFlake) {
    return buildDefaultSpec(
      result as unknown as Parameters<typeof buildDefaultSpec>[0],
      opts,
      theme,
      context,
    );
  }

  const names = Object.keys(nixFlake.inputs);
  const summary =
    names.length === 0
      ? theme.fg("dim", "no inputs")
      : theme.fg(
          "success",
          `${names.length} input${names.length === 1 ? "" : "s"}`,
        );

  const outLines = names.map(
    (name) =>
      `${theme.fg("accent", name)}  ${theme.fg("dim", nixFlake.inputs[name]!)}`,
  );
  const output =
    outLines.length > 0 ? new Text(outLines.join("\n"), 0, 0) : undefined;

  return { summary, output, outputLines: outLines.length };
};

// --- tool definition -----------------------------------------------------

const params = Type.Object({});

const nixFlakeInfoTool: StructuredCliToolDef<typeof params> = {
  name: "nix-flake-info",
  label: "nix flake info",
  command: "nix",
  description:
    "Show metadata about the flake in the current directory. Currently " +
    "reports each top-level input's store path (fetching/copying inputs " +
    "into the store as needed). Read-oriented.",
  promptSnippet: "Use nix-flake-info to inspect the current flake's inputs.",
  // Fetching inputs into the store can be slow on a cold cache.
  timeoutMs: 120_000,
  parameters: params,
  buildArgs() {
    // Runs in ctx.cwd; nix defaults the flakeref to the current directory.
    return ["flake", "archive", "--json"];
  },
  postProcess(raw) {
    return formatFlakeInfo(raw);
  },
  renderResult,
};

/**
 * Return the nix tools whose underlying binary exists. If `nix` is missing
 * (not a Nix environment) we register nothing.
 */
export function getNixTools(): CliToolDef[] {
  if (!commandOk("nix", ["--version"])) return [];
  return [nixFlakeInfoTool];
}
