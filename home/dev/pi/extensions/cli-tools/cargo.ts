// Cargo wrappers. Deliberately minimal: only clippy and nextest, both with
// just package-selection knobs. Everything else (build, run, add/remove,
// fmt, doc, tree, metadata) is either redundant with these two, mutating,
// or handled elsewhere (e.g. formatting flows through `jj fix`). Add more
// subcommands here as concrete needs come up.
//
// No `path` param on these tools — cargo runs in `ctx.cwd`. If we later
// need out-of-tree invocation, add `--manifest-path` support then.

import { Text } from "@earendil-works/pi-tui";
import { Type, type Static } from "typebox";
import { dirname } from "node:path";
import {
  buildDefaultSpec,
  type CliToolDetails,
  commandOk,
  type CliToolDef,
  type StructuredCliToolDef,
} from "./shared";

const packageSelection = {
  package: Type.Optional(
    Type.String({
      description: "Restrict to a single workspace member (-p <package>).",
    }),
  ),
  workspace: Type.Optional(
    Type.Boolean({
      description: "Run against every workspace member (--workspace).",
    }),
  ),
};

// --- cargo clippy --------------------------------------------------------

const clippyParams = Type.Object({
  ...packageSelection,
});

export const cargoClippyTool: StructuredCliToolDef<typeof clippyParams> = {
  name: "cargo-clippy",
  label: "cargo clippy",
  command: "cargo",
  partialLabel: "Linting…",
  description:
    "Lint and type-check a Rust crate or workspace with clippy (all targets).",
  timeoutMs: 120_000,
  parameters: clippyParams,
  buildArgs(p) {
    const args: string[] = ["clippy", "--all-targets"];
    if (p.workspace) args.push("--workspace");
    if (p.package !== undefined) args.push("-p", p.package);
    return args;
  },
};

// --- cargo metadata (dependency source path) -----------------------------

const dependencyPathParams = Type.Object({
  package: Type.String({
    description:
      "Name of the dependency crate to locate (e.g. `serde`, `tokio`).",
  }),
});

interface CargoMetadataPackage {
  name?: unknown;
  version?: unknown;
  manifest_path?: unknown;
}

/** One resolved crate: its version and on-disk source directory. */
interface DependencyMatch {
  version: string;
  dir: string;
}

/**
 * Extra details attached under `details.dependencyPath` so `renderResult`
 * can present the resolved directories instead of the raw `cargo metadata`
 * JSON (which is huge and useless to show).
 */
export interface DependencyPathExtraDetails {
  dependencyPath: {
    package: string;
    matches: DependencyMatch[];
  };
}

type DependencyPathDetails = CliToolDetails & DependencyPathExtraDetails;

/**
 * Resolve a dependency crate's on-disk source directory via `cargo metadata`.
 * Returns the directory containing each matching package's `Cargo.toml` (its
 * source lives alongside the manifest), one line per version present in the
 * dependency graph. Read-only: purely a lookup so the agent can then `read`
 * the dependency's source to understand its API.
 */
export const cargoDependencyPathTool: StructuredCliToolDef<
  typeof dependencyPathParams
> = {
  name: "cargo-dependency-path",
  label: "cargo metadata",
  command: "cargo",
  partialLabel: "Resolving…",
  description:
    "Locate a dependency crate's on-disk source directory (the one holding " +
    "its Cargo.toml) so you can read its source, for every version in the " +
    "dependency graph.",
  timeoutMs: 60_000,
  parameters: dependencyPathParams,
  buildArgs() {
    return ["metadata", "--format-version=1"];
  },
  // Present the user's intent (which crate) rather than the raw invocation,
  // which is identical for every lookup.
  displayArgs(p) {
    return ["metadata", "--format-version=1", `# ${p.package}`];
  },
  postProcess(raw) {
    const { package: name } = raw.params as Static<typeof dependencyPathParams>;
    if (raw.exitCode !== 0) {
      return {
        content:
          raw.stderr.trim() ||
          `cargo metadata failed (exit ${raw.exitCode ?? "unknown"}).`,
        isError: true,
      };
    }
    let meta: { packages?: CargoMetadataPackage[] };
    try {
      meta = JSON.parse(raw.stdout);
    } catch (e) {
      return {
        content: `Failed to parse cargo metadata output: ${(e as Error).message}`,
        isError: true,
      };
    }
    const packages = Array.isArray(meta.packages) ? meta.packages : [];
    const matches = packages.filter((p) => p.name === name);
    if (matches.length === 0) {
      return {
        content: `No dependency named "${name}" found in the metadata graph.`,
        isError: true,
      };
    }
    const resolved: DependencyMatch[] = matches.map((p) => ({
      version: String(p.version),
      dir: dirname(String(p.manifest_path)),
    }));
    const content = resolved
      .map((m) => `${name} ${m.version}\t${m.dir}`)
      .join("\n");
    return {
      content,
      details: { dependencyPath: { package: name, matches: resolved } },
    };
  },
  renderResult(result, opts, theme, context) {
    const details = result.details as DependencyPathDetails | undefined;
    const dep = details?.dependencyPath;

    // No structured data (error path, or parse failure): fall back to the
    // shared default spec, but from the post-processed content rather than
    // the raw metadata JSON. The default spec reads details.stdout, so swap
    // in the LLM-facing content for display.
    if (!dep) {
      const contentText = (result.content ?? [])
        .filter((p): p is { type: "text"; text: string } => p.type === "text")
        .map((p) => p.text)
        .join("\n");
      const patched = {
        ...result,
        details: details
          ? { ...details, stdout: contentText, stderr: "" }
          : details,
      };
      return buildDefaultSpec(
        patched as unknown as Parameters<typeof buildDefaultSpec>[0],
        opts,
        theme,
        context,
      );
    }

    const summary = theme.fg(
      "success",
      `${dep.matches.length} version${dep.matches.length === 1 ? "" : "s"}`,
    );
    const outLines = dep.matches.map(
      (m) =>
        `${theme.fg("accent", `${dep.package} ${m.version}`)}  ` +
        theme.fg("dim", m.dir),
    );
    return {
      summary,
      output: new Text(outLines.join("\n"), 0, 0),
      outputLines: outLines.length,
    };
  },
};

// --- cargo nextest run ---------------------------------------------------

const nextestParams = Type.Object({
  ...packageSelection,
});

export const cargoNextestTool: StructuredCliToolDef<typeof nextestParams> = {
  name: "cargo-test",
  label: "cargo nextest",
  command: "cargo",
  partialLabel: "Testing…",
  description: "Run the test suite for a Rust crate or workspace.",
  timeoutMs: 180_000,
  parameters: nextestParams,
  buildArgs(p) {
    const args: string[] = ["nextest", "run"];
    if (p.workspace) args.push("--workspace");
    if (p.package !== undefined) args.push("-p", p.package);
    return args;
  },
};

/**
 * Return the subset of cargo tools whose underlying binaries exist. If
 * `cargo` itself is missing we register nothing (not a Rust dev env). If
 * `cargo nextest` is missing we still register clippy and warn once so the
 * gap is visible on extension load.
 */
export function getCargoTools(): CliToolDef[] {
  if (!commandOk("cargo", ["--version"])) return [];
  const tools: CliToolDef[] = [cargoClippyTool, cargoDependencyPathTool];
  if (commandOk("cargo", ["nextest", "--version"])) {
    tools.push(cargoNextestTool);
  } else {
    console.warn(
      "[cli-tools] cargo is available but `cargo nextest` is not; " +
        "skipping cargo-test. Install cargo-nextest to enable it.",
    );
  }
  return tools;
}
